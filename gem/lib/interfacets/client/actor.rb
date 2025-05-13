# frozen_string_literal: true

module Interfacets
  module Client
    class Actor
      attr_reader :registry, :facet
      def initialize(registry:, channels:)
        @registry = registry
      end

      def build_facet(name)
        @facet = registry.build(name)
      end

      def render
        facet.render(channels)
      end
    end
  end
end
