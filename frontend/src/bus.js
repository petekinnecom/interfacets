import { init, system } from "./system.js"

export const connect = async ({
  bus: { id },
  rubyWorker,
  channels,
  clientSystemJson,
  hydratedFacet,
  logLevel = "fatal"
}) => {

  await init({
    rubyWorker,
    clientSystemJson,
    logLevel
  })

  system.buses[id] = { id, channels: channels };
  system.ruby.call({
    receiver: "Interfacets::Client.system",
    method: "handle",
    args: [{
      destination: { },
      type: "interfacets:system:create_bus",
      payload: {
        id: id,
        config: clientSystemJson,
        channel_ids: Object.keys(channels),
        hydration: {
          destination: { bus: id, channel: "interfacets:api" },
          type: "interfacets:api:hydrate",
          payload: hydratedFacet
        }
      }
    }]
  });
}
