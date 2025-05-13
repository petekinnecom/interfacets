# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Attributes
        class Bind
          attr_reader :name, :facet
          def initialize(name:, facet:)
            @name = name
            @facet = facet
          end

          def get
            facet.public_send(name)
          end

          def set(v)
            facet.public_send("#{name}=", v)
          end
        end
      end
    end
  end
end
