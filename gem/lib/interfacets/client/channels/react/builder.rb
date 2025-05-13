# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      module React
        class Builder
          attr_reader :nodes, :callbacks, :entity
          def initialize(entity, cache)
            @entity = entity
            @nodes = []
            @callbacks = {}
            @stack = []
            @cache = cache
            @memos = (@cache["Interfacets.Memos"] ||= {})
          end

          def __reset__
            @nodes = []
            @stack = []
            @memos = (@cache["Interfacets.Memos"] ||= {})
          end

          def apply(nodes)
            nodes.each { @nodes << _1 }
          end

          def capture
            raise ArgumentError unless block_given?

            original_nodes = @nodes
            @nodes = []
            yield
            captured_nodes = @nodes
            @nodes = original_nodes
            captured_nodes
          end

          def string(val)
            string_node(val)
          end

          def str(...)
            string(...)
          end

          # Need to override ruby's "p" methods (ie, puts)
          def p(...)
            add_node("p", ...)
          end

          def memo(*keys, on:, &)
            System.logger.warn("Memo is disabled")
            return add_node(
              "React.Fragment",
              &
            )
            memo_key = (
              ([entity.internal_id] + keys)
                .map(&:to_json)
                .join(".")
            )
            memo_val = Array(on).map(&:to_json).join(".")

            if @memos.dig(memo_key, :memo_val) == memo_val
              @nodes << @memos.dig(memo_key, :component)
            else
              component = add_node(
                "Interfacets.Memo",
                memoKey: memo_key,
                memoVal: memo_val,
                &
              )

              @memos[memo_key] = { memo_val:, component: }
            end
          end

          def cache(*keys, &)
            cache_key = keys.map(&:to_json).join(".")
            if @cache.key?(cache_key)
              @nodes << @cache.fetch(cache_key)
            else
              @cache[cache_key] = (
                add_node(
                  "Interfacets.Cache",
                  cacheKey: cache_key,
                  &
                )
              )
            end
          end

          def safe_html(str)
            # add_node("React.Fragment", dangerouslySetInnerHTML: { __html: str })
          end

          def f(id, callback = nil, &block)
            register_handler(id: id.to_json, callback: callback || block)
          end

          def prop(path)
            paths = (
              if path.is_a?(String)
                path.split(".")
              elsif path.is_a?(Symbol)
                [path.to_s]
              else
                path
              end
            )

            {
              type: "interfacets:react-dom:prop",
              payload: { path: paths },
            }
          end

          def function(...)
            f(...)
          end

          def respond_to_missing?(...)
            true
          end

          def method_missing(meth, *, **, &)
            raise if meth.to_s == "name"
            add_node(meth, *, **, &)
          end

          private

          def string_node(str)
            @nodes << {
              type: "interfacets:string-node",
              attributes: { value: str },
            }
          end

          def register_handler(id:, callback:)
            callbacks[id] = callback

            {
              type: "interfacets:react-dom:memoized-action",
              payload: { id: },

            }
          end

          def add_node(element, str = nil, **attrs)
            raise("cannot pass both a block and a string") if str && block_given?
            raise if element == :entity

            new_element = {
              type: "interfacets:react-dom:element",
              element:,
              children: [],
              attributes: (
                attrs.transform_values { |value| transform_attr(value) }
              ),
            }

            if block_given? || str
              # recurse
              original_nodes = @nodes
              @nodes = new_element[:children]
              begin
                yield if block_given?
                string_node(str) if str
              ensure
                @nodes = original_nodes
              end
            end

            @nodes << new_element
            new_element
          end

          def transform_attr(value)
            if value.is_a?(Proc)
              register_handler(
                id: value.object_id.to_s,
                callback: value,
              )

              {
                type: "interfacets:react-dom:action",
                payload: { id: value.object_id.to_s },
              }
            elsif value.is_a?(Array)
              value.map { transform_attr(_1) }
            elsif value.is_a?(Hash)
              value.transform_values { |k| transform_attr(k) }
            else
              value
            end
          end
        end
      end
    end
  end
end
