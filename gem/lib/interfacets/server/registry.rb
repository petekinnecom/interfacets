# frozen_string_literal: true

require "active_support/all"

module Interfacets
  module Server
    class Registry
      attr_reader :build_dir, :specs
      def initialize(facets:, build_dir:)
        @build_dir = build_dir
        @specs = Array(facets)
      end

      def register
        specs
          .flat_map { _1.respond_to?(:call) ? _1.call : _1 }
          .each do |klass_or_name|

            klass = (
              if klass_or_name.is_a?(String)
                if registry.key?(klass_or_name)
                  next
                else
                  Object.const_get(klass_or_name)
                end
              else
                klass_or_name
              end
            )

            next if registry.key?(klass.name)

            shared = Class.new(Shared::Entity) do
              klass.shareds.each { class_exec(&_1) }
            end

            entity = Class.new(Shared::Entity) do
              self.manifest = shared
              role("server")

              klass.shareds.each { class_exec(&_1) }
              klass.servers.each { class_exec(&_1) }

              attr_writer :channel
              def channel
                @channel || parent.channel
              end
            end

            registry[klass.name] = { klass:, entity:}
          end
      end

      def build(name, store)
        register
        entry = registry.fetch(name.is_a?(Class) ? name.name : name)



        Api.new(
          registry: self,
          name:,
          entity: (
            entry
              .fetch(:entity)
              .new(
                store: store.is_a?(Hash) ? OpenStruct.new(store) : store,
                nesting: ["root"],
                parent: nil
              )
          )
        )
      end

      def serialize
        register
        FileUtils.mkdir_p(build_dir)

        registry.each do |name, entry|
          base_name = "#{name}::Client"

          header = ""
          footer = ""
          nesting = []
          name.split("::").each do |mod|
            nesting << mod
            footer += "\nend"
            header +=(
              if nesting.join("::").constantize.is_a?(Class)
                "\nclass #{mod}"
              else
                "\nmodule #{mod}"
              end
            )
          end
          header += "\nmodule Client"
          footer += "\nend"

          File.write(
            File.join(build_dir, path_for("#{base_name}::Shared")),
            <<~TXT
              #{header}
              class Shared < Interfacets::Shared::Entity
                #{
                  entry
                    .fetch(:klass)
                    .shareds
                    .map { write_source(_1) }
                    .map { "class_exec(&#{_1})" }
                    .join("\n")
                }
              end
              #{footer}
            TXT
          )

          File.write(
            File.join(build_dir, path_for("#{base_name}::View")),
            <<~TXT
              #{header}
              class View < Interfacets::Client::View
                #{
                  entry
                    .fetch(:klass)
                    .views
                    .map { write_source(_1) }
                    .map { "view(&#{_1})"}
                    .join("\n")
                }
              end
              #{footer}
            TXT
          )

          File.write(
            File.join(build_dir, path_for("#{base_name}::Entity")),
            <<~TXT
              #{header}
              class Entity < Interfacets::Shared::Entity
                class << self
                  def view
                    #{base_name}::View
                  end

                  def store
                    @store ||= (
                      ::Interfacets::Shared::GeneratedStore.construct(self)
                        .tap { self.const_set("Store", _1) }
                    )
                  end
                end

                role("client")

                #{
                  entry
                    .fetch(:klass)
                    .shareds
                    .map { write_source(_1) }
                    .map { "class_exec(&#{_1})" }
                    .join("\n")
                }

                #{
                  entry
                    .fetch(:klass)
                    .clients
                    .map { write_source(_1) }
                    .map { "class_exec(&#{_1})" }
                    .join("\n")
                }

                self.manifest = Shared

                actions.each do |name, spec|
                  if name.start_with?("after_")
                    define_method(name) {}
                  end
                end

                def channel(name)
                  Interfacets::Client::System.current_bus.channel(name).builder
                end
              end
              #{footer}
            TXT
          )
        end
      end

      def registry
        @registry ||= {}
      end

      private

      def path_for(class_name)
        "#{class_name.gsub("::", "-")}.rb"
      end

      def write_source(block)
        return unless block

        RubyVM::AbstractSyntaxTree
          .of(block, keep_script_lines: true)
          .source
          .then { block.is_a?(UnboundMethod) ? _1 : "lambda #{_1}" }
          .strip
      end
    end
  end
end
