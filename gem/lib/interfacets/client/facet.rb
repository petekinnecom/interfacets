# frozen_string_literal: true

module Interfacets
  module Client
    class Facet
      class << self
        attr_accessor(
          :shared,
          :entity,
          :view,
          :store,
        )
      end

      attr_reader :entity, :view
      def initialize(entity)
        @entity = entity
        @view = self.class.view.new
      end

      def render(channels)
        view.render(entity:, channels:)
      end
    end
  end
end
