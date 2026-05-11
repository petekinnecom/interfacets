**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- Mounting
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)

<br/>

# Mounting (Facet Composition)

Facets are most powerful when they are composed. This allows you to build complex, stateful UIs from smaller, reusable parts.

## The Scenario: From Page to Component

Imagine we have a `Facets::Person::ShowPage`. It’s a routable facet that renders a user's profile, including the site navigation, a sidebar, and the profile details.

```ruby
module Facets::Person::ShowPage
  include Interfacets::Shared::Facet
  include Interfacets::Shared::BasicRoutable

  view do |page|
    render_to(:dom) do |c|
      c.div(class: "app-layout") do
        c.nav("Home | Search | Logout") # Site Chrome
        c.div(class: "profile-details") do
          c.h1(page.name)
          c.div(page.bio)
        end
      end
    end
  end
end
```

Now, we want to add a `Facets::Person::ListPage`. We want to show a grid of these same person profiles.

### The Issue: View Duplication

If we just copy the rendering logic into the list, we’ve duplicated code. But more importantly, we can't just `mount` the `ShowPage` inside our list, because the `ShowPage` includes the "App Layout" (navigation, etc.). We don't want 20 navigation bars inside our grid!

## The Solution: Extraction

To solve this, we extract the core profile UI into a reusable component: `Facets::Person`.

```ruby
module Facets::Person
  include Interfacets::Shared::Facet

  view do |person|
    render_to(:dom) do |c|
      c.div(class: "person-card") do
        c.h1(person.name)
        c.div(person.bio)
      end
    end
  end
end
```

Now, our `ListPage` can mount this as a **collection**:

```ruby
module Facets::Person::ListPage
  include Interfacets::Shared::Facet
  include Interfacets::Shared::BasicRoutable

  mount(Facets::Person, as: :persons, type: :collection)

  view do |list|
    render_to(:dom) do |c|
      c.div(class: "grid") do
        list.persons.each { |p| render(p) }
      end
    end
  end
end
```

And our `ShowPage` can mount it as a **reference**:

```ruby
module Facets::Person::ShowPage
  include Interfacets::Shared::Facet
  include Interfacets::Shared::BasicRoutable

  mount(Facets::Person, as: :person, type: :reference)

  view do |page|
    render_to(:dom) do |c|
      c.div(class: "app-layout") do
        c.nav("...")
        render(page.person) # Reuse the card UI!
      end
    end
  end
end
```

## Stateful Layouts

As your app grows, even the "App Layout" (navigation, sidebar) usually needs to be its own stateful facet. For example, the sidebar might need to show the `current_user`'s notifications or avatar.

Instead of duplicating the layout logic in every "Page" facet, we can use **Nested Mounting**.

### Final Example: Nested Mounts

First, we define our stateful `AppLayout`. Notice that it doesn't know what its `content` is; it just knows it has some.

```ruby
module Facets::AppLayout
  include Interfacets::Shared::Facet

  # We don't mount anything here yet! 
  # The Page facet will "inject" the content via a block.

  view do |layout|
    render_to(:dom) do |c|
      c.div(class: "app-frame") do
        c.nav("...") # Stateful chrome here
        c.main do
          # This renders whatever was mounted as 'content'
          render(layout.content) 
        end
      end
    end
  end
end
```

Now, the `ShowPage` mounts this layout and **dynamically injects** the `Person` facet into the layout's "content" slot using a block.

```ruby
module Facets::Person::ShowPage
  include Interfacets::Shared::Facet
  include Interfacets::Shared::BasicRoutable

  # 1. Mount the Layout, and inject the Person component into it!
  mount(Facets::AppLayout, as: :layout, type: :reference) do
    mount(Facets::Person, as: :content, type: :reference)
  end

  view do |page|
    render_to(:dom) { |c| render(page.layout) }
  end

  server_entity do
    find do |id, query:|
      person = Person.find(id)
      
      # 2. Pass the data through the nesting using a hash
      build(self, layout: { content: person })
    end
  end
end
```

### How it Works

1.  **Polymorphic Composition**: The `AppLayout` doesn't need to know it's rendering a person. It just renders `layout.content`. The `ShowPage` dictates what "content" means in this specific context.
2.  **Automatic Channel Selection**: When you call `render(page.layout)`, Interfacets automatically renders the layout's view. When the layout calls `render(layout.content)`, Interfacets automatically renders the `Person` view.
3.  **Data Flow**: Using `build(self, layout: { content: person })` allows you to initialize the entire tree in one go. The framework recursively builds the nested entities based on your mount structure.

---

**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- [Collections and Associations](2-collections-and-associations.md)
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- Mounting
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)
