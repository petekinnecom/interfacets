# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Schema
        class Deserializer
          def self.call(...)
            new(...).call
          end

          attr_reader :schema, :results
          def initialize(schema:)
            @schema = schema
            @results = { views: {}, entities: {}, apis: {} }
          end

          def call
            schema.fetch("views").each do |view_type, view_json|
              block = view_json.fetch("body")

              results[:views][view_type] = View.new(
                block: eval(block),
                name: view_type,
              )
            end

            schema.fetch("apis").each do |api_type, entity_json|
              block = entity_json.fetch("body")

              results[:apis][api_type] =
                Module.new do
                  extend ActiveSupport::Concern
                  define_singleton_method(:name) { api_type }

                  included do
                    class_exec(&eval(block))
                  end
                end
            end

            schema.fetch("entities").each do |entity_type, client_json|
              block = client_json.fetch("body")
              api_type = client_json.fetch("api_type")

              api_mod = results[:apis].fetch(api_type)

              results[:entities][entity_type] =
                Class.new(Entity) do
                  define_singleton_method(:name) { entity_type }
                  include api_mod

                  class_exec(&eval(block))
                end
            end

            results
          end
        end
      end
    end
  end
end
