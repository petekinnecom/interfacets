# frozen_string_literal: true

module Interfacets
  module Test
    Person = Struct.new(:id, :name, :saved)

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
          end

          c.button("save", onClick: -> { person.save })
        end
      end

      client_entity do
        role("client")
      end

      entity_base do
        accessor(:id, accepted_by: :client)
        accessor(:name)

        server_action(:save)
      end

      server_entity do
        find do |id, query:|
          build(self, TestFacet.db.fetch(id))
        end

        def save
          store.saved = true
        end
      end
    end
  end
end
