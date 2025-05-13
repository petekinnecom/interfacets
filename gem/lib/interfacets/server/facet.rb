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

        def client(&block)
          clients << block
        end

        def clients
          @clients ||= []
        end

        def shared(&block)
          shareds << block
        end

        def shareds
          @shareds ||= []
        end

        def server(&block)
          servers << block
        end

        def servers
          @servers ||= []
        end
      end
    end
  end
end
