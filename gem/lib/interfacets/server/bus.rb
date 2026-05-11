# frozen_string_literal: true

module Interfacets
  module Server
    class Bus
      attr_reader(
        :root_url,
        :asset_paths,
        :registry,
      )

      def initialize(root_url:, asset_paths:)
        @registry = Registry.new
        @root_url = root_url
        @asset_paths = asset_paths
      end

      def client_system_json(only_facets: false)
        {
          assets: Assets.bundle(dirs: asset_paths, registry:, only_facets:),
          root_url:
        }
      end

      def build(name:, store:)
        registry.build(name, store)
      end

      def handle(name:, id:, event:)
        registry.load(name, id).handle(event)
      end
    end
  end
end
