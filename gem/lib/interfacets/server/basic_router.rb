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
          klass.server_entity_class
            .find_for_basic_routing(id, query:, bus: bus)
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
        path = normalize(url)

        if path.nil? && default
          klass = klass_for(default)
          return evaluator.call(klass:, id: nil, query:, resolved_path: default)
        end

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
        val = normalized_paths.fetch(normalize(path))

        (val.is_a?(String) ? Object.const_get(val) : val)
      end

      def normalized_paths
        @normalized_paths ||= (
          paths
            .transform_keys { normalize(_1) }
        )
      end

      def normalize(path)
        path
          &.sub(/^#{bus.root_url}/, "/")
          &.sub(/^/, "/")
          &.sub(%r{^/*}, "/")
        end
    end
  end
end
