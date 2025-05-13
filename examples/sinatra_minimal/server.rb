require_relative "app"

# Configure Sinatra settings
Sinatra::Application.set :port, 4569
Sinatra::Application.set :bind, '0.0.0.0'

# Start Sinatra in a thread
server_thread = Thread.new do
  Sinatra::Application.run!
end

puts "Sinatra app starting on http://localhost:4569"
puts "Server thread is running. You can now execute other Ruby code..."

# Keep the main thread alive and allow interactive use
if $0 == __FILE__
  # You can add any other code here or start an IRB session
  # For now, just keep the process alive
  server_thread.join
end
