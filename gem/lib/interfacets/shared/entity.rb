# frozen_string_literal: true

module Interfacets
  module Shared
    class Entity
      include Shared::Validations

      class << self
        attr_accessor :manifest

        def role(name = nil)
          @role = name.to_s if name
          @role
        end

        def accessor(
          name,
          getter: -> { store.send(name) },
          setter: ->(val) { store.send("#{name}=", val) },
          accepted_by: Entities::Specs::ANY
        )
          name = name.to_s
          accessors[name] = Entities::Specs::Accessor.new(name:, accepted_by:)

          define_method(name, &getter)
          define_method("#{name}=", &setter)
        end

        def association(*args, type: :reference, **params, &block)
          if type == :reference
            reference(*args, **params, &block)
          elsif type == :collection
            collection(*args, **params, &block)
          else
            raise ArgumentError
          end
        end

        def reference(
          name,
          **spec_params,
          &block
        )
          name = name.to_s
          spec = (associations[name] ||= Entities::Specs::Reference.new(parent: self, name: name))
          spec.apply(**spec_params, &block)

          define_method(name) do
            association(name).get
          end

          define_method("#{name}=") do |val|
            association(name).set(val)
          end
        end

        def collection(
          name,
          **spec_params,
          &block
        )
          name = name.to_s

          spec = (associations[name] ||= Entities::Specs::Collection.new(parent: self, name: name))
          spec.apply(**spec_params, &block)

          define_method(name) do
            association(name).get
          end

          define_method("#{name}=") do |val|
            association(name).set(val)
          end
        end

        def server_action(name, only_if_valid: true)
          action(name, accepted_by: :server, only_if_valid:)
          action("after_#{name}", accepted_by: :client)
        end

        def action(name, accepted_by: Entities::Specs::ANY, only_if_valid: false)
          name = name.to_s
          actions[name] = Entities::Specs::Action.new(name:, accepted_by:, only_if_valid:)

          define_method(name) do
            store.send(name)
          end
        end

        def accessors
          @accessors ||= {}
        end

        def associations
          @associations ||= {}
        end

        def actions
          @actions ||= {}
        end

        def attributes
          accessors.merge(associations)
        end

        def inherited(mod)
          mod.action(:after_load, accepted_by: :client)

          mod.accessor(
            :internal_entity_id,
            getter: -> {
              if store.respond_to?(:internal_entity_id)
                store.internal_entity_id
              else
                (@interfacets_id ||= SecureRandom.uuid)
              end
            },
            setter: ->(val) {
              if store.respond_to?(:internal_entity_id=)
                store.internal_entity_id = val
              else
                @interfacets_id = val
              end
            }
          )
        end
      end

      attr_reader :store, :parent
      def initialize(store:, nesting:, parent:)
        @store = store
        @parent = parent
        @nesting = nesting
      end

      def record
        store
      end

      def ==(other)
        if other.is_a?(Entity)
          store == other.store
        else
          store == other
        end
      end

      def role
        if parent.nil?
          self.class.role
        else
          parent.role
        end
      end

      def uid
        [self.class.name, internal_entity_id].join("__")
      end

      def entity_nesting
        @entity_nesting ||= (parent&.entity_nesting || []) + [[@nesting, internal_entity_id]]
      end

      def association(name)
        # inlined to avoid polluting API
        @association_handlers ||= (
          self
            .class
            .associations
            .map { |name, spec| [name, spec.handler(self) ] }
            .to_h
        )

        @association_handlers.fetch(name.to_s)
      end
    end
  end
end
