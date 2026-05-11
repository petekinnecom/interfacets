# frozen_string_literal: true

# require_relative "../test_helper"
# require_relative "./server"

# require "rackup"
# require "capybara"
# require "net/http"

# require "action_controller/railtie"

Capybara.threadsafe = true
class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << "example.org"
  config.secret_key_base = "secret_key_base"

  config.middleware.use(
    Rack::Static,
    urls: ["/interfacets"],
    root: "./app/assets/javascript",
    cascade: true,
  )

  config.logger = Logger.new("log/test_app.log")
  Rails.logger = config.logger

  routes.draw do
    get "/" => ->(*) { [200, {}, ["hello"]] }
  end
end

class BrowserTest < InterfacetsTest
  def test_returns_success
    @server = TestAppServer.start
    assert(@server.up?)

    browser =
      Capybara::Session.new(:selenium).tap do |s|
        s.config.default_max_wait_time = 5
        s.config.app_host = "http://localhost:#{@server.port}"
      end

    ui.visit("/interfacets/system")
    sleep(10)
    assert_equal("hi hi", ui.text)
  end
end
