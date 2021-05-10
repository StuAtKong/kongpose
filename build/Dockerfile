FROM kong/kong-gateway:2.4.0.0-beta1-alpine

USER root
COPY lua-zlib-1.2-0.linux-x86_64.rock /tmp
RUN luarocks install /tmp/lua-zlib-1.2-0.linux-x86_64.rock

USER kong
