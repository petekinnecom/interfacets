import * as MRuby from "./ruby.js"
import { handler } from "./system/handler.js"

export function init(worker) {
  worker.rubyEvent = (jsonStr) => {
    postMessage({ type: "interfacets:system:render", payload: jsonStr })
  }

  worker.addEventListener("message", handler(MRuby, worker))
}
