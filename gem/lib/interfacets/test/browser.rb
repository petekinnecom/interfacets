
module Interfacets
  module Test
    class Browser
      TYPES = {
        inline: Js::InlineBus,
        nodo: Js::NodoBus,
        mruby_wasm: Js::NodoBus,
      }

      attr_reader :system_json, :router, :type
      def initialize(system_json:, router:, type:)
        unless TYPES.keys.include?(type)
          raise ArgumentError.new(
            "type: #{type.inspect} not allowed. Must be one of #{TYPES.keys}"
          )
        end

        @type = type
        # Serialize and deserialize to ensure proper data structure for JS
        @system_json = JSON.parse(system_json.to_json)
        @router = router
      end

      def visit(path)
        js.init(
          hydrated_facet: router.call(path).render
        )
      end

      def c(channel_id)
        js.handler(channel_id)
      end

      def dispatch(channel_id, event)
        js.dispatch(channel_id, event)
      end

      def url
        c("url")
      end

      def dom
        c("dom")
      end

      private

      def js
        @js ||= (
          js_api = Test::Js::Receivers::Api.new(name: "interfacets:api", router:)
          js_react = Test::Js::Receivers::React.new(name: "dom")
          js_url = Test::Js::Receivers::Url.new(name: "url")
          receivers = [js_api, js_react, js_url]

          TYPES.fetch(type).new(
            receiver_index: receivers.map { [_1.name, _1] }.to_h,
            client_system_json: system_json,
          )
        )
      end
    end
  end
end
