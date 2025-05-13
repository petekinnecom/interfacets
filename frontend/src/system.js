// put it on window for easier debugging
import { logger } from "./logger.js"

export const system = {
  buses: {},
}

const dispatchEvent = ({ busId, channelId, payload }) => {
  logger.debug(`dispatch event`, { busId, channelId, payload })
  system.ruby.call({
    receiver: "Interfacets::Client.system",
    method: "handle",
    args: [{
      destination: { bus: busId, channel: channelId },
      type: "interfacets:channel:event",
      payload
    }]
  });
}

const handleChannelRender = (bus, { id, payload }) => {
  const channel = bus.channels[id]

  if (!channel) { throw `unknown channel ${id}` }

  channel.receive({
    payload,
    dispatch: async (event) => {
      dispatchEvent({ busId: bus.id, channelId: id, payload: event })
    }
  })
}

const handleBusRender = ({ type, id, payload }) => {
  if (type == "interfacets:bus:render") {
    const bus = system.buses[id]

    payload.forEach(c => {
      handleChannelRender(bus, c)
    })
  } else {
    console.error("unknown type", type, id, payload)
  }
}

const rubyEvent = async (json) => {
  if (json.events) { return }

  const { type, payload } = json.data

  // Check for interfacets:started event
  if (type === "interfacets:started") {
    if (system.startResolver) {
      system.startResolver();
      system.startResolver = null;
    }
  } else if (type == "interfacets:system:render") {
    handleBusRender(payload.payload)
  } else {
    throw `unhandled rubyEvent: ${type}`
  }
}

export const init = async ({
  rubyWorker,
  clientSystemJson,
  force = false,
  logLevel
}) => {
  if (system.ruby && !force) { return }

  rubyWorker.onmessage = rubyEvent

  // Create a promise that will resolve when the ruby worker responds
  const startPromise = new Promise(resolve => {
    system.startResolver = resolve;
  });

  // Send the start event
  rubyWorker.postMessage({
    type: "interfacets:start"
  });

  // Wait for the worker to respond
  logger.debug("Waiting for ruby worker to start...");
  await startPromise;
  logger.debug("Ruby worker started successfully");

  system.ruby = {
    eval: (str, path = "") => {
      rubyWorker.postMessage({
        type: "interfacets:eval",
        string: str,
        path
      })
    },
    call: (json) => {
      rubyWorker.postMessage({
        type: "interfacets:call",
        jsonStr: JSON.stringify(json)
      })
    },
  };

  logger.debug("initializing assets");
  const assets = clientSystemJson.assets

  const assetsPath = assets.const_map["Interfacets::Client::Assets"][0]
  const assetsCode = assets.fs_map[assetsPath]

  system.ruby.eval(`ENV = {'DEFAULT_LOG_LEVEL' => "${logLevel}" }`)

  system.ruby.eval(assetsCode, assetsPath)


  system.ruby.call({
    receiver: "Interfacets::Client::Assets",
    method: "bootstrap",
    args: [clientSystemJson.assets]
  })
  logger.debug("Assets initialized")


  //  apply the users config
  system.ruby.call({
    receiver: "Interfacets::Client",
    method: "start",
    args: []
  })

  logger.debug("system initialized")
}
