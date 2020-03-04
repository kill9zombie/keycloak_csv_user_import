#!/bin/sh

apk update

apk add build-base clang git wget musl-dev clang-static crystal openssl-dev zlib-dev

cd /build
CC=clang crystal build --release --static --target x86_64-alpine-linux-musl -o bin/keycloak-csv-user-import src/run.cr

chown $(stat -c %u build/alpine-musl-build.sh):$(stat -c %g build/alpine-musl-build.sh) bin/keycloak-csv-user-import
