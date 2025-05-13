# frozen_string_literal: true

require_relative "../../test_helper"

module Interfacets
  module Shared
    module Entities
      class CollectionProxyTest < InterfacetsTest
        class Thing
          attr_reader :value
          def initialize(value)
            @value = value
          end
        end

        def proxy(array)
          CollectionProxy.new(
            array,
            wrap: ->(value) { Thing.new(value) },
            unwrap: ->(thing) { thing.value }
          )
        end

        def test_items_are_wrapped
          proxy = proxy(["hello"])

          assert proxy.first.is_a?(Thing)
          assert_equal "hello", proxy.first.value
        end

        def test_last_wraps_item
          proxy = proxy(["first", "last"])

          assert proxy.last.is_a?(Thing)
          assert_equal "last", proxy.last.value
        end

        def test_array_access_wraps_item
          proxy = proxy(["zero", "one", "two"])

          assert proxy[0].is_a?(Thing)
          assert_equal "zero", proxy[0].value
          assert_equal "one", proxy[1].value
          assert_equal "two", proxy[2].value
        end

        def test_at_wraps_item
          proxy = proxy(["zero", "one", "two"])

          assert proxy.at(1).is_a?(Thing)
          assert_equal "one", proxy.at(1).value
        end

        def test_each_wraps_items
          proxy = proxy(["a", "b", "c"])
          results = []

          proxy.each do |item|
            assert item.is_a?(Thing)
            results << item.value
          end

          assert_equal ["a", "b", "c"], results
        end

        def test_map_wraps_items
          proxy = proxy(["a", "b", "c"])

          result = proxy.map { |item| item.value.upcase }
          assert_equal ["A", "B", "C"], result
        end

        def test_map_returns_plain_array_not_proxy
          proxy = proxy(["a", "b", "c"])

          result = proxy.map { |item| item.value.upcase }
          # map should return a plain array, not a CollectionProxy
          refute result.is_a?(CollectionProxy)
          assert result.is_a?(Array)
          assert_equal ["A", "B", "C"], result
        end

        def test_map_receives_wrapped_items
          proxy = proxy(["a", "b", "c"])

          result = proxy.map do |item|
            # Items passed to the block should be wrapped (Thing instances)
            assert item.is_a?(Thing)
            item.value.upcase
          end
          assert_equal ["A", "B", "C"], result
        end

        def test_select_returns_proxy_with_wrapped_items
          proxy = proxy(["apple", "banana", "apricot"])

          result = proxy.select { |item| item.value.start_with?("a") }
          assert result.is_a?(CollectionProxy)
          assert_equal 2, result.size
          assert_equal "apple", result.first.value
        end

        def test_reject_returns_proxy_with_wrapped_items
          proxy = proxy(["apple", "banana", "apricot"])

          result = proxy.reject { |item| item.value.start_with?("a") }
          assert result.is_a?(CollectionProxy)
          assert_equal 1, result.size
          assert_equal "banana", result.first.value
        end

        def test_find_wraps_item
          proxy = proxy(["apple", "banana", "apricot"])

          result = proxy.find { |item| item.value.start_with?("b") }
          assert result.is_a?(Thing)
          assert_equal "banana", result.value
        end

        def test_all_predicate
          proxy = proxy(["apple", "apricot"])

          assert proxy.all? { |item| item.value.start_with?("a") }
          refute proxy.all? { |item| item.value.start_with?("b") }
        end

        def test_any_predicate
          proxy = proxy(["apple", "banana"])

          assert proxy.any? { |item| item.value.start_with?("b") }
          refute proxy.any? { |item| item.value.start_with?("c") }
        end

        def test_size_length_count
          proxy = proxy(["a", "b", "c"])

          assert_equal 3, proxy.size
          assert_equal 3, proxy.length
          assert_equal 3, proxy.count
        end

        def test_empty_predicate
          proxy = proxy([])
          assert proxy.empty?

          proxy = proxy(["a"])
          refute proxy.empty?
        end

        def test_push_mutates_underlying_collection
          collection = ["a"]
          proxy = proxy(collection)

          proxy.push(Thing.new("b"))
          assert_equal ["a", "b"], collection
        end

        def test_shovel_operator_mutates_underlying_collection
          collection = ["a"]
          proxy = proxy(collection)

          proxy << Thing.new("b")
          assert_equal ["a", "b"], collection
        end

        def test_pop_removes_and_wraps_item
          collection = ["a", "b", "c"]
          proxy = proxy(collection)

          result = proxy.pop
          assert result.is_a?(Thing)
          assert_equal "c", result.value
          assert_equal ["a", "b"], collection
        end

        def test_shift_removes_and_wraps_item
          collection = ["a", "b", "c"]
          proxy = proxy(collection)

          result = proxy.shift
          assert result.is_a?(Thing)
          assert_equal "a", result.value
          assert_equal ["b", "c"], collection
        end

        def test_unshift_mutates_underlying_collection
          collection = ["b", "c"]
          proxy = proxy(collection)

          proxy.unshift(Thing.new("a"))
          assert_equal ["a", "b", "c"], collection
        end

        def test_array_assignment_mutates_underlying_collection
          collection = ["a", "b", "c"]
          proxy = proxy(collection)

          proxy[1] = Thing.new("x")
          assert_equal ["a", "x", "c"], collection
        end

        def test_delete_removes_from_underlying_collection
          collection = ["a", "b", "c"]
          proxy = proxy(collection)

          result = proxy.delete(Thing.new("b"))
          assert result.is_a?(Thing)
          assert_equal "b", result.value
          assert_equal ["a", "c"], collection
        end

        def test_delete_at_removes_from_underlying_collection
          collection = ["a", "b", "c"]
          proxy = proxy(collection)

          result = proxy.delete_at(1)
          assert result.is_a?(Thing)
          assert_equal "b", result.value
          assert_equal ["a", "c"], collection
        end

        def test_clear_empties_underlying_collection
          collection = ["a", "b", "c"]
          proxy = proxy(collection)

          proxy.clear
          assert_equal [], collection
          assert proxy.empty?
        end

        def test_insert_mutates_underlying_collection
          collection = ["a", "c"]
          proxy = proxy(collection)

          proxy.insert(1, Thing.new("b"))
          assert_equal ["a", "b", "c"], collection
        end

        def test_concat_mutates_underlying_collection
          collection = ["a"]
          proxy = proxy(collection)

          proxy.concat([Thing.new("b"), Thing.new("c")])
          assert_equal ["a", "b", "c"], collection
        end

        def test_replace_replaces_underlying_collection
          collection = ["a", "b"]
          proxy = proxy(collection)

          proxy.replace([Thing.new("x"), Thing.new("y")])
          assert_equal ["x", "y"], collection
        end

        def test_take_returns_proxy_with_wrapped_items
          proxy = proxy(["a", "b", "c", "d"])

          result = proxy.take(2)
          assert result.is_a?(CollectionProxy)
          assert_equal 2, result.size
          assert_equal "a", result.first.value
          assert_equal "b", result.last.value
        end

        def test_drop_returns_proxy_with_wrapped_items
          proxy = proxy(["a", "b", "c", "d"])

          result = proxy.drop(2)
          assert result.is_a?(CollectionProxy)
          assert_equal 2, result.size
          assert_equal "c", result.first.value
          assert_equal "d", result.last.value
        end

        def test_reverse_returns_proxy_with_wrapped_items
          proxy = proxy(["a", "b", "c"])

          result = proxy.reverse
          assert result.is_a?(CollectionProxy)
          assert_equal 3, result.size
          assert_equal "c", result.first.value
          assert_equal "a", result.last.value
        end

        def test_sort_returns_proxy_with_wrapped_items
          proxy = proxy(["c", "a", "b"])

          result = proxy.sort { |a, b| a.value <=> b.value }
          assert result.is_a?(CollectionProxy)
          assert_equal ["a", "b", "c"], result.map { |item| item.value }
        end

        def test_sort_by_returns_proxy_with_wrapped_items
          proxy = proxy(["banana", "a", "apple"])

          result = proxy.sort_by { |item| item.value.length }
          assert result.is_a?(CollectionProxy)
          assert_equal ["a", "apple", "banana"], result.map { |item| item.value }
        end

        def test_uniq_returns_proxy_with_wrapped_items
          proxy = proxy(["a", "b", "a", "c", "b"])

          result = proxy.uniq
          assert result.is_a?(CollectionProxy)
          assert_equal 3, result.size
          assert_equal ["a", "b", "c"], result.map { |item| item.value }
        end

        def test_compact_returns_proxy_without_nils
          collection = ["a", nil, "b", nil, "c"]
          proxy = proxy(collection)

          result = proxy.compact
          assert result.is_a?(CollectionProxy)
          assert_equal 3, result.size
          assert_equal ["a", "b", "c"], result.map { |item| item.value }
        end

        def test_slice_with_range_returns_proxy
          proxy = proxy(["a", "b", "c", "d"])

          result = proxy.slice(1..2)
          assert result.is_a?(CollectionProxy)
          assert_equal 2, result.size
          assert_equal "b", result.first.value
          assert_equal "c", result.last.value
        end

        def test_slice_with_index_returns_wrapped_item
          proxy = proxy(["a", "b", "c"])

          result = proxy.slice(1)
          assert result.is_a?(Thing)
          assert_equal "b", result.value
        end

        def test_take_while_returns_proxy
          proxy = proxy(["a", "aa", "aaa", "b", "bb"])

          result = proxy.take_while { |item| item.value.start_with?("a") }
          assert result.is_a?(CollectionProxy)
          assert_equal 3, result.size
          assert_equal ["a", "aa", "aaa"], result.map { |item| item.value }
        end

        def test_drop_while_returns_proxy
          proxy = proxy(["a", "aa", "aaa", "b", "bb"])

          result = proxy.drop_while { |item| item.value.start_with?("a") }
          assert result.is_a?(CollectionProxy)
          assert_equal 2, result.size
          assert_equal ["b", "bb"], result.map { |item| item.value }
        end
      end
    end
  end
end
