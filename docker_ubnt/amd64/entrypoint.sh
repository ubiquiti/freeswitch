#!/bin/bash
uid="$UID"
gid="$GID"
arch="${ARCH}"
echo "================= ENTRYPOINT START ARCH=${arch} UID=${uid} GID=${gid} ==================="
export TERM="xterm"
cat <<EOT > ${HOME}/.pbuilderrc
PBUILDERSATISFYDEPENDSCMD=/usr/lib/pbuilder/pbuilder-satisfydepends-experimental
HOOKDIR="/var/cache/pbuilder/hook.d"
export DH_VERBOSE=1
BUILDRESULTUID=${uid}
BUILDRESULTGID=${gid}
EOT
echo "============================ ENTRYPOINT LINK =========================="
ln -s -f /usr/lib/pbuilder/pbuilder-satisfydepends-experimental /usr/lib/pbuilder/pbuilder-satisfydepends || true
cd /build/freeswitch
echo "============================ ENTRYPOINT BUILD =========================="
./debian/util_ubnt.sh build-ubnt-debs ${arch}
RET=$?
echo "============================ ENTRYPOINT chown -R ${uid}:${gid} =========================="
chown -R ${uid}:${gid} /build/freeswitch* || true
cd /build/
ls -AlF || true
echo "============================ ENTRYPOINT END =========================="
exit $RET

