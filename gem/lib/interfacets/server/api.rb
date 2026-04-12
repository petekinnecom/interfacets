# frozen_string_literal: true

module Interfacets
  module Server
    class Api
      attr_reader :entity, :name, :registry
      def initialize(entity:, name:, registry:)
        @entity = entity
        @name = name
        @registry = registry
      end

      def handle(event)
        Shared::Entities::Bus
          .new(entity:)
          .handle(event:)

        if entity.channel.rendered?
          entity.channel.render_facet
        else
          emit("after_#{event.fetch("action")}", nesting: event.fetch("nesting"))
        end
      end

      def render
        emit("after_load", nesting: ["root"])
      end

      private

      def emit(action, nesting: )
        {
          facet: name,
          payload: (
            Shared::Entities::Bus
              .new(entity:)
              .serialize(to: "client", action:, nesting:)
          )
        }
      end

    end
  end
end
