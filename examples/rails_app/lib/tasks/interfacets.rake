namespace :interfacets do
  desc "Synchronize component registry"
  task :sync => :environment do
    require "interfacets/component_registry"
    registry = Interfacets::ComponentRegistry.new(
      config_path: Rails.root.join("config/components.yml")
    )
    registry.write_client_registry(
      path: Rails.root.join("app/javascript/interfacets/registry.js")
    )
    puts "Interfacets registry synchronized"
  end
end

# Ensure interfacets:sync runs before javascript:build
if Rake::Task.task_defined?("javascript:build")
  Rake::Task["javascript:build"].enhance(["interfacets:sync"])
end
