# frozen_string_literal: true

require_relative "./test_helper"

require "logger"

module Interfacets
  class FacetTest < InterfacetsTest

    Person = Struct.new(:id, :name, :saved, :timer_fired)

    class TestFacet
      include Interfacets::Server::Facet
      include Interfacets::Server::BasicRoutable

      class << self
        attr_accessor :db
      end

      view do |person|
        render(:url) do |c|
          c.path(person.api_path)
        end

        render(:dom) do |c|
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
        facets: [TestFacet],
        build_dir: "./tmp/build"
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/person" => TestFacet
        }
      )

      browser = Test::Browser.new(
        system_json: H.j(server_bus.client_system_json),
        router:,
        type: :inline,
      )

      browser.visit("/person/1")
      name_div = browser.dom.all("div").first
      assert_equal "name_value", name_div.content
      name_div.trigger("onClick")
      assert_equal "clicked", browser.dom.all("div").first.content

      browser.dom.one("button", content: "save").trigger("onClick")
      assert @db.fetch("1").saved
      assert_equal "root_url/person/1", browser.url.url
    end

    def test_timer_callback
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
        facets: [TestFacet],
        build_dir: "./tmp/build"
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/person" => TestFacet
        }
      )

      browser = Test::Browser.new(
        system_json: H.j(server_bus.client_system_json),
        router:,
        type: :inline,
      )

      browser.visit("/person/1")
      person = @db.fetch("1")

      # Verify timer hasn't fired yet
      assert_equal "Timer not fired", browser.dom.all("div").last.content

      # Click the start_timer button to register a timer callback
      browser.dom.one("button", content: "start_timer").trigger("onClick")

      # Verify a timer was registered
      assert_equal 1, browser.timers.registrations.size
      assert_equal 1000.0, browser.timers.first.ms

      # Manually trigger the timer to simulate the timeout firing
      browser.timers.first.notify

      # Verify the callback was executed and the view updated
      assert_equal "Timer fired!", browser.dom.all("div").last.content
    end
  end
end
