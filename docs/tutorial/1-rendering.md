**Tutorials**

- [Intro](0-intro.md)
- Rendering
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)

<br/>

# Rendering

The entity can be rendered to various "channels." Channels are stateful connections between ruby and javascript that communicate via JSON under-the-hood. Each channel provides a builder API for you to use within your facet.

# The DOM channel

This channel allows you to to render React components. It yields a builder object. Methods invoked on the builder are the names of React components.

## Rendering elements

A component that accepts children can be passed a block.

Strings can be attached to the DOM in two ways:
- by invoking `c.string("the string")`
- if the component has one child that is a string, it can be passed as the first positional parameter: `c.p("the string")`

```ruby
view do |entity|
  render_to(:dom) do |c|
    c.div do
      c.string("Here's a string in a div")
    end

    c.p("this string is in a p")
  end
end
```

### Custom React components

In order to render a custom react component, you must pass it to Interfacets' registry in your javascript configuration:

```javascript
import { MyComponent1 } from "some-awesome-library"
import { MyComponent2 } from "some-average-library"
import { MyComponent3 } from "some-excellent-library"

initBus({
  ...
  channels: {
    dom: {
      receive: reactHandler({
        bus: "default",
        registry: {
          MyComponent1,
          MyComponent2,
          CustomComponentName: MyComponent3
        },
      })
    },
    ...
  }
})
```

The above configuration will make those components available to you in ruby:

```ruby
view do |entity|
  render_to(:dom) do |c|
    c.MyComponent1 do
      c.string("Here's a string in a div")
    end

    c.MyComponent2(onChange: -> { puts "blah"})

    c.CustomComponentName(excellent: true)
  end
end
```

### Component Registry & Validation (`components.yml`)

While you can manually register components in your JavaScript configuration, Interfacets provides a "contract-first" approach using a `config/interfacets/components.yml` file. This file acts as a central source of truth for your component interfaces.

#### Defining the Contract

Each component is defined with its contract, which includes expected `props` (which can be either data props or event handlers). You can also provide metadata for JavaScript generation.

Props and events are defined in a single, consolidated `props` object.

```yaml
# config/interfacets/components.yml
TextField:
  js:
    path: "./components/inputs/TextField"
    default: true
  props:
    label:
      type: string
    value:
      type: string
    onChange:
      type: event
      is_event: true
      payload:
        type: object
        required: [value]
        properties:
          value: { type: string }
```

#### Event Validation

You can specify that a component prop is an event callback by adding `is_event: true` to its definition. You can also provide a `payload` schema to validate the data passed to the event.

```yaml
# components.yml
MyComponent:
  props:
    onAction:
      is_event: true
      payload:
        type: object
        required: [id]
        properties:
          id: { type: integer }
```

#### Declarative Event Transformations

When using JavaScript components, you often need to map complex browser events (like DOM `onChange`) to simple serializable hashes. You can do this declaratively in `components.yml` by adding a `transform` key to an event prop.

```yaml
# components.yml
MyInput:
  js: { path: "./MyInput", default: true }
  props:
    onChange:
      is_event: true
      transform:
        value: [0, "target", "value"]
```

The transformation path is an array where the first element is the argument index, and subsequent elements are property names to traverse. In the example above, it extracts `arguments[0].target.value` and maps it to the `value` key in the event payload.

#### Automated Registry Generation

Instead of manually importing every component in your `initBus` call, you can generate a `registry.js` file from your YAML manifest.

```ruby
# In a Rake task or initialization script
registry = Interfacets::ComponentRegistry.new(config_path: "config/interfacets/components.yml")
registry.write_client_registry(path: "app/javascript/interfacets/registry.js")
```

In a Rails application, you can automate this with a Rake task and ensure it runs before your JavaScript build:

```ruby
# lib/tasks/interfacets.rake
namespace :interfacets do
  desc "Synchronize component registry"
  task :sync => :environment do
    require "interfacets/component_registry"
    registry = Interfacets::ComponentRegistry.new(
      config_path: Rails.root.join("config/components.yml")
    )
    registry.write_client_registry(
      path: Rails.root.join("app/javascript/interfacets/registry.js")
    )
    puts "Interfacets registry synchronized"
  end
end

# Ensure interfacets:sync runs before javascript:build
if Rake::Task.task_defined?("javascript:build")
  Rake::Task["javascript:build"].enhance(["interfacets:sync"])
end
```

