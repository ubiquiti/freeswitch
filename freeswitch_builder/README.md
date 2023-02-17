# FreeSWITCH Builder


# Overview

This is a tool for building FreeSWITCH on various combinations of CPU architectures and OS-es.
It builds a FreeSWITCH from sources.


## Folder structure

- Makefile - make script, encapsulates all target recipes
- README - this file, manual/description
- platform - contains platform definitions for docker images

Once you start building expect 3 more folders, containing sources:

- freeswitch
- sofia-sip
- spandsp

These source folders get mounted into docker containers when buidling FreeSWITCH.


## Building procedure

To build for arm64:deb11:
```
make freeswitch-arm64-debian
```

To build for amd64:deb11:
```
make freeswitch-amd64-debian
```

To build for other OS:
edit platform/$arch/Dockerfile and change OS version, e.g. to compile for Debian 9:
```
FROM arm64v8/debian:9
```


## To open a console on docker image for building

```
make console-freeswitch-arm64-debian
```

## FreeSWITCH setup

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
