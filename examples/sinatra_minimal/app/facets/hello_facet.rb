require "ostruct"

class HelloFacet
  include Interfacets::Shared::Facet
  include Interfacets::Shared::BasicRoutable

  view do |entity|
    render_to(:dom) do |c|
      c.div do
        c.h1("Hello from Interfacets!")
        c.button(
          "Click me",
          onClick: -> { entity.update }
        )
        c.p("Time: #{entity.time}")
      end
    end
  end

  client_entity do
  end

  entity_base do
    accessor(:time, accepted_by: :client)
    server_action(:update)
  end

  server_entity do
    find do |id, query:|
      build(self, OpenStruct.new(message: "Welcome to Sinatra + Interfacets!"))
    end

    def time
      Time.now.to_f
    end
  end
end
