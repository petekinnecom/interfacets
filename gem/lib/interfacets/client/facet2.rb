# frozen_string_literal: true

module Interfacets
  module Client
    class Facet2
      class << self
        attr_accessor(
          :shared_entity,
          :entity,
          :view
        )
      end
    end
  end
end
