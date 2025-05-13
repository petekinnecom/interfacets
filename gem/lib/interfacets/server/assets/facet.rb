# frozen_string_literal: true

module Interfacets
  module Server
    module Assets
      class Facet
        def self.register(klass:, assets:)
          assets[klass.name] = new(klass).code
        end

        attr_reader :klass
        def initialize(klass)
          @klass = klass
        end

        def code
          # nest it all so names resolve
          *mods, klass_name = klass.name.split("::")

          headers = []
          footers = []

          current_mod = ""
          mods.each do |mod_name|
            current_mod += "::#{mod_name}"
            type = current_mod.constantize.is_a?(Module) ? :module : :class
            headers << "#{type} #{mod_name}"
            footers << "end"
          end

          headers << "class #{klass_name} < Interfacets::Client::Facet"
          footers << "end"

          <<~TXT
            #{headers.join("\n")}

              include Interfacets::Client::Facets::Schema

              view_spec #{write_source(klass.client_config.view.block)}

              entity_spec #{write_source(klass.client_config.api.block)}

              client_spec #{write_source(klass.client_config.entity.block)}
            #{footers.join("\n")}
          TXT
        end

        private

        def write_source(block)
          return unless block

          RubyVM::AbstractSyntaxTree
            .of(block, keep_script_lines: true)
            .source
            .strip
        end
      end
    end
  end
end
