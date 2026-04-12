# frozen_string_literal: true

# require_relative "./channels/react"

module Interfacets
  module Test
    module Js
      module Receivers
        class Api
          attr_reader :router, :name, :response_queue
          def initialize(name:, router:)
            @name = name
            @router = router
            @response_queue = []
          end

          def handler
          end

          def receive(payload:, dispatch:)
            @dispatch = dispatch

            return if payload.nil?
            return if payload.empty?
            return if payload.dig("streams", "default").nil?
            return if payload.dig("streams", "default").empty?

            method = payload.dig("streams", "default", "method")
            url = payload.dig("streams", "default", "url")


            if method == "get"
              response_queue << router.call(url).render
            else
              payload
                .dig("streams", "default", "body", "event", "payload")
                .then { response_queue << router.call(url).handle(_1) }
            end
          end

          def flush_responses
            response_queue.tap { @response_queue = [] }
          end
        end
      end
    end
  end
end
