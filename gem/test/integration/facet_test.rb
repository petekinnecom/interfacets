# frozen_string_literal: true

require_relative "../test_helper"

require "logger"

module Interfacets
  class FacetTest < InterfacetsTest

    Person = Struct.new(:id, :name, :saved, :timer_fired)

    module TestFacet
      include Interfacets::Shared::Facet
      include Interfacets::Shared::BasicRoutable

      class << self
        attr_accessor :db
      end

      view do |person|
        render_to(:url) do |c|
          c.path(person.api_path)
        end

        render_to(:dom) do |c|
          c.div(onClick: ->(e) { person.name = "clicked" }) do
            c.str(person.name)
            # c.str("😅")
          end

          c.button("save", onClick: -> { person.save })
          c.button("start_timer", onClick: -> { person.setup_timer })

          c.div(person.timer_fired ? "Timer fired!" : "Timer not fired")
        end
      end

      client_entity do
        role("client")

        def setup_timer
          channel(:timer).callback(in_ms: 1 * 1000.0) do
            self.timer_fired = true
          end
        end
      end

      entity_base do
        accessor(:id, accepted_by: :client)
        accessor(:name)
        accessor(:timer_fired, accepted_by: :client)

        server_action(:save)
      end

      server_entity do
        find do |id, query:|
          build(self, TestFacet.db.fetch(id))
        end

        role("server")

        def save
          store.saved = true
        end
      end
    end

    def setup
      super
      @db = { "1" => Person.new(id: "1", name: "name_value") }
      TestFacet.db = @db
    end

    def test_data_flow
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/person" => TestFacet
        }
      )

      ui = Test::UiSimulator.new(
        bus: server_bus,
        router: router,
        type: :inline,
      )

      ui.visit("/person/1")
      name_div = ui.dom.all("div").first
      assert_equal "name_value", name_div.content
      name_div.trigger("onClick")
      assert_equal "clicked", ui.dom.all("div").first.content

      ui.dom.one("button", content: "save").trigger("onClick")
      assert @db.fetch("1").saved
      assert_equal "root_url/person/1", ui.url.url
    end

    def test_timer_callback
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
         paths: {
          "/person" => TestFacet
        }
      )

      ui = Test::UiSimulator.new(
        bus: server_bus,
        router: router,
        type: :inline,
      )

      ui.visit("/person/1")
      person = @db.fetch("1")

      # Verify timer hasn't fired yet
      assert_equal "Timer not fired", ui.dom.all("div").last.content

      # Click the start_timer button to register a timer callback
      ui.dom.one("button", content: "start_timer").trigger("onClick")

      # Verify a timer was registered
      assert_equal 1, ui.timers.registrations.size
      assert_equal 1000.0, ui.timers.first.ms

      # Manually trigger the timer to simulate the timeout firing
      ui.timers.first.notify

      # Verify the callback was executed and the view updated
      assert_equal "Timer fired!", ui.dom.all("div").last.content
    end

    def test_inheritance
      assert TestFacet.server_entity_class < TestFacet.entity_base_class
      assert TestFacet.entity_base_class < Shared::Entity

      # Inherited from entity_base
      assert TestFacet.server_entity_class.accessors.key?("id")
      assert TestFacet.server_entity_class.accessors.key?("name")
      assert TestFacet.server_entity_class.actions.key?("save")

      # Local to server_entity or explicitly set in server_entity_class
      assert_equal "server", TestFacet.server_entity_class.role
    end
  end
end
