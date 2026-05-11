
module Interfacets
  module Test
    class UiSimulator
      TYPES = {
        inline: Js::InlineBus,
        nodo: Js::NodoBus,
        mruby_wasm: Js::NodoBus,
      }

      attr_reader :system_json, :router, :type, :contract_path, :validation
      def initialize(type:, bus:, router:, contract_path: nil, validation: :strict)
        unless TYPES.keys.include?(type)
          raise ArgumentError.new(
            "type: #{type.inspect} not allowed. Must be one of #{TYPES.keys}"
          )
        end

        @type = type
        # Serialize and deserialize to ensure proper data structure for JS
        @system_json = JSON.parse(bus.client_system_json(only_facets: type == :inline).to_json)
        @router = router
        @contract_path = contract_path
        @validation = validation
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

      def timers
        c("timer")
      end

      private

      def js
        @js ||= (
          validation_engine = if contract_path
            ValidationEngine.new(ComponentRegistry.load(contract_path), validation_mode: validation)
          end

          js_api = Test::Js::Receivers::Api.new(name: "interfacets:api", router:)
          js_react = Test::Js::Receivers::React.new(name: "dom", validation_engine:)
          js_url = Test::Js::Receivers::Url.new(name: "url")
          js_timer = Test::Js::Receivers::Timer.new(name: "timer")
          receivers = [js_api, js_react, js_url, js_timer]

          TYPES.fetch(type).new(
            receiver_index: receivers.map { [_1.name, _1] }.to_h,
            client_system_json: system_json,
          )
        )
      end
    end
  end
end
