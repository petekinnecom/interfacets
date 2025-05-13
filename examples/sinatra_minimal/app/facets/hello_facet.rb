require "ostruct"

class HelloFacet
  include Interfacets::Server::Facet
  include Interfacets::Server::BasicRoutable

  view do |entity|
    render(:dom) do |c|
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

  client do
  end

  shared do
    accessor(:time, accepted_by: :client)
    server_action(:update)
  end

  find do |id, query:|
    build(self, OpenStruct.new(message: "Welcome to Sinatra + Interfacets!"))
  end

  server do
    def time
      Time.now.to_f
    end
  end
end
