# frozen_string_literal: true

require "json_schemer"

module Interfacets
  class ComponentSchemaParser
    SCHEMA = {
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "patternProperties" => {
        "^.*$" => {
          "type" => "object",
          "properties" => {
            "schema" => {
              "if" => { "type" => "object" },
              "then" => {
                "not" => { "required" => ["props"] }
              }
            },
            "props" => {
              "type" => "object",
              "patternProperties" => {
                "^.*$" => {
                  "type" => "object",
                  "properties" => {
                    "is_event" => { "type" => "boolean" }
                  },
                  "if" => {
                    "required" => ["is_event"],
                    "properties" => { "is_event" => { "const" => true } }
                  },
                  "then" => {
                    "properties" => {
                      "transform" => { "$ref" => "#/definitions/Transform" },
                      "payload" => { "type" => "object" }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "definitions" => {
        "Transform" => {
          "oneOf" => [
            { "type" => "null" },
            { "type" => "string" },
            {
              "type" => "object",
              "additionalProperties" => {
                "type" => "array",
                "items" => [
                  { "type" => "integer" }
                ],
                "additionalItems" => { "type" => "string" },
                "minItems" => 1
              }
            }
          ]
        }
      }
    }.freeze

    SCHEMER = JSONSchemer.schema(SCHEMA)

    def parse(component_config)
      errors = SCHEMER.validate(component_config).to_a
      if errors.any?
        if errors.any? { |e| e["data_pointer"].include?("/schema") && e["type"] == "not" }
          raise StandardError, "Old schema format is not supported."
        end

        message = "Validation failed:\n"
        errors.each do |error|
          message += "  - #{error["data_pointer"]}: #{error["type"]} #{error["details"]}\n"
        end
        raise StandardError, message
      end

      component_config
    end
  end
end
