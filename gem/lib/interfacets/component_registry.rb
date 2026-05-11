# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'json'
require "interfacets/component_schema_parser"

module Interfacets
  class ComponentRegistry
    def initialize(config_path:)
      @config_path = config_path
      @schema_cache = {}
    end

    def write_client_registry(path:)
      components = load_components
      content = generate_registry_content(components)
      write_atomic(path, content)
    end

    private

    def load_components
      raise Errno::ENOENT, "Configuration file not found at #{@config_path}" unless File.exist?(@config_path)
      
      # 1. Load the raw YAML
      components = YAML.load_file(@config_path, aliases: true) || {}
      
      # 2. Parse with the V2 parser
      parser = Interfacets::ComponentSchemaParser.new
      parsed_components = {}
      components.each do |name, config|
        next unless config.is_a?(Hash)
        component_data = { name => config }
        # The result of parse is the component data, which we merge.
        parsed_components.merge!(parser.parse(component_data))
      end
      
      parsed_components
    end

    def generate_registry_content(components)
      registry_components = components.select { |_, config| config.key?("js") || has_transforms?(config) }

      imports = []
      mappings = []
      any_transforms = false

      registry_components.each do |name, config|
        js_config = config["js"]
        path = js_config&.dig("path")

        transforms = extract_transforms(config)

        if path
          imports << if js_config["default"]
            "import #{name} from \"#{path}\";"
          elsif (export = js_config["export"])
            "import { #{export} as #{name} } from \"#{path}\";"
          else
            "import { #{name} } from \"#{path}\";"
          end
        else
          # Native element
          imports << "const #{name} = \"#{name}\";"
        end

        if transforms.any?
          any_transforms = true
          mappings << "  #{name}: withTransform(#{name}, #{transforms.to_json}),"
        else
          mappings << "  #{name},"
        end
      end

      if any_transforms
        imports.unshift('import { withTransform } from "interfacets/withTransform";')
      end

      template = []
      template << imports.join("\n") if imports.any?
      template << <<~JS.strip
        export const registry = {
        #{mappings.join("\n")}
        };
      JS

      "#{template.join("\n\n")}\n"
    end

    def has_transforms?(config)
      extract_transforms(config).any?
    end

    def extract_transforms(config)
      transforms = {}
      if props = config["props"]
        props.each do |prop_name, prop_config|
          if prop_config["is_event"] && prop_config.key?("transform")
            transforms[prop_name] = prop_config["transform"]
          end
        end
      end
      transforms
    end



    def write_atomic(path, content)
      temp_file = "#{path}.tmp"
      File.write(temp_file, content)
      FileUtils.mv(temp_file, path)
    end
  end
end
