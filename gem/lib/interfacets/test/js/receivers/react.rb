# frozen_string_literal: true

require "nokogiri"
require_relative "./react/node"

module Interfacets
  module Test
    module Js
      module Receivers
        class React
          attr_reader :name, :node, :validation_engine
          def initialize(name:, validation_engine: nil)
            @name = name
            @validation_engine = validation_engine
            @actions = {}
          end

          def receive(payload:, dispatch:)
            @dispatch = dispatch
            @actions = nil
            @node&.stale!
            @node = Node.parse(json: payload, dispatch:, validation_engine:)
          end

          def handler
            @node
          end
        end
      end
    end
  end
end
