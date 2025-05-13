# frozen_string_literal: true

module Interfacets
  module Client
    # alias: CrappyDelegator
    class Delegator
      def initialize(obj)
        @__obj__ = obj
      end

      def __getobj__
        @__obj__
      end

      def respond_to_missing?(...)
        @__obj__.send(:respond_to_missing?, ...)
      end

      def method_missing(method, *a, **p, &)
        @__obj__.send(method, *a, **p, &)
      end

      # delegation helpers
      def inspect
        [self.class.name, __getobj__.inspect].join(" -> ")
      end

      def to_s
        inspect
      end

      def presence
        self
      end
    end
  end
end
