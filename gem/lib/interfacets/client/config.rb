# frozen_string_literal: true

module Interfacets
  module Client
    class Config
      attr_accessor(
        :mount_point,
        :root_url
      )

      def url_for(path:)
        [
          root_url,
          mount_point,
          path,
        ]
          .map { _1.sub(%r{/$}, "").sub(%r{^/}, "") }
          .join("/")
      end
    end
  end
end
