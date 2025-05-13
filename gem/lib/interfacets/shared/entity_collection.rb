# frozen_string_literal: true

module Interfacets
  module Shared
    class EntityCollection
      include Enumerable

      attr_reader :items
      def initialize(items, &block)
        @items = items || []
        @wrap = block
      end

      def each(&)
        @items.each do |item|
          yield(@wrap.call(item))
        end
      end

      def to_a
        @items.map { @wrap.call(_1) }
      end

      def size
        @items.size
      end

      def length
        @items.length
      end

      def empty?
        @items.empty?
      end

      def include?(item)
        @items.include?(to_record(item))
      end

      def [](index)
        item = @items[index]
        item ? @wrap.call(item) : nil
      end

      def first
        item = @items.first
        item ? @wrap.call(item) : nil
      end

      def last
        item = @items.last
        item ? @wrap.call(item) : nil
      end

      def <<(item_to_add)
        @items << to_record(item_to_add)
        self
      end

      def push(*items_to_add)
        @items.push(*items_to_add.map { to_record(_1) })
        self
      end

      def delete(item)
        @items.delete(to_record(item))
      end

      def delete_at(index)
        @items.delete_at(index)
      end

      def original
        @items
      end

      def inspect
        "#<#{self.class.name} decorating=#{@items.inspect} with=#{@entity_class}>"
      end

      private

      def to_record(item)
        item.is_a?(Entity) ? item.record : item
      end
    end
  end
end
