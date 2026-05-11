# frozen_string_literal: true

module Interfacets
  module Shared
    module EntityDsl
      extend ActiveSupport::Concern

      included do |base|
        if base.respond_to?(:inherit_attributes)
          base.inherit_attributes(self)
        end
      end

      class_methods do
        attr_accessor :manifest

        def role(name = nil)
          if name
            @role = name.to_s
          else
            @role
          end
        end

        def inheritable_attributes
          {
            accessors:,
            actions:,
            mergers:,
            role: @role,
            associations:,
            validators:
          }
        end

        def inherit_attributes(parent)
          return unless parent.respond_to?(:inheritable_attributes)
          attrs = parent.inheritable_attributes
          @accessors = attrs[:accessors].dup.merge(accessors)
          @actions = attrs[:actions].dup.merge(actions)
          @mergers = attrs[:mergers].dup.merge(mergers)
          @role ||= attrs[:role]

          attrs[:associations].each do |name, spec|
            associations[name] ||= spec.dup_for(self)
          end

          @validators = (attrs[:validators].dup + validators).uniq
        end

        def merge(name, *events, &block)
          spec = Entities::Specs::Merger.new(
            name:,
            block:
          )

          target = (mergers[name.to_s] ||= {})

          if events.empty?
            target[:default] = spec
          else
            events.each do |event|
              target[event.to_s] = spec
            end
          end
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

        def association(name, mod = nil, **spec_params, &block)
          name = name.to_s
          associations[name] ||= Entities::Specs::Association.new(parent: self, name: name)
          associations[name].apply(mod:, **spec_params, &block)

          define_method(name) do
            association(name).get
          end

          define_method("#{name}=") do |val|
            association(name).set(val)
          end
        end

        def reference(*a, **p, &b)
          association(*a, **p, type: :reference, &b)
        end

        def collection(*a, **p, &b)
          association(*a, **p, type: :collection, &b)
        end

        def server_action(name, only_if_valid: true)
          action(name, accepted_by: :server, only_if_valid:)
          action("after_#{name}", accepted_by: :client)

          define_method(name) do
            store.send(name, entity: self)
          end
        end

        def action(name, accepted_by: Entities::Specs::ANY, only_if_valid: false)
          name = name.to_s
          actions[name] = Entities::Specs::Action.new(name:, accepted_by:, only_if_valid:)

          define_method(name) {}
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

        def mergers
          @mergers ||= Hash.new { |h, k|
            h[k] = {
              default: Entities::Specs::Merger.new(
                name: k,
                block: ->(entity, value) {
                  entity.send("#{k}=", value)
                }
              )
            }
          }
        end

        def attributes
          accessors.merge(associations)
        end

        def validators
          @validators ||= []
        end
      end
    end
  end
end
