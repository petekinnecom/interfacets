# frozen_string_literal: true

module Interfacets
  module Client
    class System
      module Transmit
        def self.call(data)
          Kernel.js_eval("self.rubyEvent(#{data.to_json})")
        end
      end

      class << self
        attr_accessor(
          :current_bus,
          :logger,
        )

        def logger
          @logger ||= InterfacetsLogger.main
        end

        def start(transmit: Transmit)
          @instance = new(transmit)
        end
      end

      attr_accessor :transmit
      def initialize(transmit)
        @transmit = transmit
      end

      def handle(event)
        if event.fetch("type") == "interfacets:system:create_bus"
          create_bus(event.fetch("payload"))
        else
          bus_id = event.dig("destination", "bus")
          raise("unknown event: #{event.inspect}") unless bus_id

          System.current_bus = bus_registry.fetch(bus_id)
          payload = System.current_bus.handle(event)

          transmit.(
            {
              type: "interfacets:system:render",
              payload:,
            },
          )
        end
      ensure
        GC.start
      end

      # private

      def config
        @config ||= Config.new
      end

      def create_bus(payload)
        id = payload.fetch("id")
        hydration_event = payload.fetch("hydration")

        channel_ids = payload.fetch("channel_ids")

        Bus.new(
          id:,
          channels: [
            Channels::Api.new(id: "interfacets:api"),
            Channels::React::Channel.new(id: "dom"),
            Channels::Url.new(id: "url"),
            (Channels::SpeechToText.new(id: "speechToText") if channel_ids.include?("speechToText")),
            (Channels::Timer.new(id: "timer") if channel_ids.include?("timer")),
            (Channels::Audio.new(id: "audio") if channel_ids.include?("audio")),
          ].compact,
          root_url: payload.fetch("config").fetch("root_url"),
        ).tap do
          bus_registry[id] = _1
        end

        handle(hydration_event)
      end

      def bus_registry
        @bus_registry ||= {}
      end
    end
  end
end
