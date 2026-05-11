# frozen_string_literal: true

module Interfacets
  module Shared
    module Entities
      module Specs
        module Handlers
          class Handler
            attr_reader :entity, :spec, :cache
            def initialize(entity:, spec:)
              @entity = entity
              @spec = spec
              @cache = {}
            end

            def type
              spec.type
            end

            def unwrap(value)
              if value.is_a?(Entity)
                value.store
              elsif value.is_a?(Array)
                value.map { unwrap(_1) }
              else
                value
              end
            end

            def wrap(value)
              if value.is_a?(Entity)
                value
              elsif cache[value]
                cache[value]
              elsif value
                @cache[value] = spec.klass.new(
                  store: value,
                  nesting: spec.name,
                  parent: entity,
                )
              end
            end
          end

          class Reference < Handler
            def collection?
              false
            end

            def reference?
              true
            end

            def get
              wrap(entity.instance_exec(&spec.getter))
                .tap {
                  @cache = {}
                  @cache[_1&.store] = _1
                }
            end

            def set(val)
              entity.instance_exec(unwrap(val), &spec.setter)
              wrap(val)
            end

            def build(**attributes)
              value = entity.instance_exec(&spec.builder)
              attributes.each do |name, val|
                value.send("#{name}=", val)
              end

              # TODO: make sure this is right
              # set(value)

              wrap(value)
            end
          end

          class Collection < Handler
            def collection?
              true
            end

            def reference?
              false
            end

            def get
              values = entity.instance_exec(&spec.getter) || []

              CollectionProxy.new(
                values,
                wrap: ->(val) { wrap(val) },
                unwrap: ->(val) { unwrap(val) },
              ).tap { |entities|
                @cache = entities.map { [_1.store, _1] }.to_h
              }
            end

            def set(val)
              @cache ||= {}
              val.each do |item|
                if item.is_a?(Entity)
                  @cache[item.store] = item
                end
              end

              entity.instance_exec(unwrap(val), &spec.setter)
            end

            def build(**attributes)
              value = unwrap(entity.instance_exec(&spec.builder))
              attributes.each do |name, val|
                value.send("#{name}=", val)
              end

              items = entity.instance_exec(&spec.getter)

              if items.nil?
                set([value])
              elsif !items.include?(value)
                items << value
              end

              wrap(value)
            end
          end
        end
      end
    end
  end
end
