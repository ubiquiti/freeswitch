# syntax=docker/dockerfile:experimental
FROM arm64v8/debian:11

COPY ./apt.list /tmp/apt.list

RUN apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends $(grep -v "^#" /tmp/apt.list)

RUN apt-get update && \
      apt-get -y install sudo

WORKDIR /build
