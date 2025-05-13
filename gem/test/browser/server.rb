# frozen_string_literal: true

class TestAppServer
  MAX_SECONDS = 5
  POLLS_PER_SECOND = 10

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
        # logger = Logger.new("./log/test.log")
        # logger.level = Logger::DEBUG
        Rackup::Handler::WEBrick.run(
          app,
          Port: port,
          # Logger: logger,
        )
      end
  end

  def ensure_up
    return if up?

    delay = 1.0 / POLLS_PER_SECOND.to_f

    (MAX_SECONDS * POLLS_PER_SECOND).times do |i|
      sleep(delay) if i.positive?
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
