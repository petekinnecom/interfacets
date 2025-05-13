# frozen_string_literal: true

require_relative "./test_helper"

require "logger"

module Interfacets
  class FacetTest < InterfacetsTest

    Person = Struct.new(:id, :name, :saved)

    class TestFacet
      include Interfacets::Server::Facet
      include Interfacets::Server::BasicRoutable

      class << self
        attr_accessor :db
      end

      find do |id, query:|
        build(self, TestFacet.db.fetch(id))
      end

      view do |person|
        render(:url) do |c|
          c.path(person.api_path)
        end

        render(:dom) do |c|
          c.div(onClick: ->(e) { person.name = "clicked" }) do
            c.str(person.name)
          end

          c.button("save", onClick: -> { person.save })
        end
      end

      client do
        role("client")
      end

      shared do
        accessor(:id, accepted_by: :client)
        accessor(:name)

        server_action(:save)
      end

      server do
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
      assert_equal "name_value", browser.dom.one("div").content
      browser.dom.one("div").trigger("onClick")
      assert_equal "clicked", browser.dom.one("div").content

      browser.dom.one("button").trigger("onClick")
      assert @db.fetch("1").saved
      assert_equal "root_url/person/1", browser.url.url
    end
  end
end
