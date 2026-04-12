# frozen_string_literal: true

module Interfacets
  module Shared
    module Utils
      extend self

      def permissive_exec(receiver, *, &lambda)
        if lambda.arity.zero?
          receiver.instance_exec(&lambda)
        else
          receiver.instance_exec(*, &lambda)
        end
      end

      def permissive_call(lambda, ...)
        if lambda.arity.zero?
          lambda.call
        else
          lambda.call(...)
        end
      end

      def facet_id_to_path(config:, facet:, id:)
        [config.mount_point, facet, id].join("/")
      end

      def path_to_facet_id(config:, path:)
        parts = path.sub(/.*#{config.mount_point}/, "").split("/")
        id = parts.pop
        facet = parts.join("/")

        [facet, id]
      end

      # ActiveSupport?
      def blank?(str)
        return true if str.nil?
        return str.empty? if str.is_a?(Array)
        return str.match(/\A\s*\z/) if str.is_a?(String)

        raise("unsupported blank check")
      end

      def present?(str)
        !blank?(str)
      end

      def presence(obj)
        present?(obj) ? obj : nil
      end
    end
  end
end
