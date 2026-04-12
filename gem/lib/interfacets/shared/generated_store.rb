# frozen_string_literal: true

module Interfacets
  module Shared
    class GeneratedStore
      class Constructor
        def self.call(entity_class)
          klass = Class.new(GeneratedStore) do
            define_singleton_method(:name) { "#{entity_class.name}.GeneratedStore" }
          end

          entity_class.accessors.each do |name, spec|
            klass.accessor(name)
          end

          entity_class.associations.each do |name, spec|
            sub_class = call(spec.klass)

            if spec.type == :reference
              klass.association(name, klass: sub_class)
            else
              klass.collection(name, klass: sub_class)
            end
          end

          entity_class.actions.each do |name, spec|
            klass.define_method(name) do |entity:|
              Client::System
                .current_bus
                .channel("interfacets:api")
                .builder
                .submit(name, nesting: entity.entity_nesting)
            end
          end

          klass
        end
      end

      class Handler
        attr_reader :store, :spec
        def initialize(store:, spec:)
          @store = store
          @spec = spec
        end

        def build
          if spec.type == :reference
            value = spec.klass.new
            store.send("#{spec.name}=", value)
            value
          else
            value = spec.klass.new
            items = store.send(spec.name)
            if items.nil?
              store.send("#{spec.name}=", [value])
            else
              items << value
            end

            value
          end
        end
      end


      class << self
        def construct(...)
          Constructor.call(...)
        end

        class Spec
          attr_reader(:name, :klass, :type)
          def initialize(name:, klass:, type:)
            @name = name
            @klass = klass
            @type = type
          end

          def build
            spec.klass.new
          end
        end

        def accessor(name)
          name = name.to_s

          define_method(name) do
            @attributes[name]
          end

          define_method("#{name}=") do |val|
            @attributes[name] = val
          end
        end

        def association(name, klass:, type: :reference)
          name = name.to_s

          associations[name] = Spec.new(
            name:,
            klass:,
            type:,
          )

          define_method(name) do
            @attributes[name]
          end

          define_method("#{name}=") do |val|
            @attributes[name] = val
          end
        end

        def collection(*args, **params)
          association(*args, **params, type: :collection)
        end

        def associations
          @associations ||= {}
        end
      end

      attr_accessor :attributes
      def initialize
        @attributes = {
          "internal_entity_id" => SecureRandom.uuid
        }
      end

      def ==(other)
        attributes == other.attributes
      end

      def association(name)
        @association_handlers ||= (
          self
            .class
            .associations
            .map { |name, spec| [name, Handler.new(store: self, spec:)] }
            .to_h
        )

        @association_handlers.fetch(name)
      end

    end
  end
end
