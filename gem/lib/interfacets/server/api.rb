# frozen_string_literal: true

module Interfacets
  module Server
    class Api
      class Channel
        attr_reader :klass, :store

        def rendered?
          @rendered
        end

        def render(klass, store)
          @rendered = true
          @klass = klass
          @store = store
        end
      end

      attr_reader :entity, :name, :registry
      def initialize(entity:, name:, registry:)
        @entity = entity
        @name = name
        @registry = registry
      end

      def handle(event)
        channel = Channel.new

        entity.channel = channel
        Shared::Entities::Bus
          .new(entity:)
          .handle(event:)

        if entity.channel.rendered?
          registry.build(
            channel.klass,
            channel.store,
          ).render
        else
          emit("after_#{event.fetch("action")}")
        end
      end

      def render
        emit("after_load")
      end

      private

      def emit(action)
        {
          facet: name,
          payload: (
            Shared::Entities::Bus
              .new(entity:)
              .serialize(to: "client", action:, nesting: ["root"])
          )
        }
      end

    end
  end
end
