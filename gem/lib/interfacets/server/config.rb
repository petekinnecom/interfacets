# frozen_string_literal: true

module Interfacets
  module Server
    class Config
      attr_reader :registry
      attr_accessor(
        :mount_point,
        :host,
      )

      def initialize(
        mount_point:,
        registry:,
        assets:
      )
        @mount_point = mount_point
        @registry = registry
        @assets = assets
      end

      def bundled_assets
        dirs = @assets.map(&:to_s)

        facets = (
          @registry
            .values
            .map { Object.const_get(_1) }
        )

        Interfacets::Server::Assets.bundle(dirs:, facets:)
      end

      def schema
        @facet_registry
          .values
          .map { Object.const_get(_1) }
          .then {
            Interfacets::Server::Facets::Schema::Serializer
              .call(facets: _1)
          }
      end

      def register_facet(name, class_or_class_name)
        # if klass.name is nil, then just use the class reference
        @facet_registry[name] = class_or_class_name
      end

      def all_facets
        @facet_registry.keys.map { facet(_1) }
      end

      def default_facet
        build_facet(facet_uid: @default_facet)
      end

      def facet(name)
        klass_name = (
          if @facet_registry.key?(name)
            @facet_registry.fetch(name)
          elsif @facet_registry.values.include?(name)
            name
          else
            raise("unknown facet_class: #{name}")
          end
        )

        klass_name.constantize
      end

      def ingest_facet(data)
        Facets::Deserializer.call(data:, config: self)
      end

      def build_facet(facet_uid: nil, name: nil, id: nil, query: {})
        if name
          facet(name).build(id, query:)
        elsif @facet_registry.key?(facet_uid)
          facet(facet_uid).build(nil, query:)
        else
          *name, id = facet_uid.split("/")
          facet(name.join("/")).build(id, query:)
        end
      end
    end
  end
end
