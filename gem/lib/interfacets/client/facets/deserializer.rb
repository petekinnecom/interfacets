# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      class Deserializer
        def self.call(data:, config: Client.system.config)
          Logger.main.debug("deserializing facet: #{data.fetch("facet_class")}")

          klass = Object.const_get(data.fetch("facet_class"))

          Logger.main.debug("constructing: #{klass.client.name}")

          facet = klass.new

          entity = (
            klass
              .client
              .build(data.fetch("attributes"), parent: nil, facet:)
          )

          Logger.main.debug("entity constructed")

          facet.entity = entity
          facet
        end
      end
    end
  end
end
