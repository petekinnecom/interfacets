# frozen_string_literal: true

# require_relative "./test/session"
# require_relative "./test/js"
# require_relative "./test/js/channels"

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
