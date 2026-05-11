# config/initializers/interfacets.rb

Rails.configuration.to_prepare do
  # Interfacets.reload
  Rails.configuration.x.interfacets.bus = (
    Interfacets::Server::Bus.new(
      root_url: "http://localhost:3005/ui",
      asset_paths: [
        Rails.root.join("app/interfacets/shared"),
        Rails.root.join("app/interfacets/client"),
        Rails.root.join("app/facets"),
      ],
    )
  )

  Rails.configuration.x.interfacets.router = (
    Interfacets::Server::BasicRouter.new(
      bus: Rails.configuration.x.interfacets.bus,
      paths: {
        "/users/index" => "Facets::Users::Index",
        "/users" => "Facets::Users::Show"
      }
    )
  )
end
