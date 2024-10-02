# Interfacets

### Building MRuby for WASM

The Dockerfile builds everything needed. It puts the two required files at `/build/ruby.js`, `/build/ruby.wasm`. In order to extract these two files from the build, you can start a container with a bind-mount and copy them out.  For example:

```bash
docker build -f ./lib/interfacets/mruby/build.dockerfile -t mruby .
docker run -v./build:/build2 mruby cp /build/ruby.js /build/ruby.wasm /build2
```
