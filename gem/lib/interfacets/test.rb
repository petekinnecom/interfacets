# frozen_string_literal: true

module Interfacets
  module Test
    module H
      module_function

      def j(hash)
        JSON.parse(hash.to_json)
      end
    end
  end
end
