# frozen_string_literal: true

require "yaml"

module Interfacets
  module Test
    class ComponentRegistry
      DEFAULT_CONFIG_PATH = "config/interfacets/components.yml"

      def self.load(path = DEFAULT_CONFIG_PATH)
        new(path)
      end

      attr_reader :contracts

      def initialize(path)
        @path = path
        @schema_cache = {}
        @contracts = load_contracts
      end

      def find_component(name)
        @contracts[name.to_s]
      end

      def definitions
        @contracts["definitions"] || {}
      end

      private

      def load_contracts
        return {} unless File.exist?(@path)

        contracts = YAML.load_file(@path, aliases: true) || {}
        contracts.each do |name, config|
          next unless config.is_a?(Hash)

          schema = config["schema"]
          if schema.is_a?(String)
            config["schema"] = load_schema_file(name, schema)
          end
        end
        contracts
      rescue Psych::SyntaxError => e
        raise Error, "Failed to parse component registry at #{@path}: #{e.message}"
      end

      def load_schema_file(component_name, schema_path)
        full_path = File.expand_path(schema_path, File.dirname(@path))
        return @schema_cache[full_path] if @schema_cache.key?(full_path)

        raise Errno::ENOENT, "Schema file not found for component '#{component_name}' at #{full_path}" unless File.exist?(full_path)

        begin
          @schema_cache[full_path] = YAML.load_file(full_path, aliases: true) || {}
        rescue Psych::SyntaxError => e
          raise Error, "Failed to parse schema file for component '#{component_name}' at #{full_path}: #{e.message}"
        end
      end
    end
  end
end
