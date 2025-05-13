import {
  reactHandler,
  InterfacetsProvider,
  FacetRenderer,
  initBus,
  submitHandler,
  urlHandler,
} from "@petekinnecom/interfacets"

import React, { useEffect } from "react"
import { createRoot } from "react-dom/client"

const MyApp = () => {
  useEffect(() => {
    // Initialize the worker
    const rubyWorker = new Worker("/assets/worker.js")

    // Pull the system assets
    const clientSystemJson = JSON.parse(
      document.querySelector("#interfacets-client-system-json").text
    )

    // Pull the facet data on initial page load
    const hydratedFacet = JSON.parse(
      document.querySelector("#interfacets-facet").text
    )

    initBus({
      clientSystemJson,
      rubyWorker,
      hydratedFacet,
      bus: {
        id: "default",
      },

      // Configure our channels
      channels: {
        dom: {
          receive: reactHandler({
            bus: "default",
            registry: {},
          })
        },
        url: { receive: urlHandler() },
        "interfacets:api": {
          receive: submitHandler()
        },
      },
    })
  }, [])

  return React.createElement(
    InterfacetsProvider,
    {
      children: React.createElement(FacetRenderer)
    }
  )
}

// Render it on page load
document.addEventListener("DOMContentLoaded", async () => {
  const appRoot = createRoot(document.getElementById("main"))
  appRoot.render(React.createElement(MyApp))
})
