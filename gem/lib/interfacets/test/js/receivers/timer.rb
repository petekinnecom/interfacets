# frozen_string_literal: true

module Interfacets
  module Test
    module Js
      module Receivers
        class Timer
          include Enumerable

          class Registration
            attr_reader :ms, :response_payload, :dispatch

            def initialize(ms:, response_payload:, dispatch:)
              @ms = ms
              @response_payload = response_payload
              @dispatch = dispatch
              @notified = false
            end

            def notify
              return if @notified
              @dispatch.call({ payload: response_payload })
              @notified = true
            end
          end

          attr_reader :name, :registrations
          def initialize(name:)
            @name = name
            @registrations = []
          end

          def receive(payload:, dispatch:)
            @dispatch = dispatch

            return if payload.nil?
            return if payload.empty?
            return if payload.dig("streams", "default").nil?
            return if payload.dig("streams", "default").empty?

            event = payload.dig("streams", "default")
            ms = event["ms"]
            response_payload = event["response"]

            return unless ms && response_payload

            @registrations << Registration.new(
              ms: ms,
              response_payload: response_payload,
              dispatch: dispatch
            )
          end

          def handler
            self
          end

          def first
            registrations.first
          end

          def last
            registrations.last
          end

          def each(&block)
            registrations.each(&block)
          end

          def clear
            @registrations = []
          end
        end
      end
    end
  end
end
