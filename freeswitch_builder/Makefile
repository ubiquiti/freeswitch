FREESWITCH_SRC="https://github.com/ubiquiti/freeswitch"
FREESWITCH_PREFIX=/usr/local/freeswitch
SOFIA_SRC="https://github.com/freeswitch/sofia-sip"
SPANDSP_SRC="https://github.com/freeswitch/spandsp"
SHELL := /bin/bash

docker-image-arm64-debian:
	cd platform/arm64_debian && docker build \
		--network host \
		--build-arg ARCH=arm64 \
		-t fs_arm64_debian .

docker-image-amd64-debian:
	cd platform/amd64_debian && docker build \
                --network host \
                --build-arg ARCH=amd64 \
                -t fs_amd64_debian .

freeswitch-src:
	bash -c "[[ -d freeswitch ]] || git clone $(FREESWITCH_SRC)"

sofia-src:
	bash -c "[[ -d sofia-sip ]] || git clone $(SOFIA_SRC)"

spandsp-src:
	bash -c "[[ -d spandsp ]] || git clone $(SPANDSP_SRC)"

sources: sofia-src spandsp-src freeswitch-src

_sofia: sofia-src
	cd sofia-sip && ./bootstrap.sh && ./configure CFLAGS="-ggdb -O0 -rdynamic" && make && make install && cd - && touch _sofia

_spandsp: spandsp-src
	cd spandsp && ./bootstrap.sh && ./configure CFLAGS="-ggdb -O0 -rdynamic" && make && make install && cd - && touch _spandsp

freeswitch-debian-deps:
	apt install -y libavformat-dev libswscale-dev libopus-dev libpq-dev libsndfile-dev flite1-dev libshout3-dev libmpg123-dev libmp3lame-dev

freeswitch-conf: freeswitch-src
	bash -c "[[ ! -e freeswitch/modules_ubnt.conf ]] || mv freeswitch/modules_ubnt.conf freeswitch/modules.conf"
	sed -i '/mod_verto/d' freeswitch/modules.conf
	sed -i '/mod_signalwire/d' freeswitch/modules.conf
	sed -i '/mod_rtc/d' freeswitch/modules.conf
	sed -i '/mod_skinny/d' freeswitch/modules.conf
	sed -i '/mod_lua/d' freeswitch/modules.conf

_freeswitch-debian: _sofia _spandsp freeswitch-src freeswitch-debian-deps freeswitch-conf
	cd freeswitch \
	&& ./bootstrap.sh \
	&& ./configure CFLAGS="-ggdb -O0 -rdynamic" --prefix=$(FREESWITCH_PREFIX) \
	&& make \
	&& make install \
	&& cd - \
	&& touch _freeswitch-debian

freeswitch-arm64-debian: docker-image-arm64-debian sources
	docker run -it \
		-e USER=$(USER) \
		-e GROUP=$(USER) \
		-v $(PWD):/SRC \
		--platform linux/arm64 \
		--network=host \
		--rm \
		fs_arm64_debian \
		/bin/bash -c "cd /SRC && make _freeswitch-debian"

freeswitch-amd64-debian: docker-image-amd64-debian sources
	docker run -it \
		-e USER=$(USER) \
		-e GROUP=$(USER) \
		-v $(PWD)/Makefile:/build/Makefile \
		-v $(PWD)/sofia-sip:/build/sofia-sip \
		-v $(PWD)/spandsp:/build/spandsp \
		-v $(PWD)/freeswitch:/build/freeswitch \
		--platform linux/arm64 \
		--network=host \
		--rm \
		fs_amd64_debian \
		/bin/bash -c "make _freeswitch-debian"

console-freeswitch-arm64-debian: docker-image-arm64-debian sources
	docker run -it \
		-e USER=$(USER) \
		-e GROUP=$(USER) \
		-v $(PWD)/Makefile:/build/Makefile \
		-v $(PWD)/sofia-sip:/build/sofia-sip \
		-v $(PWD)/spandsp:/build/spandsp \
		-v $(PWD)/freeswitch:/build/freeswitch \
		--platform linux/arm64 \
		--network=host \
		--rm \
		fs_arm64_debian \
		/bin/bash

console-freeswitch-amd64-debian: docker-image-amd64-debian sources
	docker run -it \
		-e USER=$(USER) \
		-e GROUP=$(USER) \
		-v $(PWD)/Makefile:/build/Makefile \
		-v $(PWD)/sofia-sip:/build/sofia-sip \
		-v $(PWD)/spandsp:/build/spandsp \
		-v $(PWD)/freeswitch:/build/freeswitch \
		--platform linux/amd64 \
		--network=host \
		--rm \
		fs_amd64_debian \
		/bin/bash

make-deb-arm64:  _freeswitch-debian
	rm -rf DEBBUILD
	mkdir -p DEBBUILD/freeswitch-unifi-talk-arm64/DEBIAN
	cd freeswitch && DESTDIR=`pwd`/../DEBBUILD/freeswitch-unifi-talk-arm64 make install
	### mkdir -p `pwd`/DEBBUILD/freeswitch-unifi-talk-arm64/usr/local/test
	cp platform/arm64_debian/DEBIAN/debian.control DEBBUILD/freeswitch-unifi-talk-arm64/DEBIAN/control
	chmod -R g-s DEBBUILD
	cd DEBBUILD && dpkg-deb --build --root-owner-group freeswitch-unifi-talk-arm64

deb-arm64: docker-image-arm64-debian
	docker run -it \
		-e USER=$(USER) \
		-e GROUP=$(USER) \
		-v $(PWD):/SRC \
		--platform linux/arm64 \
		--network=host \
		--rm \
		fs_arm64_debian \
		/bin/bash ### -c "cd /SRC && make make-deb-arm64 && tail -f /dev/null"
