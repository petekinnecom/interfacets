# frozen_string_literal: true

module Interfacets
  module Shared
    module Entities
      module Specs

        # I would like to use Object.new for object equality here, however,
        # in the intergration tests, our shared code gets evaled on the frontend
        # and again on the backend (for now). For that reason, we cannot use
        # object equality because the constant will be overridden.
        NOT_PASSED = :interfacets__not_passed_flag
        ANY = :interfacets__any_flag

        module Acceptable
          def accepted_by?(role)
            standardized_accepted_by == ANY || standardized_accepted_by.include?(role)
          end

          def standardized_accepted_by
            @standardized_accepted_by ||= (
              if accepted_by == ANY
                ANY
              else
                 Array(accepted_by).map(&:to_s)
              end
            )
          end
        end

        class Action
          include Acceptable

          attr_reader :name, :accepted_by, :only_if_valid
          def initialize(name:, accepted_by:, only_if_valid:)
            @name = name
            @accepted_by = accepted_by
            @only_if_valid = only_if_valid
          end


          def type = :action

          def dispatch(entity)
            if !only_if_valid || entity.valid?
              entity.send(name)
            end
          end
        end

        class Accessor
          include Acceptable

          attr_reader :name, :accepted_by
          def initialize(name:, accepted_by:)
            @name = name
            @accepted_by = accepted_by
          end

          def type = :accessor
        end

        class Association
          include Acceptable

          attr_reader(
            :name,
            :accepted_by,
            :klass,
            :getter,
            :setter,
            :builder,
            :parent,
            :identifier,
          )
          def initialize(parent:, name:)
            @parent = parent
            @name = name
            @accepted_by = Entities::Specs::ANY
            @getter = -> { store.send(name) }
            @setter = ->(val) { store.send("#{name}=", val) }
            @builder = ->() { store.association(name).build }
            @identifier = "id"
            @klass = Class.new(Entity) do
              define_singleton_method(:name) { "#{parent.name}.#{name}" }
            end
          end

          def apply(
            accepted_by: NOT_PASSED,
            getter: NOT_PASSED,
            setter: NOT_PASSED,
            builder: NOT_PASSED,
            identifier: NOT_PASSED,
            &block
          )
            @accepted_by = Array(accepted_by).map(&:to_s) unless accepted_by == NOT_PASSED
            @getter = getter unless getter == NOT_PASSED
            @setter = setter unless setter == NOT_PASSED
            @builder = builder unless builder == NOT_PASSED
            @identifier = identifier.to_s unless identifier == NOT_PASSED
            klass.class_exec(&block) if block_given?
          end
        end

        class Reference < Association
          def type = :reference

          def handler(entity)
            Handlers::Reference.new(entity:, spec: self)
          end
        end

        class Collection < Association
          def type = :collection

          def handler(entity)
            Handlers::Collection.new(entity:, spec: self)
          end
        end

        class Merger
          attr_reader(:name, :block)
          def initialize(name:, block:)
            @name = name
            @block = block
          end

          def call(entity, value)
            block.call(entity, value)
          end
        end
      end
    end
  end
end
