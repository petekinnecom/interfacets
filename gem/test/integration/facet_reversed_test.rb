# frozen_string_literal: true

require_relative "../test_helper"

module Interfacets
  class FacetReversedTest < InterfacetsTest

    User = Struct.new(:id, :name, :email, :saved, :profile)
    Profile = Struct.new(:bio)

    class ReverseTestFacet
      include Interfacets::Shared::Facet
      include Interfacets::Shared::BasicRoutable

      class << self
        attr_accessor :db
      end

      # 1. View defined first
      view do |user|
        render_to(:dom) do |c|
          c.div(id: "user-name") do
            c.str(user.name)
          end

          c.div(id: "user-bio") do
            c.str(user.profile.bio)
          end

          c.button("save", onClick: -> { user.save })
          c.button("update_bio", onClick: -> { user.profile.bio = "New Bio" })

          if user.errors[:email].any?
            c.span(id: "email-error") do
              c.str(user.errors[:email].join(", "))
            end
          end
        end

        render_to(:url) do |c|
          c.path(user.api_path)
        end
      end

      # 2. Client entity defined second
      client_entity do
        role("client")

        # Test that we can define methods here that use accessors from entity_base (defined later)
        def shout_name
          self.name.upcase + "!"
        end
      end

      # 3. Server entity defined third
      server_entity do
        find do |id, query:|
          build(self, ReverseTestFacet.db.fetch(id))
        end

        role("server")

        def save
          validate
          if valid?
            store.saved = true
          end
        end
      end

      # 4. Entity base defined LAST
      entity_base do
        accessor(:id)
        accessor(:name)
        accessor(:email)

        reference(:profile, getter: -> { record.profile }) do
          accessor(:bio)
        end

        server_action(:save)

        validate do
          errors.add(:email, "must be valid") if email && !email.include?("@")
        end
      end
    end

    def setup
      super
      @db = {
        "1" => User.new("1", "Alice", "alice@example.com", false, Profile.new("Initial Bio"))
      }
      ReverseTestFacet.db = @db
    end

    def test_reversed_dsl_order
      server_bus = Server::Bus.new(
        root_url: "root_url",
        asset_paths: [],
      )

      router = Server::BasicRouter.new(
        bus: server_bus,
        paths: {
          "/user" => ReverseTestFacet
        }
      )

      ui = Test::UiSimulator.new(
        bus: server_bus,
        router: router,
        type: :inline,
      )

      ui.visit("/user/1")

      # Verify initial state
      assert_equal "Alice", ui.dom.one("#user-name").content
      assert_equal "Initial Bio", ui.dom.one("#user-bio").content

      # Test validation (email is valid)
      ui.dom.one("button", content: "save").trigger("onClick")
      assert @db.fetch("1").saved

      # Test association update from client
      ui.dom.one("button", content: "update_bio").trigger("onClick")
      ui.dom.one("button", content: "save").trigger("onClick")
      assert_equal "New Bio", ui.dom.one("#user-bio").content
      assert_equal "New Bio", @db.fetch("1").profile.bio

      # Test invalid state
      user = @db.fetch("1")
      user.email = "invalid-email"
      user.saved = false

      # Re-visit to refresh the UI with the new data
      ui.visit("/user/1")
      ui.dom.one("button", content: "save").trigger("onClick")

      # Should NOT be saved because of validation
      refute @db.fetch("1").saved

      # Verify error is rendered
      assert_equal "must be valid", ui.dom.one("#email-error").content
    end

    def test_inheritance_reversed
      # This confirms that even if defined last, the inheritance is set up correctly
      assert ReverseTestFacet.server_entity_class < ReverseTestFacet.entity_base_class
      assert ReverseTestFacet.entity_base_class < Shared::Entity

      assert ReverseTestFacet.server_entity_class.accessors.key?("name")
      assert ReverseTestFacet.server_entity_class.actions.key?("save")
      assert ReverseTestFacet.server_entity_class.associations.key?("profile")
    end
  end
end
