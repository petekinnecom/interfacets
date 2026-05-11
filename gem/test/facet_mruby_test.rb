# frozen_string_literal: true

require_relative "./test_helper"
require_relative "./fixtures/test_facet"

require "logger"

module Interfacets
  class FacetMrubyTest < InterfacetsTest
    def setup
      super
      @db = { "1" => Interfacets::Test::Person.new(id: "1", name: "name_value") }
      Interfacets::Test::TestFacet.db = @db
    end

    def test_data_flow
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [File.expand_path("./fixtures", __dir__)],
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/person" => Interfacets::Test::TestFacet
        }
      )

      ui = Test::UiSimulator.new(
        bus: server_bus,
        router: router,
        type: :nodo,
      )

      ui.visit("/person/1")
      assert_equal "name_value", ui.dom.one("div").content
      ui.dom.one("div").trigger("onClick")
      assert_equal "clicked", ui.dom.one("div").content

      ui.dom.one("button").trigger("onClick")
      assert @db.fetch("1").saved
      assert_equal "root_url/person/1", ui.url.url
    end
  end
end
