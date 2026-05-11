require "test_helper"
require "interfacets/component_registry"

class RegistrySyncTest < ActiveSupport::TestCase
  test "registry.js is synchronized with components.yml" do
    registry_path = Rails.root.join("app/javascript/interfacets/registry.js")
    config_path = Rails.root.join("config/components.yml")

    # Remove the file if it exists to ensure we're testing the generation
    File.delete(registry_path) if File.exist?(registry_path)

    registry = Interfacets::ComponentRegistry.new(config_path: config_path)
    registry.write_client_registry(path: registry_path)

    assert File.exist?(registry_path)
    content = File.read(registry_path)
    assert_includes content, "import Button from \"../components/Button\";"
    assert_includes content, "Button,"
  end
end