The generated file will contain the necessary ES6 imports and a mapping that can be imported directly into your JavaScript setup.

#### Schema Validation in Tests

One of the most powerful features of `components.yml` is automatic contract enforcement during tests. When you render a component in a Ruby test, Interfacets will:

1.  **Verify the component exists**:
    - For **custom components**, if it's rendered but not defined in `components.yml`, it will raise a `MissingComponentContractError`.
    - For **standard HTML/SVG components** (e.g., `div`, `button`, `svg`), this check is optional. You can use them without a contract.
2.  **Validate Props**:
    - For **custom components**, a `props` schema is mandatory. Missing schemas will raise a `ValidationError`.
    - For **standard components**, validation only occurs if a `props` schema is explicitly provided in `components.yml`.
3.  **Validate Event Payloads**:
    - Similar to props, events for custom components must have a schema, while standard components only validate if a schema is defined.

This ensures that your Ruby code always sends data that your React components expect, and vice-versa, while allowing you to use standard web primitives with zero configuration.

## Callbacks

If a prop's value is a lambda, it will be converted to a function before being passed to the react component. The arguments to the lambda are controlled by the component.

The native HTML components invoked callbacks with event objects. Interfacets overrides this behavior for a subset of components. (🚧 🚧 🚧: specify components and their behaviors)

For example:

```ruby
view do |person|
  render_to(:dom) do |c|
    c.MyCustomComponent(
      onChange: ->(new_value) { person.thing = new_value },
      onCancel: -> { puts "Canceled!" }
    )
  end
end
```

## Memoization

> 🚧 🚧 🚧: Memoization is somewhat painful now and could use some love. I'm working on it... See my current suggestion below the example

Interfacets rerenders all channels after it handles any event. The DOM builder provides a method to invoke [React memo](https://react.dev/reference/react/memo) to avoid slow redraws.

Interfacets memoization requires a globally unique identifier and a value. The identifier should be the same across renders. The value will be used to determine whether the memoized component can be rendered.

The positional args will be joined to form the unique identifier. The `on` can be a string or array of memoization values.

```ruby
view do |entity|
  render_to(:dom) do |c|
    c.memo(:header, on: "static") do
      c.h1("the header")
    end

    entity.people.each do |person|
      c.memo(
        :name, person.id, # static memoization key
        on: [person.name, person.age] # memoization values
      ) do
        c.p(person.name)
        c.p(person.age)
      end
    end

  end
end
```

> 🚧 🚧 🚧: Simple way to deal with some of the memoization pain:

On small enough pages, just using uncontrolled components and avoiding memoization is usually performant enough.

On larger pages, if you are rendering a collection of items or a set of nested components, you can memoize large swaths of the page by doing something like: `c.memo(:person, person.id, on: person.attributes)`.

## Capturing elements

Some React components accept elements as props. In order to pass an element to a prop, you must "capture" it.

For example:

```ruby
view do |entity|
  render_to(:dom) do |c|
    c.MyLayoutComponent(
      header: c.capture { c.p("The header") },
      body: c.capture { c.p("The body") },
      footer: c.capture { c.p("The footer") },
    )
  end
end
```

## The URL channel

This channel allows you to update the URL in the location bar as well as redirect the user.

This channel can be invoked both in the "view" block but also as part of a call back or "after" action.

For example:

```ruby
view do |entity|
  render_to(:url) do |c|
    c.path("/people/#{entity.uuid}")
  end

  render_to(:dom) do |c|
    c.button(
      "Back to dashboard",

      # Redirect will be a full page reload
      onClick: -> { channel(:url).redirect("/dashboard")}
    )
  end
end

client_entity do
  def after_save
    channel(:url).redirect("/people/list")
  end
end
```

## The API channel

> 🚧 🚧 🚧: This channel will likely be removed in favor of the URL channel

This channel is used under-the-hood by server actions. However, it has one other method that is currently useful.

The "render" method will make an API request to fetch a new facet without a full page-load.

For example:

```ruby
view do |entity|
  render_to(:dom) do |c|
    c.button(
      "view person 17",
      onClick: -> {
        channel("interfacets:api").render("/people/17")
      }
    )
  end
end

```

## Other channels

There are some other channels in there, including a way to control the Audio engine. Poke around the code to see them or contact me for help.

---

**Tutorials**

- [Intro](0-intro.md)
- Rendering
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)
