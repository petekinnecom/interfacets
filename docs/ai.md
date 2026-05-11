# Interfacets: AI Agent Reference Guide

This document is a terse reference for AI agents working with the Interfacets Ruby framework. Interfacets builds full-stack reactive UIs by communicating state changes via JSON between a Ruby backend and a React/JS frontend (which often runs Ruby via MRuby/WASM).

**Note:** Configuration steps are intentionally omitted. Assume Interfacets is fully configured in the working environment. For configuration details, see `docs/tutorial/7-configuring.md`.

---

## 1. Core Facet Structure

A "facet" encapsulates an entity (state/behavior) and a view (rendering). It spans client (frontend Ruby), server (backend Ruby), and shared contexts.

```ruby
class MyFacet
  include Interfacets::Shared::Facet
  include Interfacets::Shared::BasicRoutable

  view do |entity|
    render_to(:dom) do |c|
      c.div do
        c.h1(entity.greeting)
        c.input(value: entity.name, onChange: ->(val) { entity.name = val })
        c.button("Save", onClick: -> { entity.save })
      end
    end
  end

  client_entity do
    def greeting; "Hello, #{name}!"; end
    def after_save; @saved = true; end
  end

  entity_base do
    accessor(:id, accepted_by: :client)
    accessor(:name)
    server_action(:save)
  end

  server_entity do
    find { |id, query:| build(self, User.find(id)) }
  end
end
```
*Reference:* `docs/tutorial/0-intro.md`

---

## 2. Component Contracts (`components.yml`)

The `config/interfacets/components.yml` file defines the central contract for React components. It describes expected `props` and `events`.

**Purpose:** 
- Validates data passed from Ruby to React (during testing).
- Enforces event payload structures.
- Generates the JavaScript registry (ES6 imports) automatically.
- Maps complex browser events (like DOM `onChange`) to simple serializable hashes using declarative transformations.

**Structure Snippet:**
```yaml
TextField:
  js: { path: "./components/TextField", default: true }
  props:
    label: { type: string }
    onChange:
      is_event: true
      transform:
        value: [0, "target", "value"] # Extrapolates args[0].target.value to { value: ... }
      payload:
        type: object
        required: [value]
        properties:
          value: { type: string }
```
*Reference:* `docs/tutorial/1-rendering.md`

---

## 3. Rendering & Channels

Facets render to stateful channels.
- **DOM Channel (`:dom`)**: Renders React components. `c.Component(prop: value)`. Pass children via blocks or `c.capture { ... }`. Positional string arg sets the first child string: `c.p("string")`.
- **URL Channel (`:url`)**: Modifies URL/triggers redirects. `c.path("/new")` or `channel(:url).redirect("/other")` in callbacks.
- **Memoization**: Avoid slow redraws using React memo semantics.
```ruby
render_to(:dom) do |c|
  c.memo(:header, on: "static_key") { c.h1("Title") }
  c.memo(:item, item.id, on: [item.name, item.val]) { c.p(item.name) }
end
```
*Reference:* `docs/tutorial/1-rendering.md`

---

## 4. Collections and Associations

Nest child entities within a parent entity. Seamless default behavior for ActiveRecord `belongs_to` and `has_many`.

```ruby
entity_base do
  reference(:address) { accessor(:state) }     # Belongs To / Has One
  collection(:phone_numbers) { accessor(:val) } # Has Many
end
```

**Client Manipulation:**
```ruby
# Add / Remove Reference
entity.association(:address).build
entity.address = nil 

# Add / Remove Collection Item
entity.association(:phone_numbers).build
entity.phone_numbers.delete(phone_number) 
```

**Server Deletion Handling (Custom `setter` example):**
By default, deleting from an array in the client will remove it on the server. If `mark_for_destruction` is required instead:
```ruby
server_entity do
  collection(:phone_numbers, builder: -> { record.association(:phone_numbers).build }, setter: ->(c) {}) do
    def marked_for_destruction=(val)
      record.mark_for_destruction! if val
    end
  end
end
```
*Reference:* `docs/tutorial/2-collections-and-associations.md`

---

## 5. Server Actions

`server_action` methods invoke API calls behind the scenes.

**Flow:** Action triggered on client -> state serialized -> sent to server -> server applies state -> invokes action -> serializes response -> client state updated -> client triggers `after_<action>`.

**Returning Data:** Server actions cannot return data directly; any data meant for the UI must be mutated on entity attributes.
```ruby
entity_base do
  server_action(:save)
  accessor(:flash_msg, accepted_by: :client) 
end

server_entity do
  def save
    record.save
    @flash_msg = "Success!"
  end
end
```
*Reference:* `docs/tutorial/3-server-actions.md`

---

## 6. Validations

Validation definitions exist in the entity. Define them in `entity_base` for shared validation. Server automatically validates before triggering `server_action`.

```ruby
entity_base do
  validate do
    errors.add(:name, "Can't be blank") if name.blank?
  end
end
```
*Note:* Frontend does not auto-validate. The `entity.valid?` method must be explicitly called before/during render if desired on the client.
*Reference:* `docs/tutorial/4-validations.md`

---

## 7. Mounting (Facet Composition)

Facets can be extracted into separate, reusable modules and combined (mounted) via `type: :collection` or `type: :reference`.

**Mounting and Injection:**
```ruby
# ShowPage facet mounts a layout facet and injects a Person facet into it
mount(Facets::AppLayout, as: :layout, type: :reference) do
  mount(Facets::Person, as: :content, type: :reference)
end

view do |page|
  render_to(:dom) { |c| render(page.layout) }
end

server_entity do
  find do |id, **|
    # Server initializes the nested tree structure
    build(self, layout: { content: Person.find(id) })
  end
end
```
*Reference:* `docs/tutorial/5-mounting.md`

---

## 8. Testing

Tests run server and client Ruby code sequentially within the same test process. **Crucially, testing does NOT use a real browser, Capybara, or Selenium.** The test "browser" interacts with JSON events without a real DOM, ensuring high performance. Because there is no real browser, **there is no network latency, no page refreshing, and no asynchronous rendering delays**. Events and assertions happen instantly and synchronously.

```ruby
# Assuming 'browser' (Interfacets::Test::UiSimulator) is setup
user = User.create!(name: "Pete")
browser.visit("/ui/users/#{user.id}")

# Simulate User Events
browser.dom.one("input").trigger("onChange", "Updated Name")
browser.dom.one("Button", content: "Save").trigger("onClick")

# Assert Backend State
assert_equal "Updated Name", user.reload.name

# Test Timers
browser.timers.first.notify # Execute a timer without waiting
```

**Contract Validation in Tests:**
If initialized with `contract_path: "config/interfacets/components.yml"`, `Interfacets::Test::UiSimulator` automatically asserts props and events conform to schemas, raising `Interfacets::ValidationError` or `Interfacets::MissingComponentContractError` upon violation.

*Reference:* `docs/tutorial/6-testing.md`
