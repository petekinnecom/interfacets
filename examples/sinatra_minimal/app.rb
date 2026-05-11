require "sinatra"
require "interfacets"

# Load our facet
require_relative "app/facets/hello_facet"

# Configure interfacets
configure do
  set :server_bus, Interfacets::Server::Bus.new(
    root_url: "http://localhost:4569",
    asset_paths: [
      File.expand_path("app/facets", __dir__),
    ]
  )

  set :router, Interfacets::Server::BasicRouter.new(
    bus: settings.server_bus,
    paths: {
      "/" => "HelloFacet"
    }
  )
end

# Serve the UI
get "/" do
  facet = settings.router.call("/")
  @facet_json = facet.render

  erb :index
end

# Handle server actions
put "/" do
  payload = JSON.parse(request.body.read).dig("event", "payload")
  facet = settings.router.call("/")

  content_type :json
  facet.handle(payload).to_json
end
