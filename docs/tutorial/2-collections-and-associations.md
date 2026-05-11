**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- Collections and Associations
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)

<br/>

# Associations

It's likely that modeling your view will require nested structures. You can nest "references" (singular associations, ie "belongs_to") and "collections (set of associations, ie "has_many").

## References

In the following example, we associate a `Person` record with a single `Address` record. We will allow the user to add, remove, and edit the associated address record.

On the server, we will rely on the default behavior that is built to work seamlessly with ActiveRecord associations of the same type. For that reason, we don't need to add any behavior to the server-side.

Note: The following example only has a "city" attribute on the Address to keep things simple.

```ruby
class Person < ApplicationRecord
  # attributes :name, address_id
  belongs_to :address, optional: true
end

class Address < ApplicationRecord
  # attributes: city
end

view do |person|
  render_to(:dom) do |c|
    c.p("Hello, #{person.name}")

    if person.address
      c.div do
        c.input(
          value: person.address.city,
          onChange: ->(value) { person.address.city = value}
        )
      end

      c.button(
        "Delete Address",
        onClick: -> { person.address = nil }
      )
    else
      c.button(
        "Add Address",
        onClick: -> { person.association(:address).build }
      )
    end
  end
end

entity_base do
  accessor(:name)
  reference(:address) do
    accessor(:state)
  end
end

server_entity do
  find do |id, query:|
    build(self, Person.find(id))
  end
end
```
## Collections

Collections behave similarly to references, however, they hold an array of objects. The following example allows a user to add, edit, or remove any number of phone numbers.

On the server, we will rely on the default behavior that is built to work seamlessly with ActiveRecord associations of the same type. For that reason, we don't need to add any behavior to the server-side.

```ruby
class Person
  # attributes: name
  has_many :phone_numbers
end

class PhoneNumber
  # attributes :value
end

view do |person|
  render_to(:dom) do |c|
    c.p("Hello #{person.name}")

    person.phone_numbers.each do |phone_number|
      c.div do
        c.input(
          value: phone_number.value,
          onChange: ->(val) { phone_number.value = val }
        )
        c.button(
          "Remove Phone Number",
          onClick: -> { person.phone_numbers.delete(phone_number) }
        )
      end
    end

    c.button(
      "Add Phone Number",
      onClick: -> { person.association(:phone_numbers).build }
    )
  end
end

entity_base do
  accessor(:name)
  collection(:phone_numbers) do
    accessor(:value)
  end
end

server_entity do
  find do |id, query:|
    build(self, Person.find(id))
  end
end
```

## Reference with custom handling

