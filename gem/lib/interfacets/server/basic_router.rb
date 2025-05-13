# frozen_string_literal: true

module Interfacets
  module Server
    class BasicRouter
      class Evaluator
        attr_reader :bus
        def initialize(bus:)
          @bus = bus
        end

        def call(klass:, id:, query:, resolved_path:)
          klass.bus = bus
          klass
            .find
            .call(id, query:)
            .tap { _1.entity.api_path = resolved_path }
        end
      end

      attr_reader :paths, :bus, :default
      def initialize(bus:, paths:, default: nil)
        @bus = bus
        @paths = paths
        @default = default
      end

      def call(url, query: {})
        if url.nil? && default
          klass = klass_for(default)
          evaluator.call(klass:, id: nil, query:, resolved_path: default)
        end

        path = url.sub(/^#{bus.root_url}/, "/").sub(/^/, "/").sub(%r{^/*}, "/")

        if normalized_paths.key?(path)
          klass = klass_for(path)

          evaluator.call(klass:, id: nil, query:, resolved_path: path)
        else
          *parts, id = path.split("/")
          resolved_base_path = parts.join("/")

          if normalized_paths.key?(resolved_base_path)
            klass = klass_for(resolved_base_path)
            evaluator.call(klass:, id:, query:, resolved_path: path)
          elsif default
            klass = klass_for(default)
            evaluator.call(klass:, id: nil, query:, resolved_path: default)
          else
            raise "unhandled route: #{path}"
          end
        end
      end

      def evaluator
        @evaluator ||= Evaluator.new(bus:)
      end

      def klass_for(path)
        val = normalized_paths.fetch(path)

        (val.is_a?(String) ? Object.const_get(val) : val)
      end

      def normalized_paths
        @normalized_paths ||= (
          paths
            .transform_keys { _1.start_with?("/") ? _1 : "/#{_1}" }
        )
      end
    end
  end
end
