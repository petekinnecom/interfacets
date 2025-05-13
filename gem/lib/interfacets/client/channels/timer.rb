# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      class Timer
        include Channels::Base

        type("interfacets:timer")

        class Builder
          attr_reader :event, :callbacks

          def initialize
            @event = {}
            @callbacks = {}
          end

          def flush_event
            @event.tap { @event = {} }
          end

          def callback(in_ms:, &block)
            id = SecureRandom.uuid
            event[:ms] = in_ms
            event[:response] = { id: }
            callbacks[id] = block
          end
        end

        def prepare(entity)
          @builder ||= Builder.new
        end

        def builder(stream = "defualt")
          @builder
        end

        def handle(event:, entity:, **)
          callback_id = event.dig("payload", "id")
          entity.instance_exec(&builder.callbacks.fetch(callback_id))
          builder.callbacks.delete(callback_id)
        end

        def result
          { streams: { default: @builder.flush_event } }
        end
      end
    end
  end
end
