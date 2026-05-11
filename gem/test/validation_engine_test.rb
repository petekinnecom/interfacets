# frozen_string_literal: true

require "test_helper"
require "interfacets/test/validation_engine"

class ValidationEngineTest < Minitest::Test
  class MockRegistry
    attr_reader :contracts, :definitions
    def initialize(contracts = {}, definitions = {})
      @contracts = contracts
      @definitions = definitions
    end
    def find_component(name)
      @contracts[name.to_s]
    end
  end

  def setup
    Interfacets::Test::ValidationEngine.reset_warnings!
    @contracts = {
      "CustomWidget" => {
        "props" => { "title" => { "type" => "string" } }
      }
    }
    @registry = MockRegistry.new(@contracts)
    @engine = Interfacets::Test::ValidationEngine.new(@registry)
  end

  def test_us1_standard_tag_without_contract_should_pass
    @engine.validate_props("div", { className: "foo" })
  end

  def test_us1_standard_tag_with_contract_but_missing_props_schema_should_pass
    @contracts["button"] = {} # in registry but no 'props' key
    @engine.validate_props("button", { any: "thing" })
  end

  def test_us1_standard_tag_without_contract_event_should_pass
    @engine.validate_event("button", "click", { x: 100 })
  end

  def test_us3_custom_tag_without_contract_should_raise_error
    assert_raises(Interfacets::MissingComponentContractError) do
      @engine.validate_props("MyCustomWidget", { foo: "bar" })
    end
  end

  def test_us3_custom_tag_with_contract_but_missing_props_schema_should_raise_error
    @contracts["MyCustomWidget"] = {} # in registry but no 'props' key
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_props("MyCustomWidget", { foo: "bar" })
    end
  end

  def test_us3_custom_tag_with_contract_but_missing_events_schema_should_raise_error
    @contracts["MyCustomWidget"] = { "props" => {} }
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_event("MyCustomWidget", "click", {})
    end
  end

  def test_us1_warn_mode_for_missing_custom_component
    engine = Interfacets::Test::ValidationEngine.new(@registry, validation_mode: :warn)
    _out, err = capture_io do
      engine.validate_props("MissingCustomWidget", { foo: "bar" })
    end
    assert_match(/Warning: Missing component contract for: MissingCustomWidget/, err)
  end

  def test_us1_permissive_mode_for_missing_custom_component
    engine = Interfacets::Test::ValidationEngine.new(@registry, validation_mode: :permissive)
    _out, err = capture_io do
      engine.validate_props("MissingCustomWidget", { foo: "bar" })
    end
    assert_empty(err)
  end

  def test_us1_strict_mode_for_missing_custom_component
    engine = Interfacets::Test::ValidationEngine.new(@registry, validation_mode: :strict)
    assert_raises(Interfacets::MissingComponentContractError) do
      engine.validate_props("MissingCustomWidget", { foo: "bar" })
    end
  end

  def test_us2_warn_mode_memoizes_warnings
    engine = Interfacets::Test::ValidationEngine.new(@registry, validation_mode: :warn)
    _out, err = capture_io do
      engine.validate_props("MissingCustomWidget", { foo: "bar" })
      engine.validate_props("MissingCustomWidget", { foo: "baz" })
    end
    warnings = err.scan(/Warning: Missing component contract for: MissingCustomWidget/)
    assert_equal(1, warnings.size, "Should only warn once per component")
  end

  def test_us3_permissive_mode_still_validates_registered_components
    engine = Interfacets::Test::ValidationEngine.new(@registry, validation_mode: :permissive)
    assert_raises(Interfacets::ValidationError) do
      # CustomWidget IS in @contracts, but we are passing invalid props
      engine.validate_props("CustomWidget", { title: 123 })
    end
  end

  def test_us2_standard_tag_with_schema_valid_payload_should_pass
    @contracts["button"] = {
      "props" => { "type" => { "enum" => ["submit", "button"] } }
    }
    @engine.validate_props("button", { "type" => "submit" })
  end

  def test_us2_standard_tag_with_schema_invalid_payload_should_raise_error
    @contracts["button"] = {
      "props" => { "type" => { "enum" => ["submit", "button"] } }
    }
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_props("button", { "type" => "invalid" })
    end
  end

  def test_is_event_validation_passes_for_valid_event
    @contracts["EventComp"] = {
      "props" => {
        "onAction" => { "is_event" => true, "payload" => { "type" => "object" } }
      }
    }
    @engine.validate_props("EventComp", { "onAction" => { "type" => "click", "payload" => {} } })
  end

  def test_is_event_without_payload_passes
    @contracts["EventCompNoPayload"] = {
      "props" => {
        "onAction" => { "is_event" => true }
      }
    }
    @engine.validate_props("EventCompNoPayload", { "onAction" => { "type" => "click", "payload" => { "anything" => "goes" } } })
    @engine.validate_event("EventCompNoPayload", "onAction", { "anything" => "goes" })
  end

  def test_is_event_validation_fails_for_invalid_structure
    @contracts["EventComp"] = {
      "props" => {
        "onAction" => { "is_event" => true, "payload" => { "type" => "object" } }
      }
    }
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_props("EventComp", { "onAction" => "not a hash" })
    end
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_props("EventComp", { "onAction" => { "type" => "click" } }) # missing payload
    end
  end

  def test_is_event_with_nested_schema_validation
    @contracts["ComplexComp"] = {
      "props" => {
        "onAction" => {
          "is_event" => true,
          "schema" => {
            "type" => "object",
            "required" => ["id"],
            "properties" => { "id" => { "type" => "integer" } }
          }
        }
      }
    }
    # Valid payload
    @engine.validate_props("ComplexComp", { "onAction" => { "type" => "click", "payload" => { "id" => 123 } } })

    # Invalid payload (wrong type)
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_props("ComplexComp", { "onAction" => { "type" => "click", "payload" => { "id" => "123" } } })
    end

    # Invalid payload (missing required field)
    assert_raises(Interfacets::ValidationError) do
      @engine.validate_props("ComplexComp", { "onAction" => { "type" => "click", "payload" => {} } })
    end
  end
end
