# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Attributes
        class Readonly
          def coerce(val, **)
            val
          end

          def serialize(val)
            val
          end
        end
      end
    end
  end
end
