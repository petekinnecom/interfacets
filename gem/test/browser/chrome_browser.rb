# frozen_string_literal: true

# require "capybara"
# require "selenium-webdriver"

# Capybara.register_driver :budget_chrome do |app|
#   options = Selenium::WebDriver::Chrome::Options.new(options: {"excludeSwitches" => ["enable-automation"]})
#   options.add_argument("--user-data-dir=#{File.expand_path("./chromedata")}")
#   Capybara::Selenium::Driver.new(app, browser: :chrome, options: options )
# end

# Capybara.register_driver :safari do |app|
#   Capybara::Selenium::Driver.new(app, browser: :safari)
# end

Capybara.threadsafe = true
