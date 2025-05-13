# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Attributes
        class Association
          attr_reader :nested, :anonymous, :config, :bind_map

          def initialize(nested:, anonymous:, config:, bind_map:)
            @nested = nested
            @anonymous = anonymous
            @config = config
            @bind_map = bind_map
          end

          def coerce(val, parent:)
            return if val.nil?

            facet.build(
              attrs: val,
              binds: bind_map.transform_values { |v| Bind.new(name: v, facet: parent) },
            )
          end

          def build(attrs:, parent:)
            facet.build(
              attrs:,
              binds: bind_map.transform_values { |v| Bind.new(name: v, facet: parent) },
            )
          end

          def serialize(val)
            val&.serialize
          end

          def facet
            @facet ||= (
              if anonymous
                @nested
              else
                config.schema(@nested.fetch("name"))
              end
            )
          end
        end
      end
    end
  end
end
