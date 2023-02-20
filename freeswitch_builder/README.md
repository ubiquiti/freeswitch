# FreeSWITCH Builder

# Quick start

To create debian package for arm64:

```
make deb-arm64
```

# Overview

This is a tool for building FreeSWITCH on various combinations of CPU architectures and OS-es.
It builds a FreeSWITCH from sources and packages outputs in debian package so it can be installed with `dpkg -i`.


# Folder structure

- Makefile - make script, encapsulates all target recipes
- README - this file, manual/description
- platform - contains platform definitions (for docker images) and deb control files

When building executables - expect 3 more folders to be created, they contain sources:

- freeswitch
- sofia-sip
- spandsp

These source folders get mounted into docker containers when buidling FreeSWITCH.

When building deb package - DEBBUILD folder is created and package is output in there (*.deb file).


# Building procedure to build FreeSWITCH

for arm64:deb11:
```
make freeswitch-arm64-debian
```

for amd64:deb11:
```
make freeswitch-amd64-debian
```

To build for other OS:
edit platform/$arch/Dockerfile and change OS version, e.g. to compile for Debian 9:
```
FROM arm64v8/debian:9
```

# Building procedure to build FreeSWITCH and get it packaged in deb package

for arm64:deb11:
```
make deb-arm64
```

for amd64:deb11:
```
make deb-amd64
```

Debian package is created in DEBBUILD folder, e.g.: `DEBBUILD/freeswitch-unifi-talk-$(arch).deb`

# To open a console on docker image

Execute this to get a console on docker, so you can build FreeSWITCH/packages and look around
```
make console-freeswitch-arm64-debian
```

# FreeSWITCH setup

This is the configuration FreeSWITCH is built with:

```
-------------------------- FreeSWITCH configuration --------------------------

  Locations:

      prefix:          /usr/local/freeswitch
      exec_prefix:     /usr/local/freeswitch
      bindir:          ${exec_prefix}/bin
      confdir:         /usr/local/freeswitch/conf
      libdir:          ${exec_prefix}/lib
      datadir:         /usr/local/freeswitch
      localstatedir:   /usr/local/freeswitch
      includedir:      /usr/local/freeswitch/include/freeswitch

      certsdir:        /usr/local/freeswitch/certs
      dbdir:           /usr/local/freeswitch/db
      grammardir:      /usr/local/freeswitch/grammar
      htdocsdir:       /usr/local/freeswitch/htdocs
      fontsdir:        /usr/local/freeswitch/fonts
      logfiledir:      /usr/local/freeswitch/log
      modulesdir:      /usr/local/freeswitch/mod
      pkgconfigdir:    ${exec_prefix}/lib/pkgconfig
      recordingsdir:   /usr/local/freeswitch/recordings
      imagesdir:       /usr/local/freeswitch/images
      runtimedir:      /usr/local/freeswitch/run
      scriptdir:       /usr/local/freeswitch/scripts
      soundsdir:       /usr/local/freeswitch/sounds
      storagedir:      /usr/local/freeswitch/storage
      cachedir:        /usr/local/freeswitch/cache
```
