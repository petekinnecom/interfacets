# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Attributes
        class Accessor
          attr_reader :send_if
          def initialize(send_if:)
            @send_if = send_if
          end

          def coerce(val, **)
            val
          end

          def serialize(val)
            val
          end

          def should_send?(facet)
            facet.instance_exec(&send_if)
          end
        end
      end
    end
  end
end
