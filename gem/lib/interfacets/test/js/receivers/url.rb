# frozen_string_literal: true

require 'uri'

module Interfacets
  module Test
    module Js
      module Receivers
        class Url
          class Handler
            def initialize(state)
              @state = state
            end

            def url
              url_spec = @state.fetch("urlSpec")
              base_url = url_spec["url"]
              query_params = url_spec["queryParams"]

              return base_url if query_params.nil? || query_params.empty?

              uri = URI(base_url)
              uri.query = URI.encode_www_form(query_params)
              uri.to_s
            end

            def redirected_url
              @state.fetch("redirectSpec")
            end
          end

          attr_reader :server, :name, :response_queue
          def initialize(name:)
            @name = name
            @response_queue = []
          end

          def receive(payload:, dispatch:)
            @dispatch = dispatch

            return if payload.nil?
            return if payload.empty?
            return if payload.dig("streams", "default").nil?
            return if payload.dig("streams", "default").empty?

            @handler = Handler.new(payload.dig("streams", "default"))
          end

          def handler
            @handler
          end

          def flush_responses
            response_queue.tap { @response_queue = [] }
          end
        end
      end
    end
  end
end
