# frozen_string_literal: true

require "test_helper"
require "yaml"

class Interfacets::Test::ComponentRegistryTest < Minitest::Test
  def setup
    @fixtures_path = File.expand_path("fixtures", __dir__)
  end

  def test_loads_external_schema_successfully
    config_path = File.join(@fixtures_path, "test_external_config.yml")
    config = {
      "TextField" => {
        "schema" => "TextField.yml",
        "js" => { "path" => "./components/TextField" }
      }
    }
    File.write(config_path, config.to_yaml)
    
    begin
      registry = Interfacets::Test::ComponentRegistry.new(config_path)
      # After US1 implementation, registry.contracts['TextField']['schema'] 
      # should be the content of TextField.yml
      schema = registry.contracts["TextField"]["schema"]
      
      assert_kind_of Hash, schema
      assert_equal "object", schema.dig("props", "type")
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  def test_loads_relative_schema_from_subdirectory
    config_path = File.join(@fixtures_path, "test_sub_config.yml")
    config = {
      "Button" => {
        "schema" => "contracts/Button.yml"
      }
    }
    File.write(config_path, config.to_yaml)
    
    begin
      registry = Interfacets::Test::ComponentRegistry.new(config_path)
      schema = registry.contracts["Button"]["schema"]
      
      assert_kind_of Hash, schema
      assert_equal "object", schema.dig("props", "type")
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  def test_raises_error_for_missing_schema_file
    config_path = File.join(@fixtures_path, "test_missing_config.yml")
    config = {
      "Missing" => {
        "schema" => "non_existent.yml"
      }
    }
    File.write(config_path, config.to_yaml)
    
    begin
      # After US2 implementation, this should raise Errno::ENOENT with descriptive message
      error = assert_raises(Errno::ENOENT) do
        Interfacets::Test::ComponentRegistry.new(config_path)
      end
      assert_match(/Schema file not found for component 'Missing'/, error.message)
      assert_match(/non_existent.yml/, error.message)
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  def test_raises_error_for_invalid_yaml_schema
    config_path = File.join(@fixtures_path, "test_invalid_config.yml")
    invalid_yaml_path = File.join(@fixtures_path, "invalid.yml")
    File.write(invalid_yaml_path, "props: [unclosed bracket")
    
    config = {
      "Invalid" => {
        "schema" => "invalid.yml"
      }
    }
    File.write(config_path, config.to_yaml)
    
    begin
      error = assert_raises(Interfacets::Error) do
        Interfacets::Test::ComponentRegistry.new(config_path)
      end
      assert_match(/Failed to parse schema file for component 'Invalid'/, error.message)
    ensure
      File.delete(config_path) if File.exist?(config_path)
      File.delete(invalid_yaml_path) if File.exist?(invalid_yaml_path)
    end
  end

  def test_schema_cache_ensures_shared_object_identity
    config_path = File.join(@fixtures_path, "test_cache_config.yml")
    config = {
      "Button1" => { "schema" => "contracts/Button.yml" },
      "Button2" => { "schema" => "contracts/Button.yml" }
    }
    File.write(config_path, config.to_yaml)
    
    begin
      registry = Interfacets::Test::ComponentRegistry.new(config_path)
      schema1 = registry.contracts["Button1"]["schema"]
      schema2 = registry.contracts["Button2"]["schema"]
      
      assert_same schema1, schema2
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end
end
