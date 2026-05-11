# frozen_string_literal: true

require_relative "../test_helper"

require "logger"

module Interfacets
  class FacetNestedMountTest < InterfacetsTest

    Person = Struct.new(:id, :name)

    module PersonFacet
      include Interfacets::Shared::Facet

      view do |person|
        render_to(:dom) do |c|
          c.div(person.name, class: "person-name")
        end
      end

      entity_base do
        accessor(:id, accepted_by: :client)
        accessor(:name)
      end
    end

    module LayoutFacet
      include Interfacets::Shared::Facet

      view do |layout|
        render_to(:dom) do |c|
          c.div(class: "layout-container") do
            render(layout.content)
          end
        end
      end
    end

    module PersonShowFacet
      include Interfacets::Shared::Facet
      include Interfacets::Shared::BasicRoutable

      mount(LayoutFacet, as: :layout, type: :reference) do
        mount(PersonFacet, as: :content, type: :reference)
      end

      view do |page|
        render_to(:dom) do |c|
          render(page.layout)
        end
      end

      server_entity do
        find do |id, query:|
          person = Person.new(id: id.to_i, name: "pete #{id}")
          build(self, layout: OpenStruct.new(content: person))
        end
      end
    end

    def test_nested_data_flow
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/person" => PersonShowFacet
        }
      )

      ui = Test::UiSimulator.new(
        bus: server_bus,
        router: router,
        type: :inline,
      )

      ui.visit("/person/123")

      layout_container = ui.dom.one(".layout-container")
      assert layout_container

      name_div = layout_container.one(".person-name")
      assert_equal "pete 123", name_div.content
    end
  end
end
