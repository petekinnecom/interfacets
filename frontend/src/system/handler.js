let mruby;

import { logger } from "../logger.js"

export function handler(mrubyMod, worker) {
  return async (event) => {
    if (event.data?.source == "react-devtools-content-script") {
      return
    }

    if (event.data.type == "interfacets:start") {
      if (!mruby) {
      mruby = await mrubyMod["default"]()
      logger.debug("worker started")
      }
      worker.postMessage({ type: "interfacets:started" })
    }
    else if (event.data.type == "interfacets:eval") {
      const { string, path } = event.data

      mruby._ruby_eval(
        mruby.stringToNewUTF8(string),
        mruby.stringToNewUTF8(path)
      )
    } else if (event.data.type == "interfacets:call") {
      mruby._ruby_call(
        mruby.stringToNewUTF8(event.data.jsonStr)
      )
    }
  }
}
