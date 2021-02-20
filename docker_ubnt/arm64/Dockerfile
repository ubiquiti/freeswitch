# syntax=docker/dockerfile:experimental
FROM arm64v8/debian:9
ARG HOST_UID=1000

COPY ./apt.list /tmp/apt.list

RUN useradd -u $HOST_UID --create-home --shell /bin/bash ubnt 

RUN apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends $(grep -v "^#" /tmp/apt.list)

RUN \
    sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^root.*/root ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g' && \
    echo "ubnt ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "ubnt user:";  su - ubnt -c id


WORKDIR /build

USER ubnt
ENV HOME=/home/ubnt
