# frozen_string_literal: true

require "active_support/all"
require "ostruct"

module Interfacets
  module Server
    class Registry
      class Channel
        def initialize(registry:)
          @registry = registry
        end

        def build(...)
          @registry.build(...)
        end

        def render_facet
          @facet.render
        end

        def rendered?
          @facet
        end

        def render(klass, store)
          @facet = @registry.build(klass, store)
        end
      end

      def build(name, store)
        facet = name.is_a?(Module) ? name : Object.const_get(name)

        Api.new(
          registry: self,
          name:,
          entity: (
            facet
              .server_entity_class
              .new(
                store: store.is_a?(Hash) ? OpenStruct.new(store) : store,
                nesting: "root",
                parent: nil,
                channel: Channel.new(registry: self)
              )
          )
        )
      end
    end
  end
end
