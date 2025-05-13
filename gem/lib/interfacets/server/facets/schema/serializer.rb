# frozen_string_literal: true

module Interfacets
  module Server
    module Facets
      module Schema
        class Serializer
          def self.call(...)
            new(...).call
          end

          private attr_reader(:facets, :schema)
          def initialize(facets:)
            @facets = facets
            @schema = { views: {}, entities: {}, apis: {} }
          end

          def call
            facets.each do |facet|
              config = facet.client_config

              schema[:views][config.view.name] = {
                body: write_source(config.view.block),
              }

              schema[:entities][config.entity.name] = {
                api_type: config.api.name,
                body: write_source(config.entity.block),
              }

              schema[:apis][config.api.name] = {
                body: write_source(config.api.block),
              }
            end

            schema
          end

          private

          def write_source(block)
            return unless block

            RubyVM::AbstractSyntaxTree
              .of(block, keep_script_lines: true)
              .source
              .then { block.is_a?(UnboundMethod) ? _1 : "lambda #{_1}" }
              .strip
          end
        end
      end
    end
  end
end
