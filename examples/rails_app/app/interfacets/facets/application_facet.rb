module Facets
  class ApplicationFacet
    include Interfacets::Server::Facet
    include Interfacets::Server::BasicRoutable
  end
end
