import { handler } from "./handler.js"

export async function init(mrubyMod) {
  global.self = {
    rubyEvent: (jsonStr) => {
      workerBus.postMessage({ type: "interfacets:system:render", payload: jsonStr })
    }
  }

  const mainBus = {
    postMessage: (event) => {
      inlineHandler({ data: event })
    },
  }
  const workerBus = {
    postMessage: (event) => { mainBus.onmessage({ data: event }) }
  }
  const inlineHandler = handler(mrubyMod, workerBus)

  return mainBus
}
