#!/bin/bash

if [ -n "$1" ]; then
        arch="${1}"
else
        echo "Please provide architecture"
        exit 1
fi
ver="1.10.5"
image_name="fs_${ver}_${arch}"
uid=$(id -u ${USER})
gid=$(id -g ${USER}) 
set -e
base=`pwd`
cd ${base}/freeswitch/ubnt
docker build \
	--network host \
	--build-arg UID="${uid}" --build-arg GID="${gid}" --build-arg ARCH="${arch}" -t "${image_name}" .
echo "====================== END ========================="
