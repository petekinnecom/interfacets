# frozen_string_literal: true

# require_relative "./test_helper"

class TestInterfacets < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil(::Interfacets::VERSION)
  end
end
