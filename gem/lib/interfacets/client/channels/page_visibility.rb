# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      class PageVisibility
        include Channels::Base

        type("interfacets:page-visibility")

        def configure(facet:); end

        def handle(facet:, event:)
          facet.visibility_change(event.dig("payload", "state"))
        end

        def render(_facet); end
      end
    end
  end
end
