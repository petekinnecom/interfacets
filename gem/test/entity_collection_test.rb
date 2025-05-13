# frozen_string_literal: true

require_relative "./test_helper"
require "ostruct"

module Interfacets
  class EntityCollectionTest < InterfacetsTest

    MANIFEST_BLOCK = ->(*) {
      role(:manifest)

      action(:after_load, accepted_by: :client)
      action(:save, accepted_by: :server)

      collection(
        :hats,
        builder: -> { Hat.new },
      ) do
        accessor(:id)
        accessor(:other)
      end

      collection(
        :shoes,
        identifier: :name,
        builder: -> { Shoe.new }
      ) do
        accessor(:name)
        accessor(:other)
      end
    }

    CLIENT_BLOCK = ->(*) {
      role(:client)

      def after_load
      end
    }

    SERVER_BLOCK = ->(*) {
      role(:server)

    }

    Hat = Struct.new(:id, :other)
    Shoe = Struct.new(:name, :other)

    ServerStore = OpenStruct

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
        hats: [
          Hat.new(id: "1", other: "1"),
          Hat.new(id: "2", other: "2"),
        ],
        shoes: [
          Shoe.new(name: "a", other: "A"),
          Shoe.new(name: "b", other: "B"),
        ]
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

      assert_equal ["1", "2"], @client_entity.hats.map(&:id)
      assert_equal ["a", "b"], @client_entity.shoes.map(&:name)

      @client_entity.association(:hats).build(id: "3", other: "3")
      @client_entity.association(:shoes).build(name: "c", other: "C")

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
    end

    def test_collection_items_with_nil_identifier
      # Test that items with nil identifiers are treated as new items
      # even if other items exist in the collection

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

      # Initial state: 2 hats with ids "1" and "2"
      assert_equal 2, @client_entity.hats.size
      assert_equal ["1", "2"], @client_entity.hats.map(&:id)

      # Now simulate receiving an update with nil id items
      # These should be added as new items, not matched to existing ones
      update_event = H.j({
        "id" => SecureRandom.uuid,
        "from" => "server",
        "to" => "client",
        "nesting" => @client_entity.entity_nesting,
        "action" => "after_load",
        "payload" => {
          "attributes" => {
            "hats" => [
              { "id" => "1", "other" => "updated-1" },  # existing item
              { "id" => nil, "other" => "nil-item-1" }, # new item with nil id
              { "id" => nil, "other" => "nil-item-2" }, # another new item with nil id
            ]
          }
        }
      })

      @client_bridge.handle(event: update_event)

      # Should have 3 items total: 1 matched, 2 new (with nil ids)
      assert_equal 3, @client_entity.hats.size

      # First item should be the updated existing one
      assert_equal "1", @client_entity.hats[0].id
      assert_equal "updated-1", @client_entity.hats[0].other

      # Next two should be new items with nil ids
      assert_nil @client_entity.hats[1].id
      assert_equal "nil-item-1", @client_entity.hats[1].other

      assert_nil @client_entity.hats[2].id
      assert_equal "nil-item-2", @client_entity.hats[2].other
    end

    def test_collection_items_all_nil_identifiers
      # Test case where all incoming items have nil identifiers
      # All should be created as new items

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

      # Start with 2 hats
      assert_equal 2, @client_entity.hats.size

      # Send update with all nil identifiers
      update_event = H.j({
        "id" => SecureRandom.uuid,
        "from" => "server",
        "to" => "client",
        "nesting" => @client_entity.entity_nesting,
        "action" => "after_load",
        "payload" => {
          "attributes" => {
            "hats" => [
              { "id" => nil, "other" => "first" },
              { "id" => nil, "other" => "second" },
              { "id" => nil, "other" => "third" },
            ]
          }
        }
      })

      @client_bridge.handle(event: update_event)

      # Should create 3 new items, replacing the collection
      assert_equal 3, @client_entity.hats.size
      assert @client_entity.hats.all? { |hat| hat.id.nil? }
      assert_equal ["first", "second", "third"], @client_entity.hats.map(&:other)
    end

    def test_collection_items_nil_identifier_doesnt_match_existing_nil
      # Test that items with nil identifiers never match existing items,
      # even if existing items also have nil identifiers

      # Manually set up client with items that have nil ids
      @client_store.hats = [
        Hat.new(id: nil, other: "existing-nil-1"),
        Hat.new(id: nil, other: "existing-nil-2"),
      ]

      # Send update with nil identifiers
      update_event = H.j({
        "id" => SecureRandom.uuid,
        "from" => "server",
        "to" => "client",
        "nesting" => @client_entity.entity_nesting,
        "action" => "after_load",
        "payload" => {
          "attributes" => {
            "hats" => [
              { "id" => nil, "other" => "new-nil-1" },
              { "id" => nil, "other" => "new-nil-2" },
            ]
          }
        }
      })

      @client_bridge.handle(event: update_event)

      # Should have 2 new items (not matched to existing nil items)
      assert_equal 2, @client_entity.hats.size
      assert_equal ["new-nil-1", "new-nil-2"], @client_entity.hats.map(&:other)
    end

    def test_collection_with_string_identifier_and_nil_values
      # Test the shoes collection which uses :name as identifier
      # to ensure nil name handling works correctly

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

      # Initial state: 2 shoes with names "a" and "b"
      assert_equal 2, @client_entity.shoes.size
      assert_equal ["a", "b"], @client_entity.shoes.map(&:name)

      # Update with mix of valid names and nil names
      update_event = H.j({
        "id" => SecureRandom.uuid,
        "from" => "server",
        "to" => "client",
        "nesting" => @client_entity.entity_nesting,
        "action" => "after_load",
        "payload" => {
          "attributes" => {
            "shoes" => [
              { "name" => "a", "other" => "updated-A" },  # existing item
              { "name" => nil, "other" => "nil-shoe-1" }, # new item with nil name
              { "name" => "c", "other" => "new-C" },      # new item with valid name
            ]
          }
        }
      })

      @client_bridge.handle(event: update_event)

      # Should have 3 items
      assert_equal 3, @client_entity.shoes.size

      # First should be updated existing
      assert_equal "a", @client_entity.shoes[0].name
      assert_equal "updated-A", @client_entity.shoes[0].other

      # Second should be new with nil name
      assert_nil @client_entity.shoes[1].name
      assert_equal "nil-shoe-1", @client_entity.shoes[1].other

      # Third should be new with valid name
      assert_equal "c", @client_entity.shoes[2].name
      assert_equal "new-C", @client_entity.shoes[2].other
    end
  end
end
