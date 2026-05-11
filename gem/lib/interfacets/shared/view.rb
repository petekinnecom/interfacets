# frozen_string_literal: true

module Interfacets
  module Shared
    class View
      class Evaluator
        def self.call(**p)
          new(**p).call
        end

        attr_reader :entity, :channels, :block
        def initialize(entity:, channels:, block:)
          @entity = entity
          @channels = channels
          @block = block
          @data = Hash.new { |h, k| h[k] = { streams: {} } }
        end

        def call
          instance_exec(entity, &@block)
        end

        def render(entity)
          entity
            .class
            .view
            .render(
              entity:,
              channels:
            )
        end

        def render_to(channel_id, stream: "default", &block)
          channel_id = channel_id.to_s

          channels
            .fetch(channel_id)
            .builder(stream.to_s)
            .then { @current_builder = _1 }
            .then { instance_exec(_1, &block) }
        end

        def channel(name)
          @channels.fetch(name)
        end
      end

      class << self
        def view(&block)
          @view = block if block_given?
          @view
        end

        def view=(val)
          @view = val
        end

        def render(**p)
          new.render(**p)
        end
      end

      def render(entity:, channels:)
        return unless self.class.view

        Evaluator.call(
          entity: entity,
          channels: channels,
          block: self.class.view
        )
      end
    end
  end
end
