require "nodo"

module Interfacets
  module Test
    module Js
      class NodoBus < Nodo::Core
        attr_reader :receiver_index, :client_system_json
        def initialize(receiver_index:, client_system_json:)
          super()
          @receiver_index = receiver_index
          @client_system_json = client_system_json
        end

        def dispatch(channel_id, event)
          js_dispatch(channel_id, event)
          render
        end

        def handler(channel_id)
          receiver_index.fetch(channel_id).handler
        end

        def init(hydrated_facet:)
          js_init(
            clientSystemJson: client_system_json,
            hydratedFacet: hydrated_facet
          )
          render
        end

        def render
          receiver_index.each do |id, ch|
            state = js_get_state(id)
            next if state.nil?

            ch.receive(
              payload: state.fetch("data"),
              dispatch: ->(e) { dispatch(id, e) }
            )

            receiver_index.each do |id, ch|
              if ch.respond_to?(:response_queue)
                ch.flush_responses.each do |response|
                  dispatch(id, response)
                end
              end
            end
          end

          if js_get_logs.any? { _1.fetch("type") == "error" }
            js_get_logs
            .map { _1.fetch("value") }
            .then { raise(_1.join("\n")) }
          end
        end

        import app: File.join(__dir__, "../../../../test/wasm/app.mjs")
        import :fs

        function :js_init, <<~JS
          async (config) => {
            global.logs = []
            global.console = {
              log: (...msgs) => {
                global.logs.push({
                  type: "log",
                  value: msgs.map(m => m.toString())
                })
              },
              error: (...msgs) => {
                global.logs.push({
                  type: "error",
                  value: msgs.map(m => m.toString())
                })
              },
            }

            await app.init(config)
          }
        JS

        function :js_dispatch, <<~JS
          (channelName, event) => {
            app.dispatch(channelName, event)
          }
        JS

        function :js_get_logs, <<~JS
          () => global.logs
        JS

        function :js_get_state, <<~JS
          (channelName) => app.getState(channelName)
        JS
      end
    end
  end
end
