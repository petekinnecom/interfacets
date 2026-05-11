**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- Configuring

<br/>

# Rails Configuration Walkthrough

> 🚧 🚧 🚧: Configuration and routing are very much under construction.


## Example pre-configured app

If you'd prefer to just clone a repo to be up-and-running, I've made a [demo Rails app](https://github.com/petekinnecom/interfacets-demo) that is preconfigured out of the box. Otherwise, read on.


## Walkthrough

There are a kajillion approaches to writing, building, and distributing javascript. Communicating between client and server is similarly fraught with questions of authentication, cookies, headers, JWTs, JWTs inside of cookies, and more! Hopefully, Interfacets gives you the flexibility to bend it to your needs.

Big picture:

- You control what URL loads what facet
- You control what URL a facet uses for its server actions
- You control how javascript makes requests to the server
- You control how the server accepts those requests and responds

The following walkthrough should get you up and running on an empty Rails app. The approach priorites simplicity in setup. Hopefully, by understanding this configuration, you will see how to configure things more to your own specific desire, if needed.

We'll start by looking at the server side requirements.

## Where to put things?

In this example, we'll make an "interfacets" directory split into three parts: the facets themselves, code that is shared between client and server, and client-specific code.

Here's an example layout:


```
app/
└─ interfacets/
  ├─ facets/
  │ └─ blogs/
  │   ├─ show.rb
  │   └─ list.rb
  ├─ shared/
  │ └─ blogs/
  │   ├─ validations.rb
  │   └─ policies.rb
  └─ client/
    └─ blogs/
      ├─ title_component.rb
      └─ body_component.rb
```

Note that in this setup, the `app/interfacets/client` code is in our autoload path. This is done to make testing more convenient. The simplest integration testing setup runs the client and server code in the same ruby process. In the event that this is problematic, you can put the client specific-code in lib/ or some other non-autoloaded path.

## Configuring the Server Bus

The Server Bus is the main entry-point for interfacets on the server. It is the object that handles incoming requests as well as serializes assets for the client.

The data held by the bus is static, so you can construct it in an initializer and store a global reference to it (eg, `Rails.application.x.interfacets.bus`).

Importantly, you pass it an array of all asset paths in your application (including your facets). You cannot build a facet that the bus is not aware of (because the corresponding client code will not be present on the client).

We'll construct it in an initializer and set it on a global config:

```ruby
# config/initializers/interfacets.rb

Rails.configuration.x.interfacets.bus = (
  Interfacets::Server::Bus.new(
    root_url: "https://example.com/mount-point",
    asset_paths: [
      Rails.root.join("app/interfacets/shared"),
      Rails.root.join("app/interfacets/client"),
      Rails.root.join("app/facets"),
    ]
  )
)
```

## Configuring the BasicRouter

Interfacets provides this small class for handling basic routing in a generalized way.

### Path Resolution

The `BasicRouter` maps a path to both a facet class and a store id. Its rules are simple and rigid:

1. If full path matches, the store id is `nil`
2. Assumes last subpath is the `id` and matches the rest.

For example, here is a config and some example resolutions:

```ruby
"/blogs" => "Facets::Blogs::List",
"/blogs/show" => "Facets::Blogs::Show",

# path: /blogs
# resolves: Facets::Blogs::List, id: nil

# path: /blogs/17
# resolves: Facets::Blogs::List, id: 17

# path: /blogs/show/17
# resolves: Facets::Blogs::Show, id: 17

# path: /blogs/show
# resolves: Facets::Blogs::Show, id: nil
```
Importantly, note that the `id` param must always be last. This precludes us from using Rails-like patterns like `/blogs/1/edit`. It also means that we can route to our "list" facets with IDs and we can route to our "show" facets without IDs. Like I said, it's a work-in-progress.

### Construction

Like the server bus, this is an instance that can be constructed once and saved on a global.

```ruby
# config/initializers/interfacets.rb

Rails.configuration.x.interfacets.bus = ... # see above

Rails.configuration.x.interfacets.router = (
  Interfacets::Server::BasicRouter.new(
    bus: Rails.configuration.x.interfacets.bus,
    paths: {
      "/blogs" => "Facets::Blogs::List",
      "/blogs/show" => "Facets::Blogs::Show",
      ...
    }
  )
)
```

### Facet configuration

The `BasicRouter` resolves the facet and store id, but does not resolve the store itself. It assumes that the facet will do that.

The following example shows how we wire up a facet to load the store itself when the BasicRouter invokes it:

```ruby
class Facets::Blogs::Show < ApplicationFacet

  # you can put this in your ApplicationFacet:
  include Interfacets::Shared::BasicRoutable

  # the block will be yielded:
  #  - The `id` from the URL (potentially nil)
  #  - Query params as a hash
  #
  # The block must return a "built" facet
  # constructed using the `build` method
  # (it's the `build` method from the
  # ServerBus, see above for its API)
  server_entity do
    find do |id, query:|
      build(
        self, # the facet class to build
        Blog.find(id) # the store
      )
    end
  end
end
```

The `find` method allows us to build Facets of a different class entirely. We can also invoke `find` on other facets. This allows us to potentially handle permissions issues as well as invalid ids. Here's a more robust example:

```ruby
class Facets::Blogs::Show < ApplicationFacet
  include Interfacets::Shared::BasicRoutable

  server_entity do
    find do |id, query:|
      blog = Blog.find_by(id:)

      if blog.nil? || Current.user.cannot_view?(blog)
        build(
          Blogs::List,
          { error: "Blog not found" }
        )
      end

      build(self, blog)
    end
  end
end
```
You might read the prior example and suggest that the not-found case should actually return a 302 rather than a 200. Good point! Alas, this is all still a work-in-progress at this point. :)

