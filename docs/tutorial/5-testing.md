**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- Testing
- [Configuring](6-configuring.md)

<br/>

# Testing

Your backend is ruby and now your frontend is ruby. You can test them together! <sub>...mostly</sub>

The browser (javascript) and your frontend facet code (ruby) communicate by passing JSON events back and forth. Your frontend facet code communicates with your backend facet code by passing JSON events back and forth over the network.

For testing, Interfacets allows you to start your frontend and backend in the same ruby process. It provides a small "browser" helper that allows you to simulate user actions. This allows you to test the behavior of your client code as well as simulate network requests to confirm the integration between server and client.

The tests end up looking a lot like browser tests (eg, using Capybara). The key difference is that the simulated "browser" is not actually rendering your React frontend, instead it just holds the JSON events sent to it. In summary, these tests do not confirm that your facet will render correctly nor will they confirm that your javascript is all wired up correctly. On the other hand, they're simpler to write, faster to execute, and don't involve the latency/timing issues of a Capybara test.

In summary, put them somewhere in your testing pyramid, near the top I guess?

## The setup

> 🚧 🚧 🚧: Unfortunately, the setup is a bit verbose and requires you to duplicate some configuration.

```ruby
# all communications flow through a server bus

server_bus = Interfacets::Server::Bus.new(
  root_url: "http://test.host",
  asset_paths: [],
  facets: [Facets::Users::Show],
  build_dir: Rails.root.join("tmp/interfacets/build").to_s
)

# unfortunately, we currently must rebuild your router
# so that it routes through your test bus :(
router = Interfacets::Server::BasicRouter.new(
  bus: server_bus,
  paths: {
    "/ui/users" => Facets::Users::Show
  }
)

# Here we make the browser. This is too verbose
# but hey, it will get better someday, I promise.
browser = Interfacets::Test::Browser.new(
  system_json: server_bus.client_system_json,
  router: router,
  type: :inline
)
```

## A simple test

Here we'll create a user, change the name, and save it.

It's all ruby running locally, so you can debug using your normal methods.

```ruby
user = User.create!(name: "user-name")
browser.visit("/ui/users/#{user.id}")

assert_equal "hello user-name!", browser.dom.one("p").content

# Change the name
name_input = browser.one("input")
name_input.trigger("onChange", "Updated Name")
assert_equal "hello Updated Name!", browser.dom.one("p").content

# Click the save button
browser.one("Button").trigger("onClick")

# confirm persisted on the server
assert_equal "Updated Name", user.reload.name
```

## Testing Timers

Timer callbacks can be tested by manually triggering them instead of waiting for the actual timeout to occur.

First, register a timer callback in your client entity:

```ruby
client_entity do
  def setup_auto_save
    channel(:timer).callback(in_ms: 5 * 1000.0) do
      self.save
    end
  end
end
```

In your view, trigger the timer setup:

```ruby
view do |user|
  render(:dom) do |c|
    c.button("Enable auto-save", onClick: -> { user.setup_auto_save })
  end
end
```

Then in your test, you can manually trigger the timer:

```ruby
user = User.create!(name: "user-name")
browser.visit("/ui/users/#{user.id}")

# Click button to register the timer
browser.dom.one("button", content: "Enable auto-save").trigger("onClick")

# Verify a timer was registered
assert_equal 1, browser.timers.registrations.size
assert_equal 5000.0, browser.timers.first.ms

# Manually trigger the timer (instead of waiting 5 seconds)
browser.timers.first.notify

# Verify the callback executed
assert_equal true, user.reload.auto_saved
```

You can access all registered timers through `browser.timers.registrations` and trigger them individually with `.notify`. This allows you to test timer-based behavior without actually waiting for timeouts, keeping your tests fast and deterministic.

## Running tests through MRuby/WASM

MRuby is not exactly the same as CRuby (aka, MRI). Your tests will give you more confidence if the client code is interpreted by MRuby running in WASM, as it will occur on the client.

You can change your facet tests to instead run the client-side code in a separate MRuby in WASM process. To do so, simply change your browser's `type`:

```ruby
browser = Interfacets::Test::Browser.new(
  type: :mruby_wasm,
  ...
)
```

Making this change makes your tests higher-fidelity, as they more closely resemble the true environment. The downside is that debugging becomes tricky as you can only use `puts` debugging for your client code.

I suggest writing and debugging your tests using the `:inline` strategy. Once they're stable, run your tests with both runners for super-bonus gloriousness.
