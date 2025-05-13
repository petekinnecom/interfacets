# frozen_string_literal: true

module Interfacets
module Shared
module Entities
class Bus
  InvalidAction = Class.new(StandardError)
  InvalidReceiver = Class.new(StandardError)

  # event schema:
  # {
  #   from: (role),
  #   to: (role),
  #   action:,
  #   payload: {

  #   }
  # }

  attr_reader :manifest, :entity
  def initialize(entity:)
    @manifest = entity.class.manifest
    @entity = entity
  end

  def serialize(to:, action:, nesting:)
    assert_valid_action(action:, to:, nesting:)

    {
      id: SecureRandom.uuid,
      from: entity.role,
      to: to,
      nesting:,
      action:,
      payload: {
        attributes: serialize_attributes(manifest:, entity:, to:)
      }
    }
  end

  def handle(event:)
    assert_valid_receiver(to: event.fetch("to"))
    assert_valid_action(
      action: event.fetch("action"),
      to: entity.role,
      nesting: event.fetch("nesting"),
    )

    attributes = event.fetch("payload").fetch("attributes", {})

    merge(entity:, manifest:, attributes:)

    target_entity = entity
    event.fetch("nesting")[1..-1].each do |assoc_name, id|
      break if target_entity.nil?

      spec = entity.association(assoc_name)

      target_entity =(
        if spec.type == :reference
          target_entity = spec.get
        else
          spec.get.find { _1.internal_entity_id == id }
        end
      )
    end

    raise "No EntityError" if target_entity.nil?

    target_entity
      .class
      .actions
      .fetch(event.fetch("action"))
      .dispatch(target_entity)
  end

  private

  def serialize_attributes(manifest:, entity:, to:)
    return if entity.nil?

    data = {}

    manifest
      .accessors
      .each do |name, spec|
        data[name] = entity.send(name)
      end

    manifest
      .associations
      .each do |name, spec|
        if spec.type == :reference
          data[name] = serialize_attributes(
            manifest: spec.klass,
            entity: entity.send(name),
            to:
          )
        else
          data[name] = (entity.send(name) || []).map {
            serialize_attributes(
              manifest: spec.klass,
              entity: _1,
              to:
            )
          }
        end
      end

    data
  end

  def merge(manifest:, entity:, attributes:)
    manifest
      .accessors
      .values
      .select { _1.accepted_by?(entity.role) }
      .each do |attribute|
        next unless attributes.key?(attribute.name)

        entity.send("#{attribute.name}=", attributes[attribute.name])
      end

    manifest
      .associations
      .values
      .select { _1.type == :reference }
      .select { _1.accepted_by?(entity.role) }
      .each do |association|
        next unless attributes.key?(association.name)

        value = attributes.fetch(association.name)

        if value.nil?
          entity.association(association.name).set(nil)
          next
        end

        entity
          .association(association.name)
          .get
          .then { _1 || entity.association(association.name).build }
          .tap {
            merge(
              entity: _1,
              manifest: association.klass,
              attributes: value
            )
          }
          .then { entity.association(association.name).set(_1) }
      end

    manifest
      .associations
      .values
      .select { _1.type == :collection }
      .select { _1.accepted_by?(entity.role) }
      .each do |collection|
        next unless attributes.key?(collection.name)

        identifier = collection.identifier

        incoming_coll = attributes.fetch(collection.name) || []
        existing_coll = entity.send(collection.name) || []

        items = (
          incoming_coll.map do |val|
            found_item = (
              val.fetch(identifier) &&
                existing_coll.find { _1.send(identifier) == val.fetch(identifier) }
            )

            if found_item
              found_item.tap { |r|
                merge(
                  entity: r,
                  manifest: collection.klass,
                  attributes: val
                )
              }
            else
              entity
                .association(collection.name)
                .build
                .tap { |r|
                    merge(
                      entity: r,
                      manifest: collection.klass,
                      attributes: val
                    )
                  }
            end
          end
        )
        entity.association(collection.name).set(items)
      end
  end

  def assert_valid_action(action:, to:, nesting:)
    nested_manifest = manifest
    nesting[1..-1].each do |assoc_name, _id|
      nested_manifest = manifest.associations.fetch(assoc_name).klass
    end

    unless nested_manifest.actions[action]&.accepted_by?(to.to_s)
      raise InvalidAction.new("invalid action: #{action}")
    end
  end

  def assert_valid_receiver(to:)
    if to != entity.role
      raise InvalidReceiver.new("invalid receiver role: to: #{to}, entity: #{entity.role.inspect}")
    end
  end
end
end
end
end
