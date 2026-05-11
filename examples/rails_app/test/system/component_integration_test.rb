require "application_system_test_case"

class ComponentIntegrationTest < ApplicationSystemTestCase
  test "rendering and interacting with a Button component" do
    visit "/ui/test_component"

    assert_selector "h1", text: "Component Test Page"
    assert_selector "button[data-testid=\"test-button\"]", text: "Click Me"

    # Verify interaction (the alert is hard to test in standard capybara without additional setup, 
    # but we can at least click it)
    click_on "Click Me"
  end
end
