# frozen_string_literal: true

# # require "bundler/inline"

# require "action_controller/railtie"

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << "example.org"
  config.secret_key_base = "secret_key_base"

  config.logger = Logger.new($stdout)
  Rails.logger = config.logger

  routes.draw do
    get "/" => ->(*) { [200, {}, "hello"] }
  end
end

# require "minitest/autorun"
# require "rack/test"

class BugTest < ActiveSupport::TestCase
  def test_returns_success
    @server = Server.start
    assert(@server.up?)
  end
end

class Server
  def self.start
    new.tap(&:run)
  end

  def run
    server_thread # start server
    ensure_up
  end

  def server_thread
    @server_thread ||=
      Thread.new do
        Rackup::Handler::WEBrick.run(app, Port: port)
      end
  end

  def ensure_up
    return if up?

    5.times do |i|
      sleep(1) if i.positive?
      uri = URI("http://localhost:#{port}")
      response = Net::HTTP.get_response(uri)
      if response.code == "200"
        @up = true
        break
      end
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end

    raise("server didn't start") unless @up
  end

  def up?
    @up
  end

  def app
    @app ||= Rails.application
  end

  def port
    @port ||= rand(3000..65_535)
  end
end

# end

# app = Rails.application
# random_port = rand(3000..65535)

# thread = Thread.new do
#   Rackup::Handler::WEBrick.run(app, Port: random_port)
# end

# uri = URI("http://localhost:#{random_port}")
# response = Net::HTTP.get_response(uri)

:ok
