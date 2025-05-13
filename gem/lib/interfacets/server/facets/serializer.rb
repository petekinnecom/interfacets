# frozen_string_literal: true

module Interfacets
  module Server
    module Facets
      class Serializer
        def self.call(...)
          new(...).call
        end

        attr_reader :facet, :mount_point
        def initialize(facet, mount_point)
          @facet = facet
          @mount_point = mount_point
        end

        def call
          {
            id: facet.entity.id,
            facet_class: facet.class.name,
            attributes: facet.entity.serialize,
          }
        end

        def attributes(entity)
          entity
            .attribute_specs
            .each_with_object({}) { |(name, _attribute), json|
              # refactor this, shouldn't be attributes...
              # next if attribute.is_a?(Facets::Attributes::ClientEvent)
              # next if attribute.is_a?(Facets::Attributes::ServerEvent)
              # next if attribute.is_a?(Facets::Attributes::Inherit)

              value = entity.public_send(name)

              json[name] = (
                if value.is_a?(Array)
                  value.map { _1.is_a?(Entity) || _1.is_a?(Facet::Handler) ? attributes(_1) : _1 }
                elsif value.is_a?(Entity) || value.is_a?(Facet::Handler)
                  attributes(value)
                else
                  value
                end
              )
            }
        end
      end
    end
  end
end
