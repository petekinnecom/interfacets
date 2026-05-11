# frozen_string_literal: true

require_relative "../test_helper"

require "logger"

module Interfacets
  class FacetMountTest < InterfacetsTest

    Person = Struct.new(:id, :name)
    Header = Struct.new(:title)

    module HeaderFacet
      include Interfacets::Shared::Facet

      view do |header|
        render_to(:dom) do |c|
          c.h1(header.title)
        end
      end

      entity_base do
        accessor(:title, accepted_by: :client)
      end
    end

    module PersonFacet
      include Interfacets::Shared::Facet

      view do |person|
        render_to(:url) do |c|
          c.path("nope")
        end

        render_to(:dom) do |c|
          c.div(person.name_with_title)
        end

      end

      client_entity do
        def name_with_title
          "#{title} #{name}"
        end
      end

      entity_base do
        accessor(:id, accepted_by: :client)
        accessor(:name)
        accessor(:title, accepted_by: :client)
      end

      server_entity do
        def title
          "Sir/Madam"
        end
      end
    end

    module ListFacet
      include Interfacets::Shared::Facet
      include Interfacets::Shared::BasicRoutable

      class << self
        attr_accessor :persons
      end

      mount(HeaderFacet, as: :header, type: :reference)
      mount(PersonFacet, as: :persons, type: :collection)

      view do |list|
        render_to(:dom) do |c|
          render(list.header)

          list.persons.each do |person|
            render(person)
          end
        end
      end

      server_entity do
        find do |id, query:|
          build(self, id: nil, header: Header.new("People List"), persons: ListFacet.persons)
        end
      end
    end

    def setup
      super
      ListFacet.persons = [
        Person.new(id: 1, name: "pete"),
        Person.new(id: 2, name: "repeat"),
      ]
    end

    def test_data_flow
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/list" => ListFacet
        }
      )

      ui = Test::UiSimulator.new(
        bus: server_bus,
        router: router,
        type: :inline,
      )

      ui.visit("/list")
      h1s = ui.dom.all("h1").map(&:content)
      assert_equal ["People List"], h1s

      name_divs = ui.dom.all("div").map(&:content)
      assert_equal ["Sir/Madam pete", "Sir/Madam repeat"], name_divs
    end
  end
end
