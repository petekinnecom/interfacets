# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Attributes
        class Collection
          attr_reader :nested, :anonymous, :config, :bind_map

          def initialize(nested:, anonymous:, config:, bind_map:)
            @nested = nested
            @anonymous = anonymous
            @config = config
            @bind_map = bind_map
          end

          def coerce(val, parent:)
            return [] if val.nil?

            val.map { build(attrs: _1, parent:) }
          end

          def build(attrs:, parent:)
            facet.build(
              attrs:,
              binds: bind_map.transform_values { |v| Bind.new(name: v, facet: parent) },
            )
          end

          def serialize(val)
            val.map(&:serialize)
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
