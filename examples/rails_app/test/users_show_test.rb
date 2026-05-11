require "test_helper"

module Facets
  module Users
    class ShowInlineTest < ActiveSupport::TestCase
      def setup
        @user = User.create!(name: "Test User")
        @user.create_address(city: "Test City")
        @user.phone_numbers.create!(value: "555-1234")

        @server_bus = Interfacets::Server::Bus.new(
          root_url: "http://test.host",
          asset_paths: [
            "app/interfacets/facets/application_facet.rb",
            "app/interfacets/facets/users/show.rb",
          ],
        )

        @router = Interfacets::Server::BasicRouter.new(
          bus: @server_bus,
          paths: {
            "/ui/users" => Facets::Users::Show
          }
        )
      end

      # Test with both client types: :inline uses Ruby's Interfacets client directly,
      # :nodo runs JavaScript via Node.js runtime to test real browser-like behavior
      [:nodo].each do |client_type|
        define_method("test__using_client_#{client_type}") do
          ui = Interfacets::Test::UiSimulator.new(
            bus: @server_bus,
            router: @router,
            type: client_type,
            contract_path: Rails.root.join("config/components.yml").to_s,
            validation: :strict
          )

          # Visit the user
          ui.visit("/ui/users/#{@user.id}")

          # Check that the user ID is displayed
          assert_includes ui.dom.one("p").content, @user.id.to_s

          # Find the name input and verify it has the correct value
          name_input = ui.dom.all("input").find { |input| input.attribute("id") == "user-name" }
          assert_not_nil name_input
          assert_equal "Test User", name_input.attribute("value")

          # Change the name
          name_input.trigger("onChange", "Updated Name")

          # Verify the name was updated in the facet
          updated_name_input = ui.dom.all("input").find { |input| input.attribute("id") == "user-name" }
          assert_equal "Updated Name", updated_name_input.attribute("value")

          # Find the bio textarea and verify initial value (nil)
          bio_textarea = ui.dom.one("textarea")
          assert_not_nil bio_textarea

          # Change the bio (this uses the transform defined in components.yml)
          bio_textarea.trigger("onChange", { "value" => "This is my new bio." })

          # Find and verify the address input
          address_input = ui.dom.all("input").find { |input| input.attribute("id") == "address-city" }
          assert_not_nil address_input
          assert_equal "Test City", address_input.attribute("value")

          # Change the address city
          address_input.trigger("onChange", "New City")

          # Verify the city was updated
          updated_address_input = ui.dom.all("input").find { |input| input.attribute("id") == "address-city" }
          assert_equal "New City", updated_address_input.attribute("value")

          # Find the save button (Custom component 'Button') and click it
          save_button = ui.dom.one("Button")
          assert_not_nil save_button
          assert_equal "Save", save_button.attribute("label")
          save_button.trigger("onClick", {})

          # Reload the user from database and verify changes were saved
          @user.reload
          assert_equal "Updated Name", @user.name
          assert_equal "New City", @user.address.city
          assert_equal "This is my new bio.", @user.bio

          # Verify URL
          assert_equal "http://test.host/ui/users/#{@user.id}", ui.url.url
        end
      end
    end
  end
end
