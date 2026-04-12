# frozen_string_literal: true
require "active_support/concern"

module Interfacets
  module Server
    module Facet
      extend ActiveSupport::Concern

      class Actor
        def initialize(entity:, facet:)
          @entity = entity
          @facet = facet
        end
      end

      class_methods do
        def view(&block)
          views << block
        end

        def views
          @views ||= []
        end

        def client_entity(&block)
          clients << block
        end

        def clients
          @clients ||= []
        end

        def entity_base(&block)
          bases << block
        end

        def bases
          @bases ||= []
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
    end
  end
end
