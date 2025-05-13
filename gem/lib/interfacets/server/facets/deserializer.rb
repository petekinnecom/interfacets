# frozen_string_literal: true

module Interfacets
  module Server
    module Facets
      class Deserializer
        class << self
          def call(data:, config:)
            facet_class_name = data.fetch("facet_class")
            attributes = data.fetch("attributes")

            facet = (
              config
                .facet(facet_class_name)
                .build(attributes.fetch("id"))
            )

            facet.entity.ingest(attributes)
            facet
          end
        end
      end
    end
  end
end
