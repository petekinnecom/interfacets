# frozen_string_literal: true

# require_relative "./helper"

return

class BrowserTest < InterfacetsTest
  def test_returns_success
    @server = TestAppServer.start
    assert(@server.up?)
  end
end
