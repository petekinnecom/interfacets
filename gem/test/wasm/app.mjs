import * as MRuby from "./test.mjs"
import { initTestWorker, initBus } from "interfacets/core"

const currentState = {}
let bus;

function handler(channelName) {
  return {
    receive: ({ payload, dispatch }) => {
      currentState[channelName] = {
        data: payload,
        dispatch
      }
    }
  }
}

export async function init({ clientSystemJson, hydratedFacet }) {
  const rubyWorker = await initTestWorker(MRuby)

  bus = await initBus({
    rubyWorker,
    clientSystemJson,
    bus: {
      id: "default",
    },
    clientSystemJson,
    channels: {
      dom: handler("dom"),
      url: handler("url"),
      "interfacets:api": handler("interfacets:api"),
    },
    hydratedFacet
  })
}

export function dispatch(channelName, event) {
  currentState[channelName].dispatch(event)
}

export function getState(channelName) {
  return currentState[channelName]
}
