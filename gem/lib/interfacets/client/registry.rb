# frozen_string_literal: true

module Interfacets
  module Client
    class Registry
      def initialize
        @stores = {}
      end

      def build(name, id)
        entity = Object.const_get(name).client_entity_class

        @stores[id] ||= entity.store.new

        entity.new(
          store: @stores[id],
          parent: nil,
          nesting: ["root"]
        )
      end
    end
  end
end
