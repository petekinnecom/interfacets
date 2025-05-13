# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      class Audio
        include Channels::Base

        type("interfacets:audio")

        class Builder
          attr_reader :event, :callbacks
          attr_accessor :entity

          def initialize
            @event = {}
            @callbacks = {}
          end

          def flush_event
            @event.tap { @event = {} }
          end

          def play(sounds, reset_offset: false)
            event[:type] = "play"
            event[:payload] ||= { sounds:, resetOffset: reset_offset }
          end

          def load_audios(audios, &block)
            id = SecureRandom.uuid
            @event = {
              id:,
              type: "load",
              payload: audios,
            }
            @callbacks[id] = block
          end

          def request_mic(&block)
            id = SecureRandom.uuid
            @callbacks[id] = block
            @event = {
              id:,
              type: "request-mic",
              payload: {},
            }
          end

          def start_recording(&block)
            id = SecureRandom.uuid
            @callbacks[id] = block
            @event = {
              id:,
              type: "start-record",
              payload: {},
            }
          end

          def stop_recording(&block)
            id = SecureRandom.uuid
            @callbacks[id] = block
            @event = {
              id:,
              type: "stop-record",
              payload: {},
            }
          end
        end

        def prepare(entity)
          @builder ||= Builder.new
        end

        def builder(stream = "default")
          @builder
        end

        def handle(event:, entity:, **)
          return unless [
            "loaded",
            "mic-ready",
            "recording-started",
            "recording-stopped",
          ].include?(event.fetch("type"))

          callback_id = event.dig("payload", "id")
          callback = builder.callbacks.delete(callback_id)
          if event["payload"].nil? || event["payload"].empty?
            entity.instance_exec(&callback) if callback
          elsif callback
            entity.instance_exec(event.fetch("payload"), &callback)
          end
        end

        def result
          { streams: { default: @builder.flush_event } }
        end
      end
    end
  end
end
