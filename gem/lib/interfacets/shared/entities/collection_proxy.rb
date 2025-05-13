# frozen_string_literal: true

module Interfacets
  module Shared
    module Entities
      class CollectionProxy
        include Enumerable

        attr_reader :wrap, :unwrap
        def initialize(collection, wrap:, unwrap:)
          @collection = collection
          @wrap = wrap
          @unwrap = unwrap
        end

        # Read operations - wrap items when accessing
        def first
          val = @collection.first
          val.nil? ? nil : @wrap.call(val)
        end

        def last
          val = @collection.last
          val.nil? ? nil : @wrap.call(val)
        end

        def [](index)
          val = @collection[index]
          val.nil? ? nil : @wrap.call(val)
        end

        def at(index)
          val = @collection.at(index)
          val.nil? ? nil : @wrap.call(val)
        end

        def each(&block)
          @collection.each { |item| block.call(@wrap.call(item)) }
        end

        def size
          @collection.size
        end
        alias_method :length, :size
        alias_method :count, :size

        def empty?
          @collection.empty?
        end

        # Mutation operations - unwrap items and delegate to underlying collection
        def <<(item)
          @collection << @unwrap.call(item)
          self
        end

        def push(*items)
          @collection.push(*items.map { |item| @unwrap.call(item) })
          self
        end

        def pop
          val = @collection.pop
          val.nil? ? nil : @wrap.call(val)
        end

        def shift
          val = @collection.shift
          val.nil? ? nil : @wrap.call(val)
        end

        def unshift(*items)
          @collection.unshift(*items.map { |item| @unwrap.call(item) })
          self
        end

        def []=(index, item)
          @collection[index] = @unwrap.call(item)
        end

        def delete(item)
          unwrapped = @unwrap.call(item)
          val = @collection.delete(unwrapped)
          val.nil? ? nil : @wrap.call(val)
        end

        def delete_at(index)
          val = @collection.delete_at(index)
          val.nil? ? nil : @wrap.call(val)
        end

        def clear
          @collection.clear
          self
        end

        def insert(index, *items)
          @collection.insert(index, *items.map { |item| @unwrap.call(item) })
          self
        end

        def concat(other_array)
          @collection.concat(other_array.map { |item| @unwrap.call(item) })
          self
        end

        def replace(other_array)
          @collection.replace(other_array.map { |item| @unwrap.call(item) })
          self
        end

        # Enumerable methods that return arrays should return CollectionProxy
        def select(&block)
          selected = @collection.select { |item| block.call(@wrap.call(item)) }
          CollectionProxy.new(selected, wrap: @wrap, unwrap: @unwrap)
        end
        alias_method :filter, :select

        def reject(&block)
          rejected = @collection.reject { |item| block.call(@wrap.call(item)) }
          CollectionProxy.new(rejected, wrap: @wrap, unwrap: @unwrap)
        end

        def take(n)
          taken = @collection.take(n)
          CollectionProxy.new(taken, wrap: @wrap, unwrap: @unwrap)
        end

        def take_while(&block)
          taken = @collection.take_while { |item| block.call(@wrap.call(item)) }
          CollectionProxy.new(taken, wrap: @wrap, unwrap: @unwrap)
        end

        def drop(n)
          dropped = @collection.drop(n)
          CollectionProxy.new(dropped, wrap: @wrap, unwrap: @unwrap)
        end

        def drop_while(&block)
          dropped = @collection.drop_while { |item| block.call(@wrap.call(item)) }
          CollectionProxy.new(dropped, wrap: @wrap, unwrap: @unwrap)
        end

        def reverse
          reversed = @collection.reverse
          CollectionProxy.new(reversed, wrap: @wrap, unwrap: @unwrap)
        end

        def sort(&block)
          if block
            sorted = @collection.sort { |a, b| block.call(@wrap.call(a), @wrap.call(b)) }
          else
            sorted = @collection.sort
          end
          CollectionProxy.new(sorted, wrap: @wrap, unwrap: @unwrap)
        end

        def sort_by(&block)
          sorted = @collection.sort_by { |item| block.call(@wrap.call(item)) }
          CollectionProxy.new(sorted, wrap: @wrap, unwrap: @unwrap)
        end

        def uniq(&block)
          if block
            uniqued = @collection.uniq { |item| block.call(@wrap.call(item)) }
          else
            uniqued = @collection.uniq
          end
          CollectionProxy.new(uniqued, wrap: @wrap, unwrap: @unwrap)
        end

        def compact
          compacted = @collection.compact
          CollectionProxy.new(compacted, wrap: @wrap, unwrap: @unwrap)
        end

        def slice(*args)
          sliced = @collection.slice(*args)
          if sliced.is_a?(Array)
            CollectionProxy.new(sliced, wrap: @wrap, unwrap: @unwrap)
          else
            # Single element access returns wrapped item
            sliced.nil? ? nil : @wrap.call(sliced)
          end
        end

      end
    end
  end
end