If you are not using ActiveRecord (or if you are, but your entity associations don't match up to your ActiveRecord associations) you will need to implement some custom handling on the server-side to ensure that interfacets can correctly serialize attributes as well as merge incoming attributes.

The following example shows the same Address example as above, but uses `OpenStruct` instead of ActiveRecord. It also renames the association and the address's city attribute.

The same overrides are available for collections.

```ruby

entity_base do
  accessor(:name)
  reference(:address) do
    accessor(:state)
  end
end

server_entity do
  find do |id, **|
    address = OpenStruct.new(
      id:,
      name: "Pete",
      the_address: OpenStruct.new(
        the_city: "Portland"
      )
    )

    build(self, address)
  end

  alias :store :person

  reference(
    :address,
    getter: -> { person.the_address },
    setter: ->(val) { person.the_address = val },
    builder: -> { OpenStruct.new }
  ) do
    alias :store :the_address

    accessor(
      :city,
      getter: -> { the_address.the_city },
      setter: ->(val) { the_address.the_city = val }
    )
  end
end
```

## Accessing the parent entity

All associations can access their parent entity using the `parent` method.

The following example shows an address that includes the person's name:

```ruby
client_entity do
  reference(:address) do
    def name_and_state
      [
        parent.name, #=> the person's name
        state
      ].join(" - ")
    end
  end
end

entity_base do
  accessor(:name)
  reference(:address) do
    accessor(:state)
  end
end
```

## Creating or removing a reference

### Client side

To build a reference on the client, build it through its association object. For example: `entity.association(:address).build`.

To remove a reference on the client, set it to `nil`. For example: `entity.address = nil`

### Server side

In order to create and remove items from associations, we must ensure that the server can handle the incoming values. The deafult handling is built to work with ActiveRecord's API, so if an association corresponds to an ActiveRecord `belongs_to` or `has_many` you can rely on the default behavior.

For an association, you can pass a custom `getter`, `setter`, and `builder` callable.

- The `getter`: loads the associated value
- The `builder`: if needed, invoked to construct a new association object
- The `setter`: invoked with the existing or newly built record

In order to understand the builder, consider the following scenarios for the `address` reference from the prior examples:

```ruby
server_entity do
  reference(
    :address,
    identifier: :id,
    getter: -> { record.address },
    builder: -> { Address.new }, # or: record.build_address
    setter: ->(val) { record.address = val}
  )
end
```

### Attribute handling examples

#### Server value: `nil`, incoming attributes: `{ id: nil, state: "OR" }`

Interfacets invokes the `getter` which returns `nil`. Interfacets cannot apply the incoming attributes to `nil`. For that reason, it invokes the `builder` which returns an `Address` object. It then applies the attributes to the built `Address` object by invoking setters for each attribute. Finally it invokes the setter to apply it to the parent record.

#### Server value: Address(id: 12), incoming attributes: `{ id: 12, state: "OR" }`

Interfacets invokes the `getter` which returns an Address object with id of 12. Interfacets checks the identifier (`id`) against the incoming attributes. Since they are the same, it simply invokes the relevant setters on the object. The `builder` and `setter` are not invoked.

#### Server value: Address(id: 12), incoming attributes: `{ id: 99, state: "OR" }`

Interfacets invokes the `getter` which returns an Address object with id of 12. Interfacets checks the `id` against the incoming attributes. Since they are the different, it invokes the `builder`, then `setter`, then finally applies the attributes.

#### Server value: Address(id: 12), incoming attributes: `nil`

Interfacets invokes the `setter` and passes it `nil`.

## Creating or removing an item from a collection

The concepts are an extension of the ones explained in the "reference" section.

### Client side

To build a reference on the client, build it through its association object. For example: `entity.association(:phone_numbers).build`.

To remove a reference on the client, remove it from the array. For example, `entity.phone_numbers.delete(phone_number)`. (**Note:** this behavior may not always be desired, see a later section for more discussion.)

### Server side

The server handles incoming attributes for collections in the same way it does for references. It uses the identifier to correlate existing objects, builds if needed, then applies the incoming attributes. Lastly, it invokes the setter.

#### Deletion complexities

Consider the following sequence of events:

1. Alice loads the facet for Person(id: 1). The person currently has two phone_numbers.
2. Bob loads the facet for Person(id: 1). He adds a phone_number.
3. Bob saves the facet. The Person(id: 1) now has three phone_numbers on the server.
4. Alices edits the Person's name and clicks save.

On step 4, the incoming attributes only have **two** phone_number records. Should the third phone number (just added by Bob) be deleted or left alone?

The answer depends on your application. The default `setter` value for Interfacets collection will remove the third phone_number from the array (and potentially trigger the ActiveRecord `:autodestroy` behavior).

If the oppose is desired behavior, that is, if the desired behavior that records are only destroyed when they are explicitly destroyed on the client, we must add a bit of machinery. To do this, we can use ActiveRecord's `mark_for_destruction` (or build similar machinery if not using ActiveRecord).

```ruby

view do |person|
  person.phone_numbers.each do |phone_number|
    next if phone_number.marked_for_destruction

    ...
  end
end

client_entity do
  def remove_phone_number(phone_number)
    phone_number.marked_for_destruction = true
  end
end

entity_base do
  collection(:phone_numbers) do
    accessor(:marked_for_destruction)
  end
end

server_entity do
  collection(
    :phone_numbers,
    builder: -> { record.association(:phone_numbers).build }

    # The setter can be a noop:
    #   The builder ensures new records are added to the collection
    #   `mark_for_destruction!` ensures records are destroyed
    #   Records not in the incoming attributes are left as-is
    setter: ->(coll) {}
  ) do
    def marked_for_destruction=(val)
      record.mark_for_destruction! if val
    end
  end
end

```

---

**Tutorials**

- [Intro](0-intro.md)
- [Rendering](1-rendering.md)
- Collections and Associations
- [Server Actions](3-server-actions.md)
- [Validations](4-validations.md)
- [Mounting](5-mounting.md)
- [Testing](6-testing.md)
- [Configuring](7-configuring.md)
