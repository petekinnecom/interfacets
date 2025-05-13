# frozen_string_literal: true

module Interfacets
  module Server
    module BasicRoutable
      extend ActiveSupport::Concern

      included do
        attach(self)
      end


      class_methods do
        def attach(mod)
          mod.shared do
            accessor(:api_path, accepted_by: :client)
          end

          mod.server do
            attr_accessor :api_path
          end
        end

        def inherited(mod)
          attach(mod)
        end

        attr_accessor :bus
        def find(&block)
          @find = block if block_given?
          @find
        end

        def build(klass, store)
          bus.registry.build(klass, store)
        end
      end
    end
  end
end
