FROM emscripten/emsdk:3.1.62

RUN apt update
RUN apt install -y vim git
RUN apt install -y ruby
RUN git clone https://github.com/mruby/mruby.git /home/root/interfacets/mruby
WORKDIR /home/root/interfacets/mruby
# RUN git fetch origin master && git reset --hard origin/master
RUN git fetch origin --tags && git reset --hard 3.4.0
RUN rake all test
ENV PATH="/home/root/interfacets/mruby/bin:${PATH}"
COPY ./lib/interfacets/mruby/build_config.rb \
  /home/root/interfacets/
WORKDIR /home/root/interfacets
RUN cd mruby && \
  sed -i '/MRB_STR_LENGTH_MAX 1048576/c#define MRB_STR_LENGTH_MAX 0' src/string.c && \
  MRUBY_CONFIG=../build_config.rb rake
RUN mkdir -p assets/mruby build
RUN cp -r mruby/include assets/mruby \
  && cp mruby/build/emscripten/lib/libmruby.a assets/mruby
COPY ./lib/interfacets/mruby/init.c \
  ./lib/interfacets/mruby/entrypoint.rb \
  /home/root/interfacets/
# RUN mrbc --help
RUN mrbc -B ruby_app -o build/app.c entrypoint.rb
RUN echo "\n" >> build/app.c && cat init.c >> build/app.c
RUN emcc \
  -s EXPORT_NAME=MRuby \
  -s EXPORTED_FUNCTIONS='_ruby_eval,_main,_ruby_call,stringToNewUTF8' \
  -s ENVIRONMENT=web \
  -s MODULARIZE=1 \
  -s EXPORT_ES6=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s SINGLE_FILE=1 \
  -I ./assets/mruby/include \
  build/app.c \
  ./assets/mruby/libmruby.a \
  -o build/ruby.js

RUN emcc \
  -s EXPORT_NAME=MRuby \
  # -s EXPORTED_FUNCTIONS='_ruby_eval,_main,_ruby_call,stringToNewUTF8' \
  -s ENVIRONMENT=node \
  -s MODULARIZE=1 \
  -s EXPORT_ES6=1 \
  -s SIDE_MODULE=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -I ./assets/mruby/include \
  build/app.c \
  ./assets/mruby/libmruby.a \
  -o build/test.wasm

RUN emcc \
  -s EXPORT_NAME=MRuby \
  -s EXPORTED_FUNCTIONS='_ruby_eval,_main,_ruby_call,stringToNewUTF8' \
  -s ENVIRONMENT=node \
  -s MODULARIZE=1 \
  -s EXPORT_ES6=1 \
  -s MAIN_MODULE=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -I ./assets/mruby/include \
  build/app.c \
  ./assets/mruby/libmruby.a \
  -o build/test.js

RUN mv build /build
