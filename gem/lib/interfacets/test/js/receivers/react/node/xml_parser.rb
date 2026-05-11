# frozen_string_literal: true

require "nokogiri"

module Interfacets
  module Test
    module Js
      module Receivers
        class React
          class Node
            class XmlParser
              attr_reader :json, :validation_engine
              def initialize(json, validation_engine:)
                @json = json
                @validation_engine = validation_engine
              end

              def call
                xml = Nokogiri::XML.fragment("<Facet/>")
                json
                  .dig("streams", "default", "dom")
                  .map { parse_element(_1) }
                  .each { xml.add_child(_1) }
                xml
              end

              private

              def parse_attribute(value, top: true)
                case value
                when Array
                when Hash
                  value
                    .transform_values { parse_attribute(_1, top: false) }
                    # we don't want to call to_json on nested hashes
                    .then { top ? _1.to_json : _1 }
                when Numeric, String, TrueClass, FalseClass, NilClass
                  value
                else
                  raise "unknown attribute type: #{value}"
                end
              end

              def parse_element(el)
                case el.fetch("type")
                when "interfacets:string-node"
                  el.dig("attributes", "value").to_s
                when "interfacets:react-dom:element"
                  xml = (
                    el
                      .fetch("element")
                      .tap { validation_engine&.validate_props(_1, el.fetch("attributes")) }
                      .then { Nokogiri::XML.fragment("<#{_1} />").children.first }
                  )

                  el.fetch("children").each do |child|
                    xml.add_child(parse_element(child)) if child
                  end

                  el.fetch("attributes").each do |name, value|
                    xml.set_attribute(name, parse_attribute(value))
                  end

                  xml
                else
                  raise "unknown type: #{el.fetch("type")}"
                end
              end
            end
          end
        end
      end
    end
  end
end
