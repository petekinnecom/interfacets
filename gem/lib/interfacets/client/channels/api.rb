# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      class Api
        include Channels::Base

        class Builder
          attr_accessor :request, :entity

          def render(path)
            raise("only one submission per action") if request

            System.logger.debug("Getting #{path}")

            request_id = SecureRandom.uuid

            self.request = {
              url: Client::System.current_bus.url_for(path),
              method: "get",
            }
          end

          def submit(meth, nesting: )
            raise("only one submission per action") if request

            System.logger.debug("submitting #{meth}")

            request_id = SecureRandom.uuid

            self.request = {
              url: (
                if entity.respond_to?(:api_path)
                  Client::System.current_bus.url_for(entity.api_path)
                end
              ),
              method: "put",
              body: {
                event: {
                  id: request_id,
                  type: "interfacets:api:submit",
                  payload: (
                    Shared::Entities::Bus
                      .new(entity:)
                      .serialize(
                        to: "server" ,
                        action: meth,
                        nesting:
                      )
                  )
                },
              },
            }
          end
        end

        type("interfacets:api")

        def prepare(entity)
          # must persist builder here
          # probably all channels need to persist their
          # builder. Because the bus calls "handle" before
          # the "prepare" call. Perhaps these should be
          # reversed?
          @builder ||= Builder.new
          @builder.entity = entity
        end

        def builder(stream = "default")
          @builder
        end

        def result
          {
            streams: {
              default: @builder.request,
            },
          }.tap { @builder.request = nil }
        end

        def handle(event:, entity:, build_entity:)
          facet_name = event.fetch("facet")
          id = event.dig(
            "payload",
            "payload",
            "attributes",
            "internal_entity_id"
          )

          entity = build_entity.(facet_name, id)

          Shared::Entities::Bus
            .new(entity:)
            .handle(
              event: event.fetch("payload")
            )
        end
      end
    end
  end
end
