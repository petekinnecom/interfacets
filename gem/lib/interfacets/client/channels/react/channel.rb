# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      module React
        class Channel
          include Channels::Base

          type("interfacets:react-dom")

          def prepare(entity)
            @cache ||= {}

            if entity.internal_entity_id == @builder&.entity&.internal_entity_id
              # keep all the callbacks we've ever assigned, if its the same entity
              # should probably prune these? Only need to remember last renders
              # callbacks?
              builder.__reset__
            else
              @builder = Builder.new(entity, @cache)
            end
          end

          def builder(stream = "default")
            @builder
          end

          def result
            @callbacks = builder.callbacks

            {
              streams: {
                default: { dom: builder.nodes }
              }
            }
          end

          def handle(entity:, event:, build_entity:)
            raise if event.nil?

            actions = [
              "interfacets:react-dom:action",
              "interfacets:react-dom:memoized-action",
              "interfacets:react-dom:online",
            ]

            raise("unknown event: #{event}") unless actions.include?(event.fetch("type"))

            return if event.fetch("type") == "interfacets:react-dom:online"

            payload = event.fetch("payload")
            callback_id = payload.fetch("id")
            callback = @callbacks.fetch(callback_id)
            Evaluator.call(entity, callback, payload["event"])
          end
        end
      end
    end
  end
end
