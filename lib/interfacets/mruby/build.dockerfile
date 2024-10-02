FROM emscripten/emsdk:3.1.62-arm64

RUN apt update
RUN apt install -y vim git
RUN apt install -y ruby
RUN git clone https://github.com/mruby/mruby.git /home/root/interfacets/mruby
WORKDIR /home/root/interfacets/mruby
RUN git fetch origin master && git reset --hard origin/master
RUN rake all test
ENV PATH="/home/root/interfacets/mruby/bin:${PATH}"
COPY ./lib/interfacets/mruby/build_config.rb \
  /home/root/interfacets/
WORKDIR /home/root/interfacets
RUN cd mruby && MRUBY_CONFIG=../build_config.rb rake
RUN mkdir -p assets/mruby build
RUN cp -r mruby/include assets/mruby \
  && cp mruby/build/emscripten/lib/libmruby.a assets/mruby
COPY ./lib/interfacets/mruby/init.c \
  ./lib/interfacets/mruby/entrypoint.rb \
  /home/root/interfacets/
RUN mrbc -B ruby_app -o build/app.c entrypoint.rb
RUN echo "\n" >> build/app.c && cat init.c >> build/app.c
RUN emcc -s \
  WASM=1 \
  -sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE='$stringToNewUTF8' \
  -I ./assets/mruby/include \
  build/app.c \
  ./assets/mruby/libmruby.a \
  -o build/ruby.js

RUN mv build /build
