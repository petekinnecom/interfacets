# frozen_string_literal: true

require "json_schemer"
require "set"
require "yaml"

module Interfacets
  module Test
    class ValidationEngine
      attr_reader :registry, :validation_mode

      @warned_components = Set.new

      def self.warned_components
        @warned_components
      end

      def self.reset_warnings!
        @warned_components.clear
      end

      def initialize(registry = ComponentRegistry.load, validation_mode: :strict)
        @registry = registry
        @validation_mode = validation_mode
      end

      def active?
        registry.contracts.any?
      end

      def validate_props(component_name, props)
        return unless active?

        contract = registry.find_component(component_name)
        is_standard = standard_element?(component_name)

        props_config = contract&.dig("props")

        if is_standard
          return unless props_config
        else
          return unless contract_exists?(component_name)

          raise ValidationError, "Missing props schema for custom component: #{component_name}" unless props_config
        end

        schema = { "type" => "object", "properties" => props_config }
        validate!(schema, props, "properties for #{component_name}")
      end

      def validate_event(component_name, event_name, payload)
        return unless active?

        contract = registry.find_component(component_name)
        is_standard = standard_element?(component_name)

        event_config = contract&.dig("props", event_name.to_s)

        if is_standard
          return unless event_config
        else
          return unless contract_exists?(component_name)

          raise ValidationError, "Missing events schema for custom component: #{component_name}" unless contract.key?("props")
          raise ValidationError, "Missing event schema for '#{event_name}' in custom component: #{component_name}" unless event_config
        end

        schema = event_config.is_a?(Hash) ? (event_config["payload"] || {}) : {}

        validate!(schema, payload, "event '#{event_name}' for #{component_name}")
      end

      private

      def standard_element?(component_name)
        @standard_elements ||= begin
          yaml_path = File.expand_path("standard_elements.yml", __dir__)
          Set.new(YAML.load_file(yaml_path).map(&:to_s))
        end
        @standard_elements.include?(component_name.to_s)
      end

      def contract_exists?(component_name)
        contract = registry.find_component(component_name)
        return true if contract

        case validation_mode
        when :strict
          raise MissingComponentContractError, "Missing component contract for: #{component_name}"
        when :warn
          unless self.class.warned_components.include?(component_name)
            warn "Warning: Missing component contract for: #{component_name}"
            self.class.warned_components << component_name
          end
          false
        when :permissive
          false
        else
          raise ArgumentError, "Unknown validation_mode: #{validation_mode}"
        end
      end

      def find_contract!(name)
        contract = registry.find_component(name)
        return contract if contract

        raise MissingComponentContractError, "Missing component contract for: #{name}"
      end

      def validate!(schema, data, context)
        full_schema = schema.dup
        if full_schema["type"] == "object" && !full_schema.key?("additionalProperties")
          full_schema["additionalProperties"] = false
        end
        full_schema["definitions"] = registry.definitions if registry.definitions.any?

        schemer = JSONSchemer.schema(full_schema, keywords: {
          "is_event" => lambda do |instance, keyword_value, pointer|
            return true unless keyword_value
            unless instance.is_a?(Hash) && instance.key?("type") && instance.key?("payload")
              return [false, "missing 'type' or 'payload'"]
            end

            prop_name = pointer.split("/").last
            prop_schema = full_schema.dig("properties", prop_name)
            if prop_schema && (nested_schema = prop_schema["schema"])
              nested_schemer = JSONSchemer.schema(nested_schema)
              nested_errors = nested_schemer.validate(instance["payload"]).to_a
              if nested_errors.any?
                return [false, "event payload validation failed: #{nested_errors.map { |e| "#{e['data_pointer']}: #{e['type']} #{e['details']}" }.join(', ')}"]
              end
            end

            true
          end
        })

        errors = schemer.validate(data).to_a

        return if errors.empty?

        message = "Validation failed for #{context}:\n"
        errors.each do |error|
          message += "  - #{error['data_pointer']}: #{error['type']} #{error['details']}\n"
        end

        raise ValidationError, message
      end
    end
  end
end
