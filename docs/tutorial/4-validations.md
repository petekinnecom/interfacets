**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- Validations
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)

<br/>

# Validations

> 🚧 🚧 🚧: The Validation API is akin to a basic version of ActiveModel's Validation API. I'd like to use ActiveModel::Validation directly, but it is currently incompatible with MRuby.

> 🚧 🚧 🚧: There are many currently unresolved complications with validations. This is my current area of development. The raw materials are there to for you, me, or Claude to make it work, but it's not exactly a smooth experience. But you know, [Im trying Jennifer](https://x.com/CJMcCollum/status/1029796654675841024)


Entities have basic validation functionality built in. A validation can be defined on the client, server, or shared blocks.

For example:

```ruby
view do |form|
  render_to(:dom) do |d|
    # Trigger validations before a render
    form.valid?

    if form.errors.any?
      d.p("Errors!")

      form.errors.each do |attr, message|
        d.p("error for attribute: #{attr}: #{message}")
      end
    end

    d.input(
      :name,
      onChange: ->(val) { form.name = val }
    )

    d.input(
      :tos_checkbox,
      onChange: -> { form.tos_accepted = !form.tos_accepted }
    )

    d.button(
      "save",
      onClick: -> { form.save }
    )
  end
end

client_entity do
  validate do
    unless tos_accepted?
      errors.add(:tos, "Must accept Terms of Service")
    end
  end
end

entity_base do
  validate do
    # ActiveSupport is not present in the client,
    # however, interfacets implements its `.blank?`
    # functionality because it's useful for the messy
    # world of the front-end.
    if name.blank?
      errors.add(:name, "Can't be blank")
    end
  end

  accessor(:name)
  server_action(:save)
end
```

## Validating on the client

> 🚧 🚧 🚧: I'll be implementing some built-in functionality to make desired behavior more convenient here.

In the above example, notice that we must invoke `form.valid?` before the render so that errors are present. Unfortunately, this is generally not the desired behavior on the frontend because on the initial page load, all form fields are blank, so as soon as the page loads it will complain about validation errors!

Usually to avoid this issue, forms will only validate fields that have been changed (or focused, or *unfocused*). This avoids bothering the user about fields they haven't touched yet. Once the submit button is clicked, we need to validate all fields.

Currently there is no built in methods to enable this sort of interaction, you'll need to track state manually and show/hide validations accordingly.

## Validating on the server

The server will run all validations **before** triggering the server action. If there are any errors, the server action will not be triggered. Putting your validation in the `shared` block is enough to have the validation available to your client **and** enforced on your server. Delicioso.

## Record validations

Your underlying `record` might have its own validations. How do you blend those server-side validations together with your facet's validations and present them as one set while still executing validations on the client as input changes?

GREAT QUESTION.

It's a work-in-progress...lol.

<sub>(millenial elipses followed by millenial "lol" and yes, I still sometimes put two leading spaces before a sentence. Old habits are hard to break ok?)</sub>

---

**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- Validations
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)
