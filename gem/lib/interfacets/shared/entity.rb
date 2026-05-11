# frozen_string_literal: true

module Interfacets
  module Shared
    class Entity
      include Shared::Validations
      include EntityDsl

      class << self
        def inherited(subclass)
          subclass.inherit_attributes(self)

          subclass.action(:after_load, accepted_by: :client)

          subclass.accessor(
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

      def entity_at(nesting)
        # ignore first entry, cause it's self
        real_nesting = nesting[1..-1]

        if real_nesting.count == 0
          self
        else
          assoc, internal_entity_id = real_nesting[0]

          if association(assoc).collection?
            association(assoc).get.find { _1.internal_entity_id == internal_entity_id }
          else
            value = association(assoc).get
            value.internal_entity_id == internal_entity_id ? value : nil
          end
        end
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
