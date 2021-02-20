#!/bin/bash
if [ -n "$1" ]; then
        arch="${1}"
else
        echo "Please provide architecture: arm64 or amd64"
        exit 1
fi
base=`pwd`
docker_path="${base}/freeswitch/docker_ubnt/${arch}"
if [ ! -d "${docker_path}" ]; then
        echo "Please start the script from the parent folder of freeswitch folder"
        exit 1
fi
image_name="fs_${arch}"
uid=$(id -u ${USER})
gid=$(id -g ${USER}) 
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
docker image inspect "${image_name}:latest" 2>/dev/null 1>/dev/null
ret=$?
if [ "${ret}" == "1" ]; then
	cd "${docker_path}"
	docker build \
		--network host \
		--build-arg UID="${uid}" \
		--build-arg GID="${gid}" \
		--build-arg ARCH="${arch}" \
		-t "${image_name}" .
fi
cd "${base}"
docker create \
	--interactive \
	--privileged \
	--network host \
	--name=fs_${arch} \
	--env "UID=${uid}" \
	--env "GID=${gid}" \
	--env "ARCH=${arch}" \
	-v "${base}:/build:rw" \
	"${image_name}" 2>/dev/null
docker container start "fs_${arch}" 2>/dev/null
docker container exec -ti "fs_${arch}" bash
echo "====================== END ========================="
