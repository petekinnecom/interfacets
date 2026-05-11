# frozen_string_literal: true

require_relative "./test_helper"

module Interfacets
  class FacetContractTest < InterfacetsTest
    Person = Struct.new(:id, :name)

    class ContractTestFacet
      include Interfacets::Shared::Facet
      include Interfacets::Shared::BasicRoutable

      class << self
        attr_accessor :db
      end

      view do |person|
        render_to(:dom) do |c|
          c.h1(person.name)
          # TextField is in components.yml and requires 'label' as string
          c.TextField(
            label: person.name,
            onChange: c.f(:change, ->(v) {
              person.name = v["value"]
              ContractTestFacet.db[person.id].name = v["value"]
            })
          )

          # UnknownComponent is NOT in components.yml (for testing MissingComponentContractError)
          # We'll use a conditional to trigger this specific failure
          if person.name == "trigger_missing"
            c.UnknownComponent(foo: "bar")
          end

          # Button is in components.yml
          c.button("Click Me", onClick: ->(e) { person.name = "clicked" })

          if person.name == "trigger_event_comp"
            c.EventComponent(
              onComplexAction: { type: "click", payload: { id: "not-an-int" } }
            )
          end
        end
      end

      entity_base do
        accessor(:id, accepted_by: :client)
        accessor(:name, accepted_by: :client)
      end

      server_entity do
        find do |id, query:|
          build(self, ContractTestFacet.db.fetch(id))
        end
        role("server")
      end
    end

    def setup
      super

      @db = {
        "valid" => Person.new("valid", "Valid Label"),
        "invalid_props" => Person.new("invalid_props", 123), # name is 123, but TextField expects string
        "missing_contract" => Person.new("missing_contract", "trigger_missing"),
        "invalid_event_prop" => Person.new("invalid_event_prop", "trigger_event_comp")
      }
      ContractTestFacet.db = @db

      @server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
      )

      @router = Server::BasicRouter.new(
        bus: @server_bus,
        paths: { "/person" => ContractTestFacet }
      )

      @contract_path = "test/fixtures/components.yml"
    end

    def teardown
      super
    end

    def test_integration_valid_render
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      ui.visit("/person/valid")
      assert_equal "Valid Label", ui.dom.one("TextField").attribute("label")
    end

    def test_integration_standard_tag_without_contract_passes
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      # 'valid' person rendering should now include h1 without error
      ui.visit("/person/valid")
      assert_equal "Valid Label", ui.dom.one("h1").content
    end

    def test_integration_invalid_props_raises_error
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      # TextField requires label to be a string, but we provide 123
      error = assert_raises(Interfacets::ValidationError) do
        ui.visit("/person/invalid_props")
      end

      assert_match(/Validation failed for properties for TextField/, error.message)
      assert_match(/label/, error.message)
    end

    def test_integration_missing_contract_raises_error
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      error = assert_raises(Interfacets::MissingComponentContractError) do
        ui.visit("/person/missing_contract")
      end

      assert_match(/Missing component contract for: UnknownComponent/, error.message)
    end

    def test_integration_invalid_event_trigger_raises_error
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      ui.visit("/person/valid")
      text_field = ui.dom.one("TextField")

      # TextField onChange requires 'value' string in components.yml
      error = assert_raises(Interfacets::ValidationError) do
        text_field.trigger("onChange", { not_value: "bad" })
      end

      assert_match(/Validation failed for event 'onChange' for TextField/, error.message)
    end

    def test_integration_valid_event_trigger
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      ui.visit("/person/valid")
      text_field = ui.dom.one("TextField")

      # Should not raise.
      # Note: triggering this calls person.name = "new label" which then re-renders.
      # If we used 123 here it would fail during the re-render.
      # The InlineBus automatically flushes responses and updates the DOM.
      text_field.trigger("onChange", { value: "new label" })

      # Verify it re-rendered with new label
      # Note: text_field is now stale, we must re-fetch from ui.dom
      new_text_field = ui.dom.one("TextField")
      assert_equal "new label", new_text_field.attribute("label")
      assert_equal "new label", @db.fetch("valid").name
    end

    def test_integration_is_event_nested_schema_raises_error
      ui = Test::UiSimulator.new(
        bus: @server_bus,
        router: @router,
        type: :inline,
        contract_path: @contract_path
      )

      # EventComponent onComplexAction payload requires id as integer, but we provide "not-an-int"
      error = assert_raises(Interfacets::ValidationError) do
        ui.visit("/person/invalid_event_prop")
      end

      assert_match(/Validation failed for properties for EventComponent/, error.message)
      assert_match(/event payload validation failed/, error.message)
    end
  end
end
