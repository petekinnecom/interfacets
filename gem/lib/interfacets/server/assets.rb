# frozen_string_literal: true

require "prism"

module Interfacets
  module Server
    module Assets
      Const =
        Data.define(:nesting, :type, :name, :parent) do
          def full_name
            [nesting.last&.full_name, name].compact.join("::")
          end
        end

      class Classifier
        class Visitor < Prism::Visitor
          # This class just gathers up all modules and classes defined
          attr_reader :mods
          def initialize
            @stack = []
            @mods = []
            super
          end

          def visit_module_node(node)
            push_mod(node)
          end

          def visit_class_node(node)
            push_mod(node)
          end

          private

          def push_mod(node)
            type = node.type == :module_node ? :module : :class

            parent = (
              if type == :class && node.child_nodes[1]
                node.child_nodes[1].full_name
              end
            )

            const = Const.new(
              nesting: @stack.dup,
              name: node.constant_path.full_name,
              type:,
              parent:
            )
            @stack << const
            mods << @stack.dup
            visit_child_nodes(node)
            @stack.pop
          end
        end

        attr_reader :code
        def initialize(code)
          @code = code
        end

        def consts
          @consts ||= (
            Prism.parse(code).value.accept(visitor)
            visitor.mods.map(&:last)
          )
        end

        def visitor
          @visitor ||= Visitor.new
        end
      end

      class Serializer
        attr_reader :paths, :file
        def initialize(paths:, file: File)
          @paths = paths
          @file = file
        end

        def as_json
          {
            fs_map:,
            const_map:,
            scaffolding:,
          }
        end

        private

        def const_map
          @const_map ||= (
            full_map = Hash.new { |h, k| h[k] = [] }

            paths
              .each { |path|
                consts_by_path.fetch(path).each { |c| full_map[c.full_name] << path }
              }

            full_map.transform_values(&:uniq!)
            full_map
          )
        end

        def scaffolding
          serialized = {}
          results = []

          consts.each { |const|
            push_bootstrapper(const, results, serialized)
          }

          results
        end

        def push_bootstrapper(const, results, serialized)
          return if serialized.key?(const.full_name)

          serialized[const.full_name] = true

          const.nesting.each do |_nesting_const|
            push_bootstrapper(const, results, serialized)
          end

          parent = (
            if const.parent
              resolve_const_name(const.nesting.last&.full_name, const.parent)
            end
          )

          if parent.is_a?(Const)
            push_bootstrapper(parent, results, serialized)
          end

          parent_name = parent.is_a?(Const) ? parent.full_name : parent

          parent_str = "< #{parent_name}" if parent
          results << <<~TXT
            #{const.type} #{const.full_name} #{parent_str}
              class << self
                include Interfacets::Client::Assets::AutoloadHook
              end
            end
          TXT
        end

        def resolve_const_name(nesting, name)
          full_name = [nesting, name].compact.join("::")
          return consts_by_name[full_name] if consts_by_name.key?(full_name)

          # maybe a constant that we don't handle loading for (eg, StandardError)
          return name if nesting.nil? || nesting.empty?

          resolve_const_name(nesting.split("::")[0...-1].join("::"), name)
        end

        def consts_by_name
          @consts_by_name ||= consts.group_by(&:full_name).transform_values(&:first)
        end

        def fs_map
          paths.map { [_1, file.read(_1)] }.to_h
        end

        def consts
          @consts ||= consts_by_path.values.flatten
        end

        def consts_by_path
          @consts_by_path ||= (
            fs_map
              .transform_values { |code| Classifier.new(code).consts }
          )
        end
      end

      GEM_DIRS = [
        File.expand_path(File.join(__dir__, "../shared")),
        File.expand_path(File.join(__dir__, "../client")),
        File.expand_path(File.join(__dir__, "../client.rb")),
      ].freeze

      class << self
        def bundle(dirs:, registry:)

          registry.serialize

          (dirs + GEM_DIRS + [registry.build_dir])
            .flat_map { paths(_1) }
            .flatten
            .map(&:to_s)
            .then { Serializer.new(paths: _1).as_json }
        end

        private

        def paths(path)
          if File.file?(path)
            [path]
          else
            [
              Dir.glob(File.join(path, "*.rb")),
              Dir.glob(File.join(path, "**/*.rb")),
            ].flatten
          end
        end
      end
    end
  end
end
