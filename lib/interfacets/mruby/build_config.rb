MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gembox 'full-core'
end

MRuby::CrossBuild.new('emscripten') do |conf|
  toolchain :clang
  conf.gembox 'full-core'
  conf.cc.command = 'emcc'
  conf.cc.flags = %W(-Os)
  conf.linker.command = 'emcc'
  conf.archiver.command = 'emar'

  conf.gem :github => 'mattn/mruby-json'
  conf.gem :github => 'monochromegane/mruby-secure-random'
  conf.gem :github => 'iij/mruby-regexp-pcre'
end
