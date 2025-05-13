# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      module React
        class Dom
          attr_accessor :children, :handlers, :facet

          def initialize(facet:)
            @children = []
            @portals = []
            @handlers = {}
            @facet = facet
          end

          def reset
            @children = []
            @portals = []
            @handlers = {}
          end

          def handle(facet:, payload:)
            handler_id = payload.fetch("id")
            handler = handlers.fetch(handler_id)
            callback = handler.fetch(:callback)
            og_facet = handler.fetch(:facet)

            Evaluator.call(og_facet, callback, payload["event"])
          end

          def register_handler(id:, callback:, facet:)
            @handlers[id] = { facet:, callback: }

            {
              type: "interfacets:react-dom:memoized-action",
              payload: { id: },

            }
          end

          def string_node(str)
            @children << {
              type: "interfacets:string-node",
              attributes: { value: str },
            }
          end

          def call(type, str = nil, **attrs)
            raise("cannot pass both a block and a string") if str && block_given?
            raise if type == :facet

            new_element = {
              type:,
              children: [],
              attributes: (
                attrs.transform_values { |value|
                  if value.is_a?(Proc)
                    register_handler(
                      id: value.object_id.to_s,
                      callback: value,
                      facet:,
                    )

                    {
                      type: "interfacets:react-dom:action",
                      payload: { id: value.object_id.to_s },
                    }
                  else
                    value
                  end
                }
              ),
            }

            if block_given? || str
              # recurse
              original_children = @children
              @children = new_element[:children]
              yield if block_given?
              string_node(str) if str
              @children = original_children
            end

            @children << new_element
          end
        end
      end
    end
  end
end
