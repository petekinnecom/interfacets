# frozen_string_literal: true

module Interfacets
  module Client
    class View
      class Evaluator
        def self.call(...)
          new(...).call
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

        def render(channel_id, stream: "default", &block)
          channels
            .fetch(channel_id.to_s)
            .builder(stream.to_s)
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
      end

      def render(entity:, channels:)
        Evaluator.call(entity: entity, channels:, block: self.class.view)
      end
    end
  end
end
