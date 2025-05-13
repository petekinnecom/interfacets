**Tutorials**

- Intro
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Testing](5-testing.md)
- [Configuring](6-configuring.md)

<br/>

# Tutorial

<sub>These documents give in-depth information on how to use Interfacets. If you'd prefer, you can see a [small demo facet](../demo/README.md) just to see how it feels.</sub>

A "facet" consists of two main components: an object to render (the "entity"), and the view that renders it.

## The entity

An entity represents the state and behavior of the the facet. The entity exists on both the server and client, and defines the contract between the two. On the server, you define the entity behaviors that map attributes to your persistence layer and expose actions the client can invoke (eg, `save`, `delete`, etc). On the client, you define the behaviors required by the view for user interactions.

## Creating a Basic Facet

To create a facet, you include the `Interfacets::Server::Facet` module in a Ruby class. A facet is divided into several sections:

- **view**: Defines how the entity is rendered on the client
- **client**: Client-side behavior and computed properties
- **shared**: Attributes and methods available on both client and server
- **find**: How to load the server-side record
- **server**: Server-side behavior

Here's a simple example:

```ruby
class PersonFacet
  include Interfacets::Server::Facet

  view do |person|
    render(:dom) do |c|
      c.div do
        c.p(person.greeting)

        c.input(
          value: person.name,
          onChange: ->(value) { person.name = value}
        )
        c.button(
          "Save",
          onClick: -> { person.save }
        )
      end
    end
  end

  client do
    # Inherits all shared behavior.
    #
    # By defaults, attributes create getters/setters
    # that store values in memory
    #
    # client-specific behaviors can be added:

    def greeting
      "Hello, #{name}"
    end
  end

  shared do
    # Defines the API between client/server.

    accessor(:id, accepted_by: :client)
    accessor(:name)
    server_action(:save)
  end

  find do |id, query:|
    # How to build a facet from an ID (see "configuring")
    build(self, Person.find(id))
  end

  server do
    # Inherits all shared behavior

    # By default, attributes create getters/setters
    # that delegate to underlying record (in this
    # case the Person instance).
  end
end
```

Let's breakdown the client entity and server entity from the above example. Here's their schema:

### Client side:

Methods:

- `id`, `id=` stored in memory, from attribute in "shared" block
- `name`, `name=` stored in memory, from attribute in "shared" block
- `save`, `after_save` from server action in "shared" block
- `greeting`, from method definition in client block

These methods are all available to be used in the view. When the `save` method is invoked, the client entity will be serialized and shipped to the backend.

### Server side:

Methods:

- `id`, `id=` delegated to record, from attribute in "shared" block
- `name`, `name=` delegated to record, from attribute in "shared" block
- `save` delegated to record, from server action in "shared" block


## Handling user actions

On the client-side, all changes to the entity are triggered by an incoming event. A channel receives the event, invokes your code, and finally interfacets re-renders to all channels.

Here's how the data flows for the following button:

```ruby
view do |entity|
  render(:dom) do |c|
    c.p("you clicked: #{entity.count} times")

    c.button(onClick: -> { entity.count += 1 })
  end
end
```

1. **interfacets renders the DOM**

    The count shows 0.

2. **the user clicks the button**

    Javascript dispatches an event to Ruby. The DOM channel receives the event and invokes the lambda.

3. **the lambda is called**

    The count goes up by one

4. **interfacets re-renders**

    The dom now shows a count of 1.


## Server-Client data flow

In Interfacets, data flows in a cycle between server and client:

1. **initial request**:

    A URL request is mapped to a facet. The facet constructs an entity by loading and wrapping an an object(s) (for example, an ActiveRecord object). The entity is serialized and sent to the client.

2. **user does stuff**:

    As the user interacts with the view, the client updates the entity's state.

3. **server action triggered**:

    When a `server_action` is invoked (eg, by clicking a "save" button), the client serializes the entity and sends it to the server. The server reconstructs the entity using the submitted URL, then applies the income client-side attributes. Finally, it invokes the specified action and returns the serialized entity.

4. **client receives response**:

    The client receives the response and applies the incoming attributes to the entity.

5. **the user cries (metaphorical) tears of joy**:

    The user is happy because they filled out the form and submitted it and it was persisted. Ha ha, business!


## The entity, the view, and ~~Barbara Walters~~ you

Interfacets was primarily built to render to the DOM using React, however, there are other parts of the browser you might want to control. For example, maybe you'd like to write changes to the URL bar. Or perhaps you'd like to be able to play some audio. Maybe you'd like to record some audio (NOT WITHOUT PERMISSION OF COURSE THAT'S ILLEGAL). This can all be done with interfacts.

When you define your view, you specify which "channel" you are rendering to. Each channel has its own builder object with its own API. Each channel can invoke callbacks in your code, allowing you to update your entity's state.

---

**Tutorials**

- Intro
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Testing](5-testing.md)
- [Configuring](6-configuring.md)
