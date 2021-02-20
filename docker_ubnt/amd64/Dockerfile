FROM debian:stretch

ARG UID
ARG GID
ARG ARCH

ENV HOME=/home/ubnt

COPY ./apt.list /tmp/apt.list

RUN \
    useradd -u $UID --create-home --shell /bin/bash ubnt && \
    apt-get update && \
    apt-get install -y --no-install-recommends $(grep -v "^#" /tmp/apt.list) && \
    echo "ubnt ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubnt-nopasswd && \
    ln -sf /bin/bash /bin/sh

RUN \
    mkdir /home/ubnt/.ssh && \
    echo "nameserver 10.28.42.11" > /etc/resolv.conf && \
    ssh-keyscan -H github.com >> /home/ubnt/.ssh/known_hosts && \
    ssh-keyscan -H -p 2022 slc-unifi-scm.rad.ubnt.com >> /home/ubnt/.ssh/known_hosts

WORKDIR /build



