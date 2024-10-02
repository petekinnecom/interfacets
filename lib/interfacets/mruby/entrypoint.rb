module Kernel
  def wrapped_eval(str, path)
    eval(str, binding, path)
  rescue StandardError, SyntaxError => e
    puts e.class
    puts e.message
    puts e.backtrace.join("\n")
  end

  def wrapped_call(json_string)
    spec = JSON.parse(json_string)
    eval(spec.fetch("receiver")).send(
      spec.fetch("method"),
      *spec.fetch("args", [])
    )
  rescue StandardError, SyntaxError => e
    puts e.class
    puts e.message
    puts e.backtrace.join("\n")
  end
end

puts "ruby initialized. Calling window.Interfacets.rubyLoaded()"
js_eval("window.Interfacets.rubyLoaded()")
