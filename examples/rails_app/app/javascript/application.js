import {
  reactHandler,
  InterfacetsProvider,
  FacetRenderer,
  initBus,
  submitHandler,
  urlHandler,
} from "interfacets"

import { registry } from "./interfacets/registry"

import React, { useEffect } from "react"
import { createRoot } from "react-dom/client";

// Initialize the worker
const rubyWorker = new Worker(
  document
    .querySelector("#interfacets-worker-path")
    .text
)

// Pull the system assets
const clientSystemJson = JSON.parse(
  document
    .querySelector("#interfacets-client-system-json")
    .text
)

// Pull the facet data on initial page load
const hydratedFacet = JSON.parse(
  document
    .querySelector("#interfacets-facet")
    .text
)

// Make a renderable component
const MyApp = ({ }) => {
  useEffect(() => {
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
            registry,
          })
        },
        url: { receive: urlHandler() },
        "interfacets:api": {
          receive: submitHandler()
        },
      },
    })
  }, [])


  // equivalent to:
  // <InterfacetsProvider>
  //   <FacetRenderer />
  // </InterfacetsProvider>

  return (
    React.createElement(
      InterfacetsProvider,
      {
        children: React.createElement(FacetRenderer)
      }
    )
  )
}

// Render it on page load:
document.addEventListener("DOMContentLoaded", async () => {
  const appRoot = createRoot(document.getElementById("main"))
  appRoot.render(React.createElement(MyApp))
});
