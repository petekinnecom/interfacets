# frozen_string_literal: true

require "test_helper"

require "yaml"
require "interfacets/component_schema_parser"

class Interfacets::ComponentSchemaTest < Minitest::Test
  def setup
    @parser = Interfacets::ComponentSchemaParser.new
  end

  def teardown
    # Teardown for V2 schema tests
  end

  def test_parses_valid_component_definition
    yaml_data = <<~YAML
      MyComponent:
        props:
          onClick:
            type: event
            is_event: true
            transform: "debounce"
            payload:
              type: "object"
              properties:
                id:
                  type: "integer"
          title:
            type: "string"
    YAML

    component_config = YAML.safe_load(yaml_data)
    result = @parser.parse(component_config)

    expected = {
      "MyComponent" => {
        "props" => {
          "onClick" => {
            "type" => "event",
            "is_event" => true,
            "transform" => "debounce",
            "payload" => {
              "type" => "object",
              "properties" => {
                "id" => {
                  "type" => "integer"
                }
              }
            }
          },
          "title" => {
            "type" => "string"
          }
        }
      }
    }

    assert_equal expected, result
  end

  def test_rejects_invalid_component_definition
    yaml_data = <<~YAML
      MyComponent:
        schema:
          props:
            title:
              type: "string"
    YAML

    component_config = YAML.safe_load(yaml_data)
    
    assert_raises(StandardError) do
      @parser.parse(component_config)
    end
  end

  def test_allows_transform_on_non_event_prop
    yaml_data = <<~YAML
      MyComponent:
        props:
          title:
            type: "string"
            transform: 123
    YAML

    component_config = YAML.safe_load(yaml_data)
    result = @parser.parse(component_config)
    assert_equal component_config, result
  end

  def test_validates_transform_structure
    # Invalid: transform as object with non-array value
    yaml_data1 = <<~YAML
      MyComponent:
        props:
          onClick:
            is_event: true
            transform:
              value: "not an array"
    YAML

    assert_raises(StandardError) { @parser.parse(YAML.safe_load(yaml_data1)) }

    # Invalid: first item in array is not an integer
    yaml_data2 = <<~YAML
      MyComponent:
        props:
          onClick:
            is_event: true
            transform:
              value: ["not an integer", "target"]
    YAML

    assert_raises(StandardError) { @parser.parse(YAML.safe_load(yaml_data2)) }

    # Invalid: subsequent item is not a string
    yaml_data3 = <<~YAML
      MyComponent:
        props:
          onClick:
            is_event: true
            transform:
              value: [0, 123]
    YAML

    assert_raises(StandardError) { @parser.parse(YAML.safe_load(yaml_data3)) }
  end

  def test_allows_empty_transform
    # Empty string
    yaml_data1 = <<~YAML
      MyComponent:
        props:
          onClick:
            is_event: true
            transform: ""
    YAML
    assert_equal YAML.safe_load(yaml_data1), @parser.parse(YAML.safe_load(yaml_data1))

    # Nil value (empty in YAML)
    yaml_data2 = <<~YAML
      MyComponent:
        props:
          onClick:
            is_event: true
            transform:
    YAML
    assert_equal YAML.safe_load(yaml_data2), @parser.parse(YAML.safe_load(yaml_data2))
  end
end
