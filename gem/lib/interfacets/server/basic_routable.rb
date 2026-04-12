# frozen_string_literal: true

module Interfacets
  module Server
    module BasicRoutable
      extend ActiveSupport::Concern

      class RoutableChannel < Interfacets::Server::Registry::Channel
        def initialize(registry:)
          @router = router
        end

        def find(path, query: {})
          @router.call(path, query)
        end
      end

      included do
        attach(self)
      end

      class_methods do
        attr_accessor(:bus, :finder)

        def attach(mod)
          mod.entity_base do
            accessor(:api_path, accepted_by: :client)
          end
          facet_class = mod

          mod.server_entity(unshift: true) do
            attr_accessor :api_path

            define_singleton_method(:find) do |&block|
              facet_class.finder = block
            end
          end
        end

        def inherited(mod)
          attach(mod)
        end

        def find(id, query:)
          instance_exec(id, query:, &finder)
        end

        def build(klass, store)
          bus.registry.build(klass, store)
        end
      end
    end
  end
end
