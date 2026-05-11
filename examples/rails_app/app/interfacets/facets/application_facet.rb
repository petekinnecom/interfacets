module Facets
  class ApplicationFacet
    include Interfacets::Shared::Facet

    # Make all facets routable:
    def self.inherited(mod)
      mod.include(Interfacets::Shared::BasicRoutable)
    end
  end
end
