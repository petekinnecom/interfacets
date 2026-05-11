# frozen_string_literal: true

module Interfacets
  module Shared
    module BasicRoutable
      extend ActiveSupport::Concern

      included do
        class << self
          attr_accessor :bus

          def build(klass, store)
            bus.registry.build(klass, store)
          end
        end

        # This is unfortunate, but in order to be able to do:

        # build(self, ...)
        # we need the self to be the facet.
        # We could also update the registry to handle being passed a server
        # entity, but I'm currently tweaking the registry. so this is a TODO.
        facet = self

        entity_base do
          accessor(:api_path, accepted_by: :client)
        end

        server_entity(unshift: true) do
          attr_accessor :api_path

          define_singleton_method(:find) do |&block|
            @find = block if block
            @find
          end

          define_singleton_method(:find_for_basic_routing) do |id, query:, bus:|
            facet.bus = bus
            facet.instance_exec(id, query:, &find)
          end
        end
      end
    end
  end
end
