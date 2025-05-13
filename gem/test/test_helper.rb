# frozen_string_literal: true

$interfacets_dev_mode = true
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "interfacets"
require "minitest/autorun"
require "json"

Interfacets.reload

class InterfacetsTest < Minitest::Test
  module H
    module_function

    def j(hash)
      JSON.parse(hash.to_json)
    end
  end

end
