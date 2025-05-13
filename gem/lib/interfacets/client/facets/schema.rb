# frozen_string_literal: true

module Interfacets
  module Client
    module Facets
      module Schema
        extend ActiveSupport::Concern
        class_methods do
          def view_spec(&block)
            @view_spec = block
          end

          def view
            # TODO: change this to just inherit from view
            @view ||= View.new(
              block: @view_spec,
              name: "#{self.name}::View",
            )
          end

          def client_spec(&block)
            @client_spec = block
          end

          def client
            # scoping
            client_name = "#{self.name}::Client"
            client_spec = @client_spec
            entity = self.entity

            @client ||=
              Class.new(Entity) do
                define_singleton_method(:name) { client_name }
                extend_entity { include entity }

                class_exec(&client_spec)
              end
          end

          def entity_spec(&block)
            @entity_spec = block
          end

          def entity
            # scoping
            entity_name = "#{self.name}::Entity"
            entity_spec = @entity_spec

            @entity ||=
              Module.new do
                extend ActiveSupport::Concern
                define_singleton_method(:name) { entity_name }

                included do
                  class_exec(&entity_spec)
                end
              end
          end
        end
      end
    end
  end
end
