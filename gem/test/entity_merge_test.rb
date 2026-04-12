# frozen_string_literal: true

require_relative "./test_helper"

module Interfacets
  class EntityMergeTest < InterfacetsTest

    MANIFEST_BLOCK = ->(*) {
      role(:manifest)
      server_action(:save)

      accessor(:attr_1)
      accessor(:attr_2)
    }

    CLIENT_BLOCK = ->(*) {
      role(:client)

      merge(:attr_1, :after_save) do |entity, value|
        entity.attr_1 = "#{value} - merged"
      end

      merge(:attr_2, :after_save) do |entity, value|
        entity.attr_2 = "#{value} - merged"
      end

      def after_save_called?
        @after_save
      end

      def after_load_called?
        @after_load
      end

      def after_save
        @after_save = true
      end

      def after_load
        @after_load = true
      end
    }

    SERVER_BLOCK = ->(*) {
      role(:server)

      def save
        store.saved = true
      end
    }

    ServerStore = Struct.new(
      :attr_1,
      :attr_2,
      :saved,
    )

    def setup
      shared_klass = Class.new(Shared::Entity, &MANIFEST_BLOCK)

      client_klass = Class.new(Shared::Entity) do
        self.manifest = shared_klass
        class_exec(&MANIFEST_BLOCK)
        class_exec(&CLIENT_BLOCK)
      end

      server_klass = Class.new(Shared::Entity) do
        self.manifest = shared_klass

        class_exec(&MANIFEST_BLOCK)
        class_exec(&SERVER_BLOCK)
      end

      @client_store_klass = Shared::GeneratedStore.construct(client_klass)

      @client_store = @client_store_klass.new
      @server_store = ServerStore.new(
        attr_1: "attr_1",
        attr_2: "attr_2",
      )
      @server_entity = server_klass.new(
        store: @server_store,
        nesting: "root",
        parent: nil,
      )
      @client_entity = client_klass.new(
        store: @client_store,
        nesting: "root",
        parent: nil
      )

      @server_bridge = Shared::Entities::Bus.new(
        entity: @server_entity
      )

      @client_bridge = Shared::Entities::Bus.new(
        entity: @client_entity
      )
    end

    def test_attribute_flow
      init_event = (
        @server_bridge
          .serialize(
            to: "client",
            action: "after_load",
            nesting: @server_entity.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @client_bridge.handle(event: init_event)

      assert_equal "attr_1", @client_entity.attr_1
      assert_equal "attr_2", @client_entity.attr_2

      @client_entity.attr_1 = "attr_1_updated"

      save_event = (
        @client_bridge
          .serialize(
            to: "server",
            action: "save",
            nesting: @client_entity.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @server_bridge.handle(event: save_event)
      assert_equal "attr_1_updated", @server_entity.attr_1
      assert_equal "attr_2", @server_entity.attr_2
      assert @server_store.saved

      @server_store.attr_2 = "attr_2_server_updated"

      save_response = (
        @server_bridge
          .serialize(
            to: "client",
            action: "after_save",
            nesting: @server_entity.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @client_bridge.handle(event: save_response)

      assert_equal(
        "attr_1_updated - merged",
        @client_entity.attr_1
      )
      assert_equal(
        "attr_2_server_updated - merged",
        @client_entity.attr_2
      )
    end

    # Extended merge logic tests

    class ItemStore < Struct.new(:id, :content, keyword_init: true); end
    class ChildStore < Struct.new(:id, :title, :items, keyword_init: true); end
    class RootStore < Struct.new(:id, :name, :child, keyword_init: true); end

    def test_recursive_and_collection_merge
      # Define Root Class with nested associations
      root_klass = Class.new(Shared::Entity) do
        role(:client)
        accessor(:id)
        accessor(:name)
        action(:after_load)
        server_action(:save)

        merge(:name) do |entity, value|
          entity.name = "DEFAULT MERGED: #{value}"
        end

        reference(:child) do
          accessor(:id)
          accessor(:title)

          merge(:title, :after_save) do |entity, value|
            entity.title = "CHILD MERGED: #{value}"
          end

          collection(:items) do
            accessor(:id)
            accessor(:content)

            merge(:content, :after_save) do |entity, value|
              entity.content = "ITEM MERGED: #{value}"
            end
          end
        end
      end
      root_klass.manifest = root_klass

      # Stores
      item_1_server = ItemStore.new(id: "i1", content: "item 1 content")
      child_server = ChildStore.new(
        id: "c1", title: "child title", items: [item_1_server]
      )
      root_server = RootStore.new(
        id: "r1", name: "root name", child: child_server
      )

      server_entity = root_klass.new(
        store: root_server, nesting: "root", parent: nil
      )
      client_store_klass = Shared::GeneratedStore.construct(root_klass)
      client_entity = root_klass.new(
        store: client_store_klass.new, nesting: "root", parent: nil
      )

      server_bus = Shared::Entities::Bus.new(entity: server_entity)
      client_bus = Shared::Entities::Bus.new(entity: client_entity)

      # 1. Initial Load (action: after_load)
      load_event = (
        server_bus
          .serialize(
            to: "client",
            action: "after_load",
            nesting: server_entity.entity_nesting
          )
          .then { H.j(_1) }
      )
      client_bus.handle(event: load_event)

      assert_equal "DEFAULT MERGED: root name", client_entity.name
      assert_equal "child title", client_entity.child.title
      assert_equal "item 1 content", client_entity.child.items.first.content

      # 2. Save Response (action: after_save)
      root_server.name = "new root name"
      child_server.title = "new child title"
      item_1_server.content = "new item 1 content"

      save_response = (
        server_bus
          .serialize(
            to: "client",
            action: "after_save",
            nesting: server_entity.entity_nesting
          )
          .then { H.j(_1) }
      )
      client_bus.handle(event: save_response)

      assert_equal "DEFAULT MERGED: new root name", client_entity.name
      assert_equal "CHILD MERGED: new child title", client_entity.child.title
      assert_equal "ITEM MERGED: new item 1 content", client_entity.child.items.first.content
    end

    def test_multiple_mergers_for_same_attribute
      klass = Class.new(Shared::Entity) do
        role(:client)
        accessor(:attr)
        action(:event_a)
        action(:event_b)
        action(:event_c)

        merge(:attr, :event_a) { |e, v| e.attr = "A: #{v}" }
        merge(:attr, :event_b) { |e, v| e.attr = "B: #{v}" }
      end
      klass.manifest = klass

      store_klass = Shared::GeneratedStore.construct(klass)
      entity = klass.new(store: store_klass.new, nesting: "root", parent: nil)
      bus = Shared::Entities::Bus.new(entity: entity)

      # Event A
      bus.handle(event: {
        "to" => "client",
        "action" => "event_a",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => "val" } }
      })
      assert_equal "A: val", entity.attr

      # Event B
      bus.handle(event: {
        "to" => "client",
        "action" => "event_b",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => "val" } }
      })
      assert_equal "B: val", entity.attr

      # Unknown event (should use default setter)
      bus.handle(event: {
        "to" => "client",
        "action" => "event_c",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => "val" } }
      })
      assert_equal "val", entity.attr
    end

    def test_default_merger_explicit_override
      klass = Class.new(Shared::Entity) do
        role(:client)
        accessor(:attr)
        action(:specific)
        action(:other)

        merge(:attr) { |e, v| e.attr = "DEFAULT: #{v}" }
        merge(:attr, :specific) { |e, v| e.attr = "SPECIFIC: #{v}" }
      end
      klass.manifest = klass

      store_klass = Shared::GeneratedStore.construct(klass)
      entity = klass.new(store: store_klass.new, nesting: "root", parent: nil)
      bus = Shared::Entities::Bus.new(entity: entity)

      # Specific event
      bus.handle(event: {
        "to" => "client",
        "action" => "specific",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => "val" } }
      })
      assert_equal "SPECIFIC: val", entity.attr

      # Other event
      bus.handle(event: {
        "to" => "client",
        "action" => "other",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => "val" } }
      })
      assert_equal "DEFAULT: val", entity.attr
    end

    def test_nil_value_merging
       klass = Class.new(Shared::Entity) do
        role(:client)
        accessor(:attr)
        action(:test)

        merge(:attr) do |e, v|
          e.attr = v.nil? ? "IS NIL" : "IS NOT NIL: #{v}"
        end
      end
      klass.manifest = klass

      store_klass = Shared::GeneratedStore.construct(klass)
      entity = klass.new(store: store_klass.new, nesting: "root", parent: nil)
      bus = Shared::Entities::Bus.new(entity: entity)

      bus.handle(event: {
        "to" => "client",
        "action" => "test",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => nil } }
      })
      assert_equal "IS NIL", entity.attr

      bus.handle(event: {
        "to" => "client",
        "action" => "test",
        "nesting" => [["root", nil]],
        "payload" => { "attributes" => { "attr" => "something" } }
      })
      assert_equal "IS NOT NIL: something", entity.attr
    end
  end
end
