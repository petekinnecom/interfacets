**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- Server Actions
- [Validations](4-validations.md)
- [Testing](5-testing.md)
- [Configuring](6-configuring.md)

<br/>

# Server Actions

Server actions are methods available to the client that send an API request to your server. The data flows like so:

- client: action invoked
- client: serializes entity
- client: sends API request
- server: receives API request
- server: maps URL to facet
- server: loads entity
- server: applies incoming attributes to entity
- server: invokes designated method
- server: serializes entity
- server: responds with serialized attributes
- client: applies incoming attributes to entity
- client: triggers "after" action

The nice thing about Interfacets is that it handles this all for you. Your entity definition includes all the getters and setters necessary to make this happen.

## "After" actions

An after action is run when the client receives the API response. You can optionally define them. You might use them to track when a request is outstanding and put up a spinner or disable input buttons. For example:

```ruby
view do |entity|
  render(:dom) do |c|
    c.Spinner if entity.saving

    c.button(
      disabled: entity.saving,
      onClick: -> {
        entity.saving = true
        entity.save
      }
    )
  end
end

client_entity do
  attr_accessor :saving

  def after_save
    self.saving = false
  end
end

entity_base do
  server_action(:save)
end
```
## Returning data from an action

Server actions cannot "return" any data beyond the entity itself. This means that any data you want to communicate to the frontend must be an attribute of the entity.

Let's suppose when a record (eg, a `Person` record) is saved, we'd like to report the total number of records of that type (eg, `Person.count`). Importantly, we must compute this value on the server. In that case, we must make it an attribute. We might need some more attributes to support the view in deciding when to show that information or not.

In the following example, we only show the `Person.count` message after a save:

```ruby
view do |entity|
  render(:dom) do |c|
    c.p(person_count_message) if person_count_message

    c.button(onClick: -> { person.save })
  end
end

client_entity do
  def person_count_message
    if @show_person_count
      "There are #{person_count} Person records"
    end
  end

  def after_save
    @show_person_count = true
  end
end

entity_base do
  accessor(:person_count, accepted_by: :client)
  server_action(:save)
end

server_entity do
  def person_count
    Person.count
  end

  def save
    logger.info("Save invoked")
  end
end
```

## Checking the HTTP Response Code

You can't, but also you probably shouldn't need to. Interfacets is in the business of passing back and forth ruby objects that represent the state of the interaction. Instead of using an HTTP status code to determine aspects of your view, use an attribute. (Under the hood, interfacets will try use appropriate HTTP methods and response codes, cause, you know, it is our duty as netizens.)

For example, if you want to indicate that a "save" action was unsuccessful due to a validation failure, you could set a flash message from the server:

```ruby
view do |entity|
  render(:dom) do |c|
    c.p(entity.flash_message) if entity.flash_message
    c.button(onClick: -> { entity.save })
  end
end

entity_base do
  accessor(:flash_message, accepted_by: :client)
  server_action(:save)
end

server_entity do
  def flash_message
    @flash_message
  end

  def save
    if record.valid?
      record.save
      @flash_message = "Saved!"
    else
      @flash_message = "Not saved: invalid"
    end
  end
end
```

## Overriding action method on the client

You cannot use `super` to invoke an action. Instead you must manually submit by invoking the action on the underlying store.

For example:

```ruby
client_entity do
  def save
    @saving = true
    store.save
  end
end

entity_base do
  server_action(:save)
end
```

---

**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- Server Actions
- [Validations](4-validations.md)
- [Testing](5-testing.md)
- [Configuring](6-configuring.md)
