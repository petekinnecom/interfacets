# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      class Url
        include Channels::Base

        type("interfacets:url")

        class Builder
          attr_reader :state
          def initialize
            @state = {}
          end

          def path(path, query: {})
            state[:urlSpec] = {
              url: (
                System
                  .current_bus
                  .url_for(path)
              ),
              queryParams: query,
            }
          end

          def redirect(url, query: {})
            @redirected = true
            state[:redirectUrlSpec] = { url:, query: }
          end

          def redirected?
            @redirected
          end
        end

        def prepare(entity)
          @builder ||= Builder.new
        end

        def builder(stream = "default")
          @builder
        end

        def result
          { streams: { default: @builder.state } }
        end
      end
    end
  end
end
