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
          asset_paths: [],
          facets: [Facets::Users::Show],
          build_dir: Rails.root.join("tmp/interfacets/build").to_s
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
      [:inline, :nodo].each do |client_type|
        define_method("test__using_client_#{client_type}") do
          browser = Interfacets::Test::Browser.new(
            system_json: @server_bus.client_system_json,
            router: @router,
            type: client_type
          )

          # Visit the user
          browser.visit("/ui/users/#{@user.id}")

          # Check that the user ID is displayed
          assert_includes browser.dom.one("p").content, @user.id.to_s

          # Find the name input and verify it has the correct value
          name_input = browser.dom.all("input").find { |input| input.attribute("id") == "user-name" }
          assert_not_nil name_input
          assert_equal "Test User", name_input.attribute("value")

          # Change the name
          name_input.trigger("onChange", "Updated Name")

          # Verify the name was updated in the facet
          updated_name_input = browser.dom.all("input").find { |input| input.attribute("id") == "user-name" }
          assert_equal "Updated Name", updated_name_input.attribute("value")

          # Find and verify the address input
          address_input = browser.dom.all("input").find { |input| input.attribute("id") == "address-city" }
          assert_not_nil address_input
          assert_equal "Test City", address_input.attribute("value")

          # Change the address city
          address_input.trigger("onChange", "New City")

          # Verify the city was updated
          updated_address_input = browser.dom.all("input").find { |input| input.attribute("id") == "address-city" }
          assert_equal "New City", updated_address_input.attribute("value")

          # Find the save button and click it
          save_button = browser.dom.all("button").find { |btn| btn.content == "Save" }
          assert_not_nil save_button
          save_button.trigger("onClick")

          # Reload the user from database and verify changes were saved

          @user.reload
          assert_equal "Updated Name", @user.name
          assert_equal "New City", @user.address.city

          # Verify URL
          assert_equal "http://test.host/ui/users/#{@user.id}", browser.url.url
        end
      end
    end
  end
end
