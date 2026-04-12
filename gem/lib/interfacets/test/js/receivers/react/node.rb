# frozen_string_literal: true

require "nokogiri"

module Interfacets
  module Test
    module Js
      module Receivers
        class React
          class Node
            def self.parse(json:, dispatch:)
              new(
                xml: XmlParser.new(json).call,
                dispatch:,
                parent: nil,
              )
            end

            Error = Class.new(StandardError)
            NoMatchesError = Class.new(Error)
            MultipleMatchesError = Class.new(Error)
            StaleNodeError = Class.new(Error) do
              def initialize
                super(
                  <<~TXT
                    This node is stale and cannot be used. This occurs when the facet \
                    has been updated and you are using a reference to an out-of-date \
                    node. Re-fetch the node using `page.dom` rather than storing a \
                    reference to the node.
                  TXT
                )
              end
            end

            attr_reader :xml, :dispatch, :parent
            def initialize(xml:, dispatch:, parent:)
              @xml = xml
              @dispatch = dispatch
              @parent = parent
            end

            def stale!
              @stale = true
            end

            def stale?
              @stale || parent&.stale?
            end

            def component_name
              raise StaleNodeError if stale?

              xml.name
            end

            def props
              raise StaleNodeError if stale?

              xml.attributes.transform_values do |attr|
                attr.value.then { JSON.parse(_1) rescue _1 }
              end
            end

            def content
              raise StaleNodeError if stale?

              xml.content
            end

            def one(...)
              raise StaleNodeError if stale?

              all(...)
                .tap {
                  if _1.count == 0
                    raise NoMatchesError
                  elsif _1.count > 1
                    raise MultipleMatchesError.new(_1.map(&:content).join(", "))
                  end
                }
                .first
            end

            EMPTY_ARG = Object.new

            def all(*a, content: EMPTY_ARG, **p)
              raise StaleNodeError if stale?

              xml
                .css(*a, **p)
                .map { Node.new(xml: _1, dispatch:, parent: self) }
                .select {
                  (
                    content == EMPTY_ARG || (
                      if content.is_a?(Regexp)
                        _1.content.match?(content)
                      else
                        _1.content == content
                      end
                    )
                  )
                }

            end

            def attribute(name)
              raise StaleNodeError if stale?

              xml
                .attribute(name)
                &.value
                &.then { JSON.parse(_1) rescue _1 }
            end

            def trigger(name, data = {})
              raise StaleNodeError if stale?

              value = attribute(name.to_s)
              value["payload"]["event"] = data
              dispatch.(value)
            end
          end
        end
      end
    end
  end
end
