import React, {
  useState,
  useEffect,
  createContext,
  useContext,
  forwardRef,
} from "react"

import { withTransform } from "../interfacets/withTransform"

const buses = {}
const defaultState = {}

const memoizedActions = {}

const memoizedAction = (value, dispatch) => {
  const id = value.payload.id

  if (!memoizedActions[id]) {
    memoizedActions[id] = async (ev) => {
      value.payload["event"] = ev
      dispatch(value)
    }
  }

  return memoizedActions[id]
}

const convertAttributesToJs = ({
  value,
  dispatch,
  jsProps,
  registry,
  depth = 0,
}) => {
  if (depth > 10) {
    return value
  } else if (value?.type == "interfacets:react-dom:action") {
    return async (ev) => {
      ev?.preventDefault ? ev.preventDefault() : null
      try {
        value.payload["event"] = JSON.parse(JSON.stringify(ev))
      } catch (e) {

        // TEMPORARY RESTORE
        if (ev?.target) {
          // This is an HTML event which can't be serialized
          value.payload["event"] = {
            value: ev.target?.value,
          }
        } else {
          value.payload["event"] = ev
        }
        console.warn(`Failed to serialize event for ${value}. Using fallback`)
      }
      dispatch(value)
    }
  } else if (value?.type == "interfacets:react-dom:memoized-action") {
    return memoizedAction(value, dispatch)
  } else if (value?.type == "interfacets:react-dom:prop") {
    // ['a', 'b', 'c'] => jsProps.a.b.c
    return value.payload["path"].reduce((o, i) => o[i], jsProps)
  } else if (value?.type == "interfacets:react-dom:element") {
    return render({ ...value, dispatch, registry })
  } else if (value?.type == "interfacets:mount-metadata") {
    return render({ ...value['content'], dispatch, registry })
  } else if (Array.isArray(value)) {
    return value.map(v => convertAttributesToJs({ registry, value: v, dispatch, jsProps, depth: depth + 1 }))
  } else if (value === null || value === undefined) {
    return null;
  } else if (typeof value == "object") {
    return Object.entries(value).reduce((acc, [key, v]) => {
      acc[key] = convertAttributesToJs({ registry, value: v, dispatch, jsProps, depth: depth + 1 })
      return acc;
    }, {});
  } else {
    return value;
  }
}

const Config = {
  renderer: React,
}

const render = ({
  type,
  element,
  children,
  attributes,
  key = 0,
  dispatch,
  registry,
  jsProps,
}) => {
  if (type == "interfacets:string-node") {
    return attributes.value;
  }

  let props = convertAttributesToJs({
    value: (attributes || {}),
    dispatch,
    jsProps,
    registry,
  })
  props.key || (props.key = key)

  if (children?.length > 0) {
    props = {...props, children: children?.map((c, i) => render({ ...c, key: i, dispatch, registry })) }
  }

  let resolvedElement = registry[element] || (registry["_default"] && [element]) || element

  return Config.renderer.createElement(resolvedElement, props)
}

// React startup is a mess of dependencies.
// should turn it into a promise or something
// and use suspense or something.

const memo = {}
const MemoNode = ({ memoKey, memoVal, children }) => {
  if (memo[memoKey] && memo[memoKey].memoVal == memoVal) {
    return memo[memoKey].component
  }

  const component = React.createElement(React.Fragment, { children })
  memo[memoKey] = { memoVal, component }
  return component
}


const cache = {}
const CacheNode = ({ cacheKey, children }) => {
  return cache[cacheKey] ||= React.createElement(React.Fragment, {children})
}

const defaultInput = (props) => {
  return React.createElement(
    "input", {
      ...props,
      value: props.value || "",
      onChange: (event) => {
        props.onChange && props.onChange(event.target.value)
      }
  })
}

export function reactHandler({ registry, bus }) {
  registry["React.Fragment"] ||= React.Fragment
  registry["Interfacets.Cache"] = CacheNode
  registry["Interfacets.Memo"] = MemoNode
  registry["input"] ||= defaultInput

  buses[bus] = {
    ...buses[bus],
    renderCount: 0,
    context: createContext(null),
    registry
  }

  return ({ payload, dispatch }) => {
    if (!buses[bus].component?.online) {
      buses[bus].component.online = true
      dispatch({ type: "interfacets:react-dom:online" })
    } else {
      buses[bus].component.updateState({
        state: payload,
        dispatch
      })

    }
  }
}

export function reactElement({ bus, dispatch, state, jsProps, ref }) {
  const registry = buses[bus].registry

  return state.dom.map((d, i) => (
    render({ ...d, key: i, dispatch, registry, jsProps, ref })
  ))
}

export function handle({ bus, payload }) {
  buses[bus].updateState(payload)
}

export function InterfacetsProvider({ bus="default", ...props }) {
  const [state, updateState] = useState({ offline: true })
  buses[bus] ||= {
    component: { updateState, online: false }
  }

  useEffect(() => {
    buses[bus].component.updateState = updateState
  })

  if (state.offline) { return }

  return (
    React.createElement(
      buses[bus].context.Provider,
      { ...props, value: state }
    )
  )
}

export const FacetRenderer = ({ bus = "default", stream = "default", ...jsProps }) => {
  const { state, dispatch } = useContext(buses[bus].context)
  const streamData = (state?.streams || {})[stream]
  if (!streamData) {
    return React.createElement("div", { style: { width: "10px", height: "10px", backgroundColor: "red" } })
  }

  return reactElement({ bus, dispatch, state: streamData, jsProps})
}
