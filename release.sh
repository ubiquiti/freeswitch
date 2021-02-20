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
echo "===================== START ${uid} ${gid} ${arch} ========================"
base=`pwd`
cd ${base}/freeswitch/ubnt
docker build \
	--network host \
	--build-arg UID="${uid}" --build-arg GID="${gid}" --build-arg ARCH="${arch}" -t "${image_name}" .
echo "====================== END ========================="
echo "====================== BUILDER RUN arch=${arch} uid=$(id -u ${USER}) gid=$(id -g ${USER}) ========================="
docker create \
	--interactive \
	--privileged \
	--network host \
	--name=fs \
	--env "UID=${uid}" --env "GID=${gid}" --env "ARCH=${arch}" \
	-v "${base}:/build:rw" \
	"${image_name}"
echo "====================== END ========================="

