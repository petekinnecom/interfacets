# frozen_string_literal: true

require_relative "./test_helper"

module Interfacets
  class EntityTest < InterfacetsTest

    MANIFEST_BLOCK = ->(*) {
      role(:manifest)

      accessor(:first_name)
      accessor(:last_name)
      accessor(:tos_agreed, accepted_by: :server)
      action(:after_load)
      action(:save, accepted_by: :server)
      action(:after_save, accepted_by: :client)

      association(:phone_number) do
        accessor(:value)
      end

      collection(:hats) do
        accessor(:id)
        accessor(:name)
        action(:nested_save, accepted_by: :server)
        server_action(:nested_server_action)
      end

      def full_name
        [first_name, last_name].join(" ")
      end
    }

    CLIENT_BLOCK = ->(*) {
      role(:client)

      association(:phone_number)
      collection(:hats)

      def after_save
      end

      def after_load
      end
    }

    SERVER_BLOCK = ->(*) {
      role(:server)

      association(:phone_number, builder: -> { PhoneNumber.new })
      collection(:hats, builder: -> { Hat.new }) do
        def full_name
          "full_name: #{name}"
        end

        def nested_save
          @nested_save_called = true
        end

        def nested_save_called?
          @nested_save_called
        end

        def nested_server_action
          @nested_server_action_called = true
        end

        def nested_server_action_called?
          @nested_server_action_called = true
        end
      end

      def save
        store.saved = true
      end
    }

    PhoneNumber = Struct.new(:value)

    Hat = Struct.new(:id, :name)

    ServerStore = Struct.new(
      :first_name,
      :last_name,
      :tos_agreed,
      :phone_number,
      :saved,
      :hats,
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
        first_name: "first_name_value",
        last_name: "last_name_value",
        phone_number: PhoneNumber.new(value: "111"),
        hats: [
          Hat.new(id: "1", name: "hat_1"),
          Hat.new(id: "2", name: "hat_2"),
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

    def test_filters_actions
      assert_raises Shared::Entities::Bus::InvalidAction do
        @server_bridge
          .serialize(
            to: "client",
            action: "invalid_event",
            nesting: @server_entity.entity_nesting,
          )
      end

      assert_raises Shared::Entities::Bus::InvalidAction do
        event = (
          @client_bridge
            .serialize(
              to: "server",
              action: "save",
              nesting: @client_entity.entity_nesting,
            )
            .then { H.j(_1) }
        )

        event["action"] = "after_save"

        @server_bridge.handle(event:)
      end
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

      assert_equal "first_name_value", @client_entity.first_name
      assert_equal "last_name_value", @client_entity.last_name
      assert_equal "first_name_value last_name_value", @client_entity.full_name
      assert_equal "111", @client_entity.phone_number.value
      assert_equal ["hat_1", "hat_2"], @client_entity.hats.map(&:name)

      @client_entity.first_name = "first_name_value_2"
      assert_equal "first_name_value_2", @client_entity.first_name
      assert_equal "last_name_value", @client_entity.last_name
      assert_equal "first_name_value_2 last_name_value", @client_entity.full_name

      assert_equal(
        ["full_name: hat_1", "full_name: hat_2"],
        @server_entity.hats.map(&:full_name)
      )

      @client_entity.phone_number.value = "222"

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
      assert_equal "first_name_value_2", @server_entity.first_name
      assert_equal "last_name_value", @server_entity.last_name
      assert_equal "222", @server_entity.phone_number.value
      assert @server_store.saved

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
    end

    def test_attributes_accepted_by
      @client_entity.tos_agreed = true

      @client_bridge
        .serialize(
          to: "server",
          action: "save",
            nesting: @client_entity.entity_nesting,
        )
        .then { H.j(_1) }
        .then {
          @server_bridge.handle(event: _1)
        }

      assert @server_store.tos_agreed

      @server_store.tos_agreed = "some value"

      @server_bridge
        .serialize(
          to: "client",
          action: "after_save",
          nesting: @server_entity.entity_nesting,
        )
        .then { H.j(_1) }
        .then {
          @client_bridge.handle(event: _1)
        }

      assert_equal true, @client_store.tos_agreed
    end

    def test_deleting_and_creating_an_association
      # Initialize client with server state
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

      # Verify initial association exists
      refute_nil @client_entity.phone_number
      assert_equal "111", @client_entity.phone_number.value

      # Client destroys the association by setting it to nil
      @client_entity.phone_number = nil
      assert_nil @client_entity.phone_number

      # Send deletion to server
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

      # Verify server association is destroyed
      assert_nil @server_entity.phone_number

      # Server creates a new association
      new_phone = @server_entity.association(:phone_number).build
      new_phone.value = "333"
      @server_entity.phone_number = new_phone
      refute_nil @server_entity.phone_number
      assert_equal "333", @server_entity.phone_number.value

      # Send creation to client
      create_response = (
        @server_bridge
          .serialize(
            to: "client",
            action: "after_save",
            nesting: @server_entity.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @client_bridge.handle(event: create_response)

      # Verify client received new association
      refute_nil @client_entity.phone_number
      assert_equal "333", @client_entity.phone_number.value

      # Client creates another association using build method
      new_client_phone = @client_entity.association(:phone_number).build
      new_client_phone.value = "444"
      @client_entity.phone_number = new_client_phone
      assert_equal "444", @client_entity.phone_number.value

      # Send client's new association to server
      final_save_event = (
        @client_bridge
          .serialize(
            to: "server",
            action: "save",
            nesting: @client_entity.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @server_bridge.handle(event: final_save_event)

      # Verify server received client's new association
      refute_nil @server_entity.phone_number
      assert_equal "444", @server_entity.phone_number.value
    end

    def test_collection_adding_new_items
      # Initialize client with server state
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

      # Verify initial hats collection
      assert_equal 2, @client_entity.hats.length
      assert_equal ["hat_1", "hat_2"], @client_entity.hats.map(&:name)

      # Client adds a new hat
      new_hat = @client_entity.association(:hats).build
      new_hat.id = "3"
      new_hat.name = "hat_3"

      assert_equal 3, @client_entity.hats.length
      assert_equal ["hat_1", "hat_2", "hat_3"], @client_entity.hats.map(&:name)

      # Send to server
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

      # Verify server received the new hat
      assert_equal 3, @server_entity.hats.length
      assert_equal ["hat_1", "hat_2", "hat_3"], @server_entity.hats.map(&:name)
      assert_equal ["1", "2", "3"], @server_entity.hats.map(&:id)
    end

    def test_builders_return_entities
      # - Fix GeneratedStore:
      #   - Currently it evals the whole blocks. It should not do that, because then
      #     it picks up all helper methods.
      #   - The way it returns the data is different: An "entity" must wrap any values
      #     it gets. A Store should not wrap. That's the current bug, captured by the
      #     failing test.
      new_hat = @server_entity.association(:hats).build
      new_hat.name = "new_hat"
      assert_equal "full_name: new_hat", new_hat.full_name
    end

    def test_entity_caching__singular
      assert_equal(
        @server_entity.phone_number.object_id,
        @server_entity.phone_number.object_id
      )

      original_phone_number = @server_entity.phone_number

      @server_entity.association(:phone_number).build

      refute_equal(
        original_phone_number,
        @server_entity.phone_number.object_id
      )
    end

    def test_entity_caching__collection
      hat_1_id = @server_entity.hats[0].object_id
      hat_2_id = @server_entity.hats[1].object_id

      assert_equal(
        [hat_1_id, hat_2_id],
        @server_entity.hats.map(&:object_id)
      )

      @server_entity.association(:hats).build
      assert_equal 3, @server_entity.hats.count
      hat_3_id = @server_entity.hats.last.object_id

      assert_equal(
        [hat_1_id, hat_2_id, hat_3_id],
        @server_entity.hats.map(&:object_id)
      )

      assert @server_entity.hats.include?(@server_entity.hats.first)

      @server_entity.hats.delete(@server_entity.hats.first)
      assert_equal(
        [hat_2_id, hat_3_id],
        @server_entity.hats.map(&:object_id)
      )
    end

    def test_paths
      if_id = @server_entity.internal_entity_id
      assert if_id

      ph_id = @server_entity.phone_number.internal_entity_id
      assert ph_id

      assert_equal(
        [["root", if_id]],
        @server_entity.entity_nesting
      )
      assert_equal(
        [["root", if_id], ["phone_number", ph_id]],
        @server_entity.phone_number.entity_nesting
      )

      hat_id = @server_entity.hats.first.internal_entity_id
      assert hat_id
      assert_equal(
        [["root", if_id], ["hats", hat_id]],
        @server_entity.hats.first.entity_nesting
      )

      # ensure they make it across the wire
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

      hat = @client_entity.association(:hats).build
      hat.name = "new_hat"
      hat_if_id = hat.internal_entity_id
      assert hat_if_id

      event = (
        @client_bridge
          .serialize(
            to: "server",
            action: "save",
            nesting: @client_entity.entity_nesting,
          )
          .then { H.j(_1) }
      )

      hat_if_ids = @server_entity.hats.map(&:internal_entity_id)
      @server_bridge.handle(event:)

      assert_equal(
        hat_if_ids + [hat_if_id],
        @server_entity.hats.map(&:internal_entity_id)
      )
    end

    def test_parent
      assert_equal(
        @server_entity,
        @server_entity.phone_number.parent
      )
      assert_equal(
        @server_entity,
        @server_entity.hats.first.parent
      )
    end

    def test_nested_action
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

      event = (
        @client_bridge
          .serialize(
            to: "server",
            action: "nested_save",
            nesting: @client_entity.hats.first.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @server_bridge.handle(event:)

      assert @server_entity.hats.first.nested_save_called?
    end

    def test_nested_server_action
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

      event = (
        @client_bridge
          .serialize(
            to: "server",
            action: "nested_server_action",
            nesting: @client_entity.hats.first.entity_nesting,
          )
          .then { H.j(_1) }
      )

      @server_bridge.handle(event:)

      assert @server_entity.hats.first.nested_server_action_called?
    end

    def test_collection_proxy
      assert_equal 2, @server_entity.hats.count
      assert_equal 2, @server_store.hats.count
      @server_entity.hats.delete_at(0)
      assert_equal 1, @server_store.hats.count
      assert_equal 1, @server_entity.hats.count
    end

    def test_entity_at
      assert_equal(
        @server_entity,
        @server_entity.entity_at(@server_entity.entity_nesting)
      )

      assert_equal(
        @server_entity.hats.first,
        @server_entity.entity_at(@server_entity.hats.first.entity_nesting)
      )

      assert_equal(
        @server_entity.hats.last,
        @server_entity.entity_at(@server_entity.hats.last.entity_nesting)
      )
    end
  end
end
