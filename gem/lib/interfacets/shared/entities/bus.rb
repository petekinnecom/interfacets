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
    action = event.fetch("action")

    assert_valid_receiver(to: event.fetch("to"))
    assert_valid_action(
      action:,
      to: entity.role,
      nesting: event.fetch("nesting"),
    )

    attributes = event.fetch("payload").fetch("attributes", {})

    merge(entity:, manifest:, attributes:, action:)

    target_entity = entity.entity_at(event.fetch("nesting"))

    target_entity
      &.class
      &.actions
      &.fetch(event.fetch("action"))
      &.dispatch(target_entity)
  end

  private

  def serialize_attributes(manifest:, entity:, to:)
    return if entity.nil?

    data = {}

    data[:errors] = entity.errors.to_h if entity.respond_to?(:errors)

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

  def merge(manifest:, entity:, attributes:, action:)
    if (errs = attributes[:errors] || attributes["errors"])
      entity.errors.clear if entity.errors.respond_to?(:clear)
      errs.each do |k, vs|
        Array(vs).each { |v| entity.errors.add(k.to_sym, v) }
      end
    end

    manifest
      .accessors
      .values
      .select { _1.accepted_by?(entity.role) }
      .each do |attribute|
        next unless attributes.key?(attribute.name)

        attr_mergers = (
          entity.class.mergers[attribute.name]
        )

        merger = (
          if attr_mergers.key?(action)
            attr_mergers.fetch(action)
          else
            attr_mergers.fetch(:default)
          end
        )

        merger.call(entity, attributes[attribute.name])
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
          .tap { |nested_entity|
            merge(
              entity: nested_entity,
              manifest: association.klass,
              attributes: value,
              action:
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
                  attributes: val,
                  action:
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
                      attributes: val,
                      action:
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
