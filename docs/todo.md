# My Todo List

## Entities

- Nesting required fixes, needs testing using facets/server actions and JS bus
- When a facet is destroyed as part of a server_action, the responding "after_{}" action cannot be called on an entity.

## BasicRoutable

- Bug! the api_path is assigned when the route is resolved, BUT what if the resulting facet has a different route? The original route gets assigned to `api_path` and this screws it up.

- on the server side you call channel.render(klass, store) to render a different facet in response. However, with BasicRoutable, it's probably preferable to do `channel.render(klass, id, query:)`

## Testing
- When testing, if an MRuby exception is raised, the browser should raise with that error, rather than silently continuing
- Requests are not passed through Rails, they're intercepted. This is probably ok, but something to think about

## Rails reloading

If you set facets: `-> { ApplicationFacet.descendents }`, then the show will work, but if you trigger an action that gets a *new* facet, it will be loaded on the server now, but it will not be in the assets present on the client. So you either need to send it along *OR* list out all your facets in the initializer (ie, eager load them all. :(
