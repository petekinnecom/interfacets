# frozen_string_literal: true

# This pipes messages through channels. This allows channel authors to intercept
# and incoming and outgoing messages and dropping/ignoring/updating their own state

module Interfacets
  module Client
    class Bus
      attr_reader(
        :id,
        :channels,
        :channel_index,
        :registry,
        :entity,
        :root_url,
      )

      def initialize(
        id:,
        channels:,
        root_url:
      )
        @id = id
        @channels = channels
        @registry = Registry.new
        @channel_index = channels.map { [_1.id, _1] }.to_h
        @root_url = root_url
      end

      def url_for(path)
        [
          root_url,
          path,
        ]
          .map { _1.sub(%r{/$}, "").sub(%r{^/}, "") }
          .join("/")
      end

      def channel(name)
        channel_index.fetch(name.to_s)
      end

      def handle(event)
        channel_id = event.dig("destination", "channel")
        raise("unknown event: #{event.inspect}") unless channel_id
        channel = channel_index.fetch(channel_id)

        channel.handle(
          entity: @entity,
          event: event.fetch("payload"),
          build_entity: ->(name) { @entity = registry.build(name) }
        )

        channel_index.values.each { _1.prepare(entity) }

        entity.class.view.new.render(entity:, channels: channel_index)

        {
          type: "interfacets:bus:render",
          id: id,
          payload: (
            channel_index
              .map { |name, chann| { id: name, payload: chann.result } }
          )
        }
      end
    end
  end
end
