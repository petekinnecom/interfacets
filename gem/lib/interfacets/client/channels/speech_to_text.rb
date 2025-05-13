# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      class SpeechToText
        include Channels::Base

        type("speechToText")

        class Builder
          attr_accessor :facet
          attr_accessor :entity

          def initialize
            @event = {}
            @callbacks = {}
          end

          def flush_event
            @event.tap { @event = {} }
          end

          def record(
            on_done: ->(*, **) {},
            on_progress: ->(*,**) {},
            on_submit: ->(*, **) {}
          )
            id = SecureRandom.uuid
            @event = {
              id:,
              type: "record",
            }
            @callbacks[id] = {
              on_progress:,
              on_done:,
              on_submit:,
            }
          end

          def callbacks
            @callbacks ||= {}
          end

          def event
            @event ||= {}
          end
        end

        attr_reader :helper

        def prepare(entity)
          @builder ||= Builder.new
          @builder.entity = entity
        end

        def builder(stream = "default")
          @builder
        end

        def handle(event:, entity:, **)
          callback_id = event.dig("payload", "id")

          case event.fetch("type")
          when "text-result"
            builder
              .callbacks
              .delete(callback_id)
              .fetch(:on_done)
              .then do
                entity.instance_exec(event.dig("payload", "text"), &_1)
              end
          when "text-progress"
            builder
              .callbacks
              .fetch(callback_id)
              .fetch(:on_progress)
              .then do
                entity.instance_exec(event.dig("payload", "text"), &_1)
              end
          when "text-submit"
            builder
              .callbacks
              .fetch(callback_id)
              .fetch(:on_submit)
              .then do
                entity.instance_exec(event.dig("payload", "text"), &_1)
              end
          else
            raise "unknown event type: #{event.inspect}"
          end
        end

        def result
          { streams: { default: @builder.flush_event } }
        end
      end
    end
  end
end
