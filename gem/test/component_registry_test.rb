# frozen_string_literal: true

require "test_helper"

class Interfacets::ComponentRegistryTest < Minitest::Test
  def setup
    @fixtures_path = File.expand_path("fixtures/registry_test.yml", __dir__)
    @output_path = "test_registry.js"
    @registry = Interfacets::ComponentRegistry.new(config_path: @fixtures_path)
  end

  def teardown
    FileUtils.rm_f(@output_path)
  end

  def test_identifies_js_components
    components = @registry.send(:load_components)
    js_components = components.select { |_, config| config.key?("js") }
    assert_includes js_components.keys, "Button"
    assert_includes js_components.keys, "Header"
    assert_includes js_components.keys, "Badge"
    refute_includes js_components.keys, "ServerOnly"
  end

  def test_generates_full_registry_correctly
    @registry.write_client_registry(path: @output_path)
    assert File.exist?(@output_path)
    content = File.read(@output_path)

    expected_content = <<~JS
      import Button from "./components/Button";
      import { HeaderComponent as Header } from "./components/Header";
      import { Badge } from "./components/Badge";
      import { JSComponentName as RubySideName } from "./components/JSImplementation";

      export const registry = {
        Button,
        Header,
        Badge,
        RubySideName,
      };
    JS

    assert_equal expected_content, content
  end

  def test_handles_missing_config_file
    registry = Interfacets::ComponentRegistry.new(config_path: "non_existent.yml")
    assert_raises(Errno::ENOENT) do
      registry.write_client_registry(path: @output_path)
    end
  end

  def test_initialization_with_different_paths
    # This just ensures it doesn't crash during init/load if the file exists
    temp_config = "temp_config.yml"
    File.write(temp_config, { "Test" => { "js" => { "path" => "test" } } }.to_yaml)
    begin
      registry = Interfacets::ComponentRegistry.new(config_path: temp_config)
      registry.write_client_registry(path: @output_path)
      assert File.exist?(@output_path)
    ensure
      File.delete(temp_config) if File.exist?(temp_config)
    end
  end

  def test_generates_empty_registry_for_no_js_components
    temp_config = "empty_config.yml"
    File.write(temp_config, { "ServerOnly" => { "props" => {} } }.to_yaml)
    begin
      registry = Interfacets::ComponentRegistry.new(config_path: temp_config)
      registry.write_client_registry(path: @output_path)
      content = File.read(@output_path)
      expected_content = <<~JS
        export const registry = {

        };
      JS
      assert_equal expected_content, content
    ensure
      File.delete(temp_config) if File.exist?(temp_config)
    end
  end

  def test_handles_duplicate_paths
    temp_config = "dup_config.yml"
    config = {
      "Comp1" => { "js" => { "path" => "./shared" } },
      "Comp2" => { "js" => { "path" => "./shared" } }
    }
    File.write(temp_config, config.to_yaml)
    begin
      registry = Interfacets::ComponentRegistry.new(config_path: temp_config)
      registry.write_client_registry(path: @output_path)
      content = File.read(@output_path)
      expected_content = <<~JS
        import { Comp1 } from "./shared";
        import { Comp2 } from "./shared";

        export const registry = {
          Comp1,
          Comp2,
        };
      JS
      assert_equal expected_content, content
    ensure
      File.delete(temp_config) if File.exist?(temp_config)
    end
  end



  def test_generates_registry_with_transforms
    temp_config = "transform_config.yml"
    config = {
      "MyInput" => {
        "js" => { "path" => "./MyInput", "default" => true },
        "props" => {
          "onChange" => {
            "type" => "event",
            "is_event" => true,
            "transform" => { "value" => [0, "target", "value"] }
          }
        }
      }
    }
    File.write(temp_config, config.to_yaml)
    begin
      registry = Interfacets::ComponentRegistry.new(config_path: temp_config)
      registry.write_client_registry(path: @output_path)
      content = File.read(@output_path)

      expected_content = <<~JS
        import { withTransform } from "interfacets/withTransform";
        import MyInput from "./MyInput";

        export const registry = {
          MyInput: withTransform(MyInput, {"onChange":{"value":[0,"target","value"]}}),
        };
      JS
      assert_equal expected_content, content
    ensure
      File.delete(temp_config) if File.exist?(temp_config)
    end
  end
end