### Rails routing

We will build a generic Rails controller to handle all Interfacets-related requests. We will assume that all relevant requests are nested under the subpath `/ui/`.

In order to handle our assets as simply as possible we will use a standard ERB template, attach our assets and facet data as JSON in a script tag.

Here is an example routes config:

```ruby
# routes.rb

get "/ui/*facet_path", to: "interfacets#show"
put "/ui/*facet_path", to: "interfacets#update"
```

Here is an example rails controller:

```ruby
class InterfacetsController < ApplicationController
  def show
    @facet_json = facet.render

    respond_to do |req|
      req.html { }
      req.json { render(json: @facet_json) }
    end
  end

  def update
    payload = params.dig(:event, :payload).to_unsafe_hash

    render(json: facet.handle(payload), status: 201)
  end

  private

  def facet
    @facet ||= (
      Rails
        .configuration
        .x
        .interfacets
        .router
        .call(params.fetch(:facet_path), query: query_params)
    )
  end

  def query_params
    params
      .except(
        :facet_path,
        :controller,
        :action,
        :format
      )
      .to_unsafe_h
  end
end
```

Here's the show template. Note that the `interfacets-client-system-json` is static assets. These could be pre-built and pushed to a CDN, but here we'll just build and attach them every request:

```html
# app/views/interfacets/show.html.erb

<script type="text/json" id="interfacets-client-system-json">
  <%= Rails.configuration.x.interfacets.bus.client_system_json.to_json.html_safe %>
</script>

<script type="text/json" id="interfacets-facet">
  <%= @facet_json.to_json.html_safe %>
</script>

<div id="main"></div>
```

## Configuring the javascript

This assumes you're building your app with esbuild.

First, add package `@petekinnecom/interfacets` to package.json.

> 🚧 🚧 🚧: This will be simplified in the future

Interfacets run the ruby WASM in a web-worker so that it's not a blocking operation. In order to do this, we must expose a separate, loadable `worker.js` file:

```javascript
/* /app/javascript/worker.js */

import { initWorker } from "interfacets"

initWorker(self)
```

In the main entrypoint, we configure the following:

- Pull the rubyWorker's asset path and start it
- pull the system json from the dom and parse it
- pull the facet data from the dom and parse it
- configure three channels: DOM, URL, and API.

We will use the default `submitHandler` because it works with our example rails controller. Importantly, however, it does not implement any authentication strategy. When you want to implement that, you'll need to construct your own submit handler.

```javascript
/* /app/javascript/application.js */

import {
  reactHandler,
  InterfacetsProvider,
  FacetRenderer,
  initBus,
  submitHandler,
  urlHandler,
} from "interfacets"

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
```

### Adding assets to layout

Your `application.js` is probably already accessible to the frontend.

We do not want to add an include tag for the `worker.js`, instead we want to share the asset path with the frontend so it can load it in a worker. For that reason, we just add it as a string that can be pulled from the dom. (see `const rubyWorker = ...` above).

```html
# app/views/layout/application.html.erb

<%= javascript_include_tag("app/javascript/application", defer: true, type: :module) %>

<script type="text/json" id="interfacets-worker-path">
  <%= asset_path("worker.js").to_s %>
</script>
```

---

**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- Configuring
