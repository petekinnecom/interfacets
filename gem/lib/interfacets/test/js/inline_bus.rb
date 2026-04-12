require "nodo"

module Interfacets
  module Test
    module Js
      class InlineBus
        attr_reader :receiver_index, :client_system_json
        def initialize(receiver_index:, client_system_json:)
          @receiver_index = receiver_index
          @client_system_json = client_system_json
        end

        def handler(channel_id)
          receiver_index.fetch(channel_id).handler
        end

        def init(hydrated_facet:)
          client.handle(H.j({
            type: "interfacets:system:create_bus",
            payload: {
              id: "default",
              channel_ids: ["interfacets:api", "dom", "url", "timer"],
              hydration: {
                destination: { bus: "default", channel: "interfacets:api" },
                type: "interfacets:api:hydrate",
                payload: hydrated_facet
              },
              config: client_system_json,
            }
          }))
        end

        def dispatch(channel_id, event)
          dispatch_to_bus(bus_id: "default", channel_id: channel_id, event: event)
        end

        private

        def handle(event)
          case event.fetch("type")
          when "interfacets:system:render"
            bus_event = event.fetch("payload")
            bus_id = bus_event.fetch("id")

            bus_event.fetch("payload").each do |channel_event|
              channel_id = channel_event.fetch("id")
              receiver = receiver_index.fetch(channel_id)

              receiver
                .receive(
                  payload: channel_event.fetch("payload"),
                  dispatch: ->(ev) {
                    dispatch_to_bus(bus_id:, channel_id:, event: ev)
                  },
                )
            end
          else
            raise("unhandled event type: #{event}")
          end

          # Flush any responses that may have come from the server
          # should separate this out so that auto-flush or manual-flush
          # is possible to simulate ordering events as needed.
          receiver_index.each do |channel_id, receiver|
            if receiver.respond_to?(:response_queue)
              receiver.flush_responses.each do |response|
                dispatch_to_bus(bus_id:, channel_id:, event: response)
              end
            end
          end
        end

        def dispatch_to_bus(bus_id:, channel_id:, event:)
          client.handle(
            H.j(
              {
                destination: { bus: bus_id, channel: channel_id },
                type: "interfacets:channel:event",
                payload: event,
              },
            ),
          )
        end

        def client
          @client ||= (
            $asset_logger = Logger.new("/dev/null")
            original_verbose = $VERBOSE
            $VERBOSE = nil
            begin
              Client::Assets.bootstrap(client_system_json.fetch("assets"))
            ensure
              $VERBOSE = original_verbose
            end
            Client::System.logger = $asset_logger

            Client.start(
              transmit: ->(event) {
                handle(H.j(event))
              },
            )
          )
        end
      end
    end
  end
end
