# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      class Serializer
        class << self
          def call(facet)
            {
              facet_class: facet.class.name,
              attributes: facet.entity.serialize,
            }
          end
        end
      end
    end
  end
end
