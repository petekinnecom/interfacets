# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      module React
        class Evaluator
          def self.call(facet, handler, event)
            new(facet).call(handler, event)
          end

          # This just isolates the evaluation so that we don't
          # conflict with other methods
          #
          # for associations, this facet needs to be the relevant one...
          attr_reader :facet

          def initialize(facet)
            @facet = facet
          end

          def call(handler, event)
            Shared::Utils.permissive_exec(self, event, &handler)
          end

          def channel(name)
            System.current_bus.channel(name).builder
          end
        end
      end
    end
  end
end
