# frozen_string_literal: true

module Interfacets
  module Shared
    module Facet
      extend ActiveSupport::Concern

      class_methods do
        attr_accessor :shared, :entity, :store

        def mount(facet, as:, type: nil, &block)
          if block_given?
            parent_facet = facet
            facet = Module.new do
              include Interfacets::Shared::Facet

              server_entity do
                include parent_facet.server_entity_module
              end

              entity_base do
                include parent_facet.entity_base_module
              end

              client_entity do
                include parent_facet.client_entity_module
              end

              view_class.view(&parent_facet.view_class.view) if parent_facet.view_class.view

              class_exec(&block)
            end
          end

          server_entity do
            association(as, facet.server_entity_module, type:)
          end

          client_entity do
            association(as, facet.client_entity_module, type:)
          end

          entity_base do
            association(as, facet.entity_base_module, type:)
          end
        end

        def view(&block)
          view_class.view(&block)
        end

        def view_class
          @view_class ||= Class.new(Interfacets::Shared::View)
        end

        def client_entity(&block)
          clients << block
        end

        def clients
          @clients ||= []
        end

        def client_entity_module
          @client_entity_module ||= (
            facet = self
            Module.new do
              extend ActiveSupport::Concern
              include facet.entity_base_module

              included do
                define_singleton_method(:view) do
                  facet.view_class
                end

                role("client")
                facet.clients.each { class_exec(&_1) }
              end
            end
          )
        end

        def client_entity_class
          @client_entity_class ||= (
            facet = self
            Class
              .new(entity_base_class)
              .tap do |k|
                k.class_exec do
                  include facet.client_entity_module

                  define_singleton_method(:store) do
                    @store ||= (
                      ::Interfacets::Shared::GeneratedStore.construct(self)
                        .tap { self.const_set("Store", _1) }
                    )
                  end

                  self.manifest = facet.entity_base_class

                  def channel(name)
                    Interfacets::Client::System.current_bus.channel(name).builder
                  end
                end
              end
          )
        end

        def entity_base(&block)
          bases << block
        end

        def bases
          @bases ||= []
        end

        def entity_base_module
          @entity_base_module ||= (
            facet = self
            Module.new do
              extend ActiveSupport::Concern
              include Interfacets::Shared::EntityDsl
              included do
                facet.bases.each { class_exec(&_1) }
              end
            end
          )
        end

        def entity_base_class
          @entity_base_class ||= (
            facet = self

            Class.new(Shared::Entity)
              .tap { |k| k.include(facet.entity_base_module) }
              .tap { facet.const_set("EntityBase", _1) }
          )
        end

        def server_entity_module
          @server_entity_module ||= (
            facet = self
            Module.new do
              extend ActiveSupport::Concern
              include facet.entity_base_module
              included do
                role("server")
                facet.servers.each { class_exec(&_1) }
              end
            end
          )
        end

        def server_entity_class
          @server_entity_class ||= (
            facet = self

            Class.new(entity_base_class) {
              include facet.server_entity_module

              attr_reader :channel
              def initialize(*a, channel:, **p, &b)
                @channel = channel
                super(*a, **p, &b)
              end

              def build_entity(...)
                channel.build(...)
              end

              self.manifest = facet.entity_base_class
            }
          ).tap { facet.const_set("ServerBase", _1) }
        end

        def server_entity(unshift: false, &block)
          if unshift
            servers.unshift(block)
          else
            servers << block
          end
        end

        def servers
          @servers ||= []
        end
      end

      attr_reader :entity, :view
      def initialize(entity)
        @entity = entity
        @view = self.class.view.new if self.class.view.is_a?(Class)
      end

      def render(channels)
        view.render(entity:, channels:)
      end
    end
  end
end
