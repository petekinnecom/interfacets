# frozen_string_literal: true

module Interfacets
  module Client
    class Registry
      def initialize
        @stores = {}
      end

      def build(name, id)
        entity = Object.const_get("#{name}::Client::Entity")

        @stores[id] ||= entity.store.new

        entity.new(
          store: @stores[id],
          parent: nil,
          nesting: ["root"]
        )
      end

      def register(schema, namespace: "Things")
        schema.each do |name, schema|
          next if registry.key?(name)

          shared = Class.new(Shared::Entity) do
            schema.fetch("shared").each { class_exec(&eval(_1)) }
          end

          view = Class.new(View) do
            schema.fetch("view").each { view(&eval(_1)) }
          end

          entity = Class.new(Shared::Entity) do
            define_singleton_method(:view) { view }
            self.manifest = shared

            actions.each do |name, spec|
              if name.start_with?("after_")
                define_method(name) {}
              end
            end

            schema.fetch("shared").each { class_exec(&eval(_1)) }
            schema.fetch("client").each { class_exec(&eval(_1)) }
          end

          store = Shared::GeneratedStore.construct(entity)

          mod = set_const(
            [
              namespace,
              name.split("::"),
            ].flatten,
            Module.new
          )
          entity.define_singleton_method(:facet_name) { name }
          mod.const_set("Entity", entity)
          entity.const_set("Shared", shared)
          entity.const_set("View", view)

          registry[name] = { entity:, store: }
        end
      end

      private

      def set_const(mods, klass)

        namespace = Object

        mods[0..-1].each do |mod|
          namespace = (
            if namespace.const_defined?(mod, false)
              namespace.const_get(mod)
            else
              namespace.const_set(mod, Module.new)
            end
          )
        end

        namespace.const_set(mods.last, klass)
      end

      def registry
        @registry ||= {}
      end
    end
  end
end
