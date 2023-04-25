#!/bin/bash
##### -*- mode:shell-script; indent-tabs-mode:nil; sh-basic-offset:2 -*-
##### Author: Travis Cross <tc@traviscross.com>

set -e

ddir="."
[ -n "${0%/*}" ] && ddir="${0%/*}"
cd $ddir/../

#### lib

err () {
  echo "$0 error: $1" >&2
  exit 1
}


log(){
    echo "$1" >> ./log.log
}

announce () {
  cat >&2 <<EOF

########################################################################
## $1
########################################################################

EOF
}

xread () {
  local xIFS="$IFS"
  IFS=''
  read $@
  local ret=$?
  IFS="$xIFS"
  return $ret
}

mk_dver () { echo "$1" | sed -e 's/-/~/g'; }
mk_uver () { echo "$1" | sed -e 's/-.*$//' -e 's/~/-/'; }
dsc_source () { dpkg-parsechangelog | grep '^Source:' | awk '{print $2}'; }
dsc_ver () { dpkg-parsechangelog | grep '^Version:' | awk '{print $2}'; }
up_ver () { mk_uver "$(dsc_ver)"; }
dsc_base () { echo "$(dsc_source)_$(dsc_ver)"; }
up_base () { echo "$(dsc_source)-$(up_ver)"; }

find_distro () {
  case "$1" in
    experimental) echo "sid";;
    unstable) echo "sid";;
    testing) echo "buster";;
    stable) echo "stretch";;
    oldstable) echo "jessie";;
    *) echo "$1";;
  esac
}

find_suite () {
  case "$1" in
    sid) echo "unstable";;
    buster) echo "testing";;
    stretch) echo "stable";;
    jessie) echo "oldstable";;
    *) echo "$1";;
  esac
}

#### debian/rules helpers

create_dbg_pkgs () {
  for x in $ddir/*; do
    test ! -d $x && continue
    test "$x" = "tmp" -o "$x" = "source" && continue
    test ! "$x" = "${x%-dbg}" && continue
    test ! -d $x/usr/lib/debug && continue
    mkdir -p $x-dbg/usr/lib
    mv $x/usr/lib/debug $x-dbg/usr/lib/
  done
}

cwget () {
  local url="$1" f="${1##*/}"
  echo "fetching: $url to $f" >&2
  if [ -n "$FS_FILES_DIR" ]; then
    if ! [ -s "$FS_FILES_DIR/$f" ]; then
      (cd $FS_FILES_DIR && wget -N "$url")
    fi
    cp -a $FS_FILES_DIR/$f .
  else
    wget -N "$url"
  fi
}

getlib () {
  local url="$1" f="${1##*/}"
  cwget "$url"
  tar -xv --no-same-owner --no-same-permissions -f "$f"
  rm -f "$f" && mkdir -p $f && touch $f/.download-stamp
}

getlibs () {
  # get pinned libraries
  getlib http://files.freeswitch.org/downloads/libs/sphinxbase-0.8.tar.gz
  getlib http://files.freeswitch.org/downloads/libs/pocketsphinx-0.8.tar.gz
  getlib http://files.freeswitch.org/downloads/libs/communicator_semi_6000_20080321.tar.gz
  #getlib http://download.zeromq.org/zeromq-2.1.9.tar.gz \
  #  || getlib http://download.zeromq.org/historic/zeromq-2.1.9.tar.gz
  getlib http://files.freeswitch.org/downloads/libs/freeradius-client-1.1.7.tar.gz
  #getlib http://files.freeswitch.org/downloads/libs/v8-3.24.14.tar.bz2
}

check_repo_clean () {
    log "#-> check_repo_clean ( ) "
  git diff-index --quiet --cached HEAD \
    || err "uncommitted changes present"
  git diff-files --quiet \
    || err "unclean working tree"
  git diff-index --quiet HEAD \
    || err "unclean repository"
  ! git ls-files --other --error-unmatch . >/dev/null 2>&1 \
    || err "untracked files or build products present"
    log "<-# check_repo_clean ( ) "
}

get_last_release_ver () {
  grep -m1 -e '^AC_INIT' configure.ac \
    | cut -d, -f2 \
    | sed -e 's/\[//' -e 's/\]//' -e 's/ //g'
}

get_nightly_version () {
  local commit="$(git rev-list -n1 --abbrev=10 --abbrev-commit HEAD)"
  echo "$(get_last_release_ver)+git~$(date -u '+%Y%m%dT%H%M%SZ')~$commit"
  #echo "1.10.5~release+git~20210121T110356Z~085d30c552~stretch-1~stretch+1_arm64"
  #echo "1.10.5~release+git~20210121T110356Z~085d30c552"
}

get_nightly_revision_human () {
  echo "git $(git rev-list -n1 --abbrev=7 --abbrev-commit HEAD) $(date -u '+%Y-%m-%d %H:%M:%SZ')"
}

create_orig () {
  log "#-> create_orig ( ) "
  {
    set -e
    local OPTIND OPTARG
    local uver="" hrev="" bundle_deps=true modules_list="" zl=9e
    while getopts 'bm:nv:z:' o "$@"; do
      case "$o" in
        m) modules_list="$OPTARG";;
        n) uver="nightly";;
        v) uver="$OPTARG";;
        z) zl="$OPTARG";;
      esac
    done
    shift $(($OPTIND-1))
    if [ -z "$uver" ] || [ "$uver" = "nightly" ]; then
      uver="$(get_nightly_version)"
      hrev="$(get_nightly_revision_human)"
    fi
    local treeish="$1"
    local dver="$(mk_dver "$uver")"
    local orig="../freeswitch_$dver~$(lsb_release -sc).orig.tar.xz"
    log "uver=$uver dver=$dver orig=$orig treeish=$treeish"
    [ -n "$treeish" ] || treeish="HEAD"

    # check_repo_clean
    # git reset --hard "$treeish"


    mv .gitattributes .gitattributes.orig
    local -a args=(-e '\bdebian-ignore\b')
    test "$modules_list" = "non-dfsg" || args+=(-e '\bdfsg-nonfree\b')
    grep .gitattributes.orig "${args[@]}" \
      | while xread l; do
      echo "$l export-ignore" >> .gitattributes
    done

    #if $bundle_deps; then
    #  (cd libs && getlibs)
    #  git add -f libs
    #fi

    ./build/set-fs-version.sh "$uver" "$hrev" 
    #git add configure.ac
    #echo "$uver" > .version && git add -f .version
    echo "$uver" > .version
    # git commit --allow-empty -m "nightly v$uver"

    git archive -v \
      --worktree-attributes \
      --format=tar \
      --prefix=freeswitch-$uver/ \
      HEAD \
      | xz -c -${zl}v > $orig
    mv .gitattributes.orig .gitattributes

    #git reset --hard HEAD^ && git clean -fdx

  } 1>&2
  echo $orig
  log "<-# create_orig ( ) [$orig]"
}

set_modules_quicktest () {
  cat > debian/modules.conf <<EOF
applications/mod_commands
EOF
}

create_dsc () {
  {
    set -e

    log "#-> create_dsc ( [$1][$2][$3][$4][$5][$6][$7][$8] ) "

    local OPTIND OPTARG modules_conf=$(pwd)/modules_ubnt.conf modules_list="" speed="normal" suite_postfix="" suite_postfix_p=false zl=9
    local modules_add=""
    while getopts 'a:f:m:p:s:u:z:' o "$@"; do
      case "$o" in
        a) avoid_mods_arch="$OPTARG";;
        f) modules_conf="$OPTARG";;
        m) modules_list="$OPTARG";;
        p) modules_add="$modules_add $OPTARG";;
        s) speed="$OPTARG";;
        u) suite_postfix="$OPTARG"; suite_postfix_p=true;;
        z) zl="$OPTARG";;
      esac
    done
    shift $(($OPTIND-1))
    local distro="$(find_distro $1)" orig="$2"
    local suite="$(find_suite $distro)"
    local orig_ver="$(echo "$orig" | sed -e 's/^.*_//' -e 's/\.orig\.tar.*$//')"
    local dver="${orig_ver}-1~${distro}+1"
    log "   create_dsc ( ) orig=[$orig] orig_ver=[$orig_ver] suite=[$suite] dver=[$dver] distro=[${distro}] modules_conf=[${modules_conf}]"
    $suite_postfix_p && { suite="${distro}${suite_postfix}"; }
    [ -x "$(which dch)" ] \
      || err "package devscripts isn't installed"
    if [ -n "$modules_conf" ]; then
      cp $modules_conf debian/modules.conf
    fi
    local bootstrap_args=""
    if [ -n "$modules_list" ]; then
      if [ "$modules_list" = "non-dfsg" ]; then
        bootstrap_args="-mnon-dfsg"
      else set_modules_${modules_list}; fi
    fi
    if test -n "$modules_add"; then
      for x in $modules_add; do
        bootstrap_args="$bootstrap_args -p${x}"
      done
    fi
    log "./bootstrap.sh -c $distro $bootstrap_args"
    (cd debian && ./bootstrap.sh -c $distro $bootstrap_args)
    case "$speed" in
      paranoid) sed -i ./debian/rules \
        -e '/\.stamp-bootstrap:/{:l2 n; /\.\/bootstrap.sh -j/{s/ -j//; :l3 n; b l3}; b l2};' ;;
      reckless) sed -i ./debian/rules \
        -e '/\.stamp-build:/{:l2 n; /make/{s/$/ -j/; :l3 n; b l3}; b l2};' ;;
    esac
    [ "$zl" -ge "1" ] || zl=1
    #git add debian/rules
    dch -b -m -v "$dver" --force-distribution -D "$suite" "Nightly build."
    #git add debian/changelog && git commit -m "nightly v$orig_ver"
    dpkg-source -i.* -Zxz -z${zl} -b .
    dpkg-genchanges -S > ../$(dsc_base)_source.changes
    local dsc="../$(dsc_base).dsc"
    #git reset --hard HEAD^ && git clean -fdx
  } 1>&2
  echo $dsc
  log "<-# create_dsc ( ) [$dsc]"
}

fmt_debug_hook () {
  cat <<'EOF'
#!/bin/bash
export debian_chroot="cow"
cd /tmp/buildd/*/debian/..
/bin/bash < /dev/tty > /dev/tty 2> /dev/tty
EOF
}


fmt_apt_update_hook () {
    cat <<'EOF'
#!/bin/sh
echo "#-> hook"
echo "1) ls /build/deb"
ls /build/deb
echo "2) cd /build/deb"
cd /build/deb
/usr/bin/dpkg-scanpackages -m . | gzip -c > "Packages.gz"
echo "" >> /etc/apt/sources.list
echo "deb [trusted=yes] file:///build/deb ./" >> /etc/apt/sources.list

echo "3) cat /etc/apt/sources.list"
cat /etc/apt/sources.list

echo "4) apt-get update"
/usr/bin/apt-get update

echo "5)"
/usr/bin/apt-get install -y -f /build/deb/libspandsp3-dev_3.0.0-42_arm64.deb
/usr/bin/apt-get install -y -f /build/deb/libspandsp3_3.0.0-42_arm64.deb
/usr/bin/apt-get install -y -f /build/deb/libspandsp3-dbgsym_3.0.0-42_arm64.deb

echo "6) dpkg -l | grep libspan"
/usr/bin/dpkg -l | grep libspan

echo "<-# hook"
EOF
}

libks_install_hook () {
    cat <<'EOF'
#!/bin/sh
echo "#-> libks hook"

echo "1) apt-get install -y ca-certificates wget uuid-dev git ssh-client"
apt-get install -y ca-certificates wget uuid-dev git ssh-client

echo "installing cmake"
echo "2) wget https://cmake.org/files/v3.7/cmake-3.7.2.tar.gz"
wget https://cmake.org/files/v3.7/cmake-3.7.2.tar.gz
echo "3) tar -zxf cmake-3.7.2.tar.gz"
tar -zxf cmake-3.7.2.tar.gz
echo "4) cd cmake-3.7.2"
cd cmake-3.7.2
echo "5) ./bootstrap --prefix=/usr/local"
./bootstrap --prefix=/usr/local
echo "6) make"
make
echo "7) make install"
make install
echo "cmake version:"
/usr/local/bin/cmake --version

echo "installing libks 1.7.0"
echo "apt-get install -y pkg-config cmake-data libssl-dev"
echo "8) cd .. && git clone https://github.com/signalwire/libks.git"
cd .. && git clone https://github.com/signalwire/libks.git
echo "9) cd libks"
cd libks
echo "10) /usr/local/bin/cmake ."
/usr/local/bin/cmake .
echo "11) make"
make 
echo "12) make install"
make install

echo "<-# libks hook"
EOF
}

get_sources () {
  local tgt_distro="$1"
  while read type args path distro components; do
    test "$type" = deb || continue
    if echo "$args" | grep -qv "\[" ; then components=$distro;distro=$path;path=$args;args=""; fi
    prefix=`echo $distro | awk -F/ '{print $1}'`
    suffix="`echo $distro | awk -F/ '{print $2}'`"
    if test -n "$suffix" ; then full="$tgt_distro/$suffix" ; else full="$tgt_distro" ; fi
    printf "$type $args $path $full $components\n"
  done < "$2"
}

get_mirrors () {
  file=${2-/etc/apt/sources.list}
  announce "Using apt sources file: $file"
  get_sources "$1" "$file" | tr '\n' '|' | head -c-1; echo
}

build_debs () {
  {
    set -e
    log "#-> build_debs ( [$1][$2][$3][$4][$5][$6][$7][$8] ) "
    local OPTIND OPTARG
    local debug_hook=true
    local hookdir=""
    local cow_build_opts=""
    local keep_pbuilder_config=true
    local keyring=""
    local custom_keyring="/tmp/fs.gpg"
    local use_custom_sources=true
    # Karlis
    use_custom_sources=false
    local custom_sources_file="/etc/apt/sources.list"
    # Karlis
    custom_sources_file=""
    while getopts 'BbdK:kT:t' o "$@"; do
      case "$o" in
        B) cow_build_opts="--debbuildopts '-B'";;
        b) cow_build_opts="--debbuildopts '-b'";;
        d) debug_hook=true;;
        k) keep_pbuilder_config=true;;
        K) custom_keyring="$OPTARG";;
        t) custom_sources_file="/etc/apt/sources.list";;
        T) custom_sources_file="$OPTARG";;
      esac
    done
    shift $(($OPTIND-1))
    if [ "$custom_sources_file" == "/etc/apt/sources.list" ]; then
      # If you are using the system sources, then it is reasonable that you expect to use all of the supplementary repos too
      cat /etc/apt/sources.list > /tmp/fs.sources.list
      if [ "$(ls -A /etc/apt/sources.list.d)" ]; then
        for X in /etc/apt/sources.list.d/*; do cat $X >> /tmp/fs.sources.list; done
      fi
      custom_sources_file="/tmp/fs.sources.list"
      apt-key exportall > "/tmp/fs.gpg"
      custom_keyring="/tmp/fs.gpg"
    fi
    log "   build_debs ( ) #1 "    
    if [ "$custom_sources_file" == "" ]; then
        # echo "use_custom_sources = false <<<<<<<<<<<"
      # Caller has explicitly set the custom sources file to empty string. They must intend to not use additional mirrors.
      use_custom_sources=false
    fi
    if [[ "$custom_source_file" == "/tmp/fs.sources.list" && ! -e "/tmp/fs.sources.list" ]]; then
      echo "deb [trusted=yes] http://files.freeswitch.org/repo/deb/freeswitch-1.8/ stretch main" >> "/tmp/fs.sources.list"
    fi
    log "   build_debs ( ) #2 "    
    if [[ "$custom_keyring" == "/tmp/fs.gpg" && ! -r "/tmp/fs.gpg" ]]; then
      cat << EOF > "/tmp/fs.tmp.gpg"
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
Y4o4oqgePeTYzkxVYj8=
=XPvO
-----END PGP PUBLIC KEY BLOCK-----
EOF
      gpg --no-default-keyring --keyring /tmp/fs.tmp.keyring.gpg  --import /tmp/fs.tmp.gpg
      gpg --no-default-keyring --keyring /tmp/fs.tmp.keyring.gpg  --export > "/tmp/fs.gpg"
    fi

    log "    build_debs ( [$1] ) #3"
    local distro="$(find_distro $1)" dsc="$2" arch="$3"
    if [ -z "$distro" ] || [ "$distro" = "auto" ]; then
      if ! (echo "$dsc" | grep -e '-[0-9]*~[a-z]*+[0-9]*'); then
        err "no distro specified or found"
      fi
      local x="$(echo $dsc | sed -e 's/^[^-]*-[0-9]*~//' -e 's/+[^+]*$//')"
      distro="$(find_distro $x)"
    fi

    log "    build_debs ( ) #4"

    [ -n "$arch" ] || arch="$(dpkg-architecture | grep '^DEB_BUILD_ARCH=' | cut -d'=' -f2)"
    [ -x "$(which cowbuilder)" ] \
      || err "package cowbuilder isn't installed"
    local cow_img=/var/cache/pbuilder/base-$distro-$arch.cow

    log "    build_debs ( ) #5"

    if [ -e "$custom_keyring" ]; then
      keyring="$custom_keyring"
    else
      keyring="$(mktemp /tmp/keyringXXXXXXXX.asc)"
      apt-key exportall > "$keyring"
    fi

    log "    build_debs ( ) #6"

    cow () {
      log "#-> cow ( [$1][$2][$3][$4][$5][$6][$7][$8] )"

      local debbootstrap="";
      #local debbootstrap="--debootstrap qemu-debootstrap"
      #if [ "${arch}" == "amd64" ] ; then
      #   debbootstrap="";
      #fi
      if ! $use_custom_sources; then
        log "Using system sources $keyring $distro $custom_sources_file"
        log "cowbuilder $@ --distribution $distro --architecture $arch --basepath $cow_img --othermirror 'deb file:///var/cache/pbuilder/repo ./' --mirror http://deb.debian.org/debian/ ${debbootstrap} "
        cowbuilder "$@" \
          --distribution $distro \
          --architecture $arch \
          --basepath $cow_img \
          --mirror http://deb.debian.org/debian/ ${debbootstrap}
      else
        log "Using custom sources $keyring $distro $custom_sources_file "
	cowbuilder "$@" \
          --distribution $distro \
          --architecture $arch \
          --basepath $cow_img \
          --othermirror "deb [trusted=yes] http://pdx-artifacts.rad.ubnt.com/apt-internal stretch main" \
          --keyring "$keyring" \
          --mirror http://deb.debian.org/debian/ ${debbootstrap}
        log "======================================================================================="
      fi
      log "<-# cow ( )"
    }
    log "    build_debs ( ) #7 DISTRO=[$distro] ARCH=[$arch] COW_IMG[$cow_img]"
    if ! [ -d $cow_img ]; then
      announce "Creating base $distro-$arch image..."
      local x=30
      
      log "##################### COW CREATE #######################"
      
      while ! cow --create; do
        [ $x -lt 1 ] && break; sleep 120; x=$((x-1))
      done
    fi

    log "    build_debs ( ) #8"

    log "##################### COW UPDATE #######################"

    local x=30
    local opts="--override-config"
    $keep_pbuilder_config && opts=""
    
    while ! cow --update $opts; do
      [ $x -lt 1 ] && break; sleep 120; x=$((x-1))
    done


    log "################# HOOKS #################################"

    if $debug_hook; then
      mkdir -p .hooks
      fmt_debug_hook > .hooks/C10shell
      chmod +x .hooks/C10shell
      hookdir=$(pwd)/.hooks
    fi
    
    export BINDMOUNTS="/build/deb"
    fmt_apt_update_hook > .hooks/D70results
    chmod +x .hooks/D70results
    fmt_apt_update_hook > .hooks/H70results
    chmod +x .hooks/H70results

    # libks install hook
    libks_install_hook > .hooks/A10libks
    chmod +x .hooks/A10libks
    
    log "##################### COW BUILD #######################"
    
    cow --build $dsc \
              --hookdir "$hookdir" \
              --bindmounts /build/deb \
              --buildresult /build/ \
              $cow_build_opts


    if [ ! -e "$custom_keyring" ]; then
      # Cleanup script created temporary file
      rm -f $keyring
    fi
  } 1>&2
  echo ${dsc%.dsc}_${arch}.changes

  log "<-# build_debs ( ) [${dsc%.dsc}_${arch}.changes]"
}

default_distros () {
  local host_distro="Debian"
  test -z "$(which lsb_release)" || host_distro="$(lsb_release -is)"
  case "$host_distro" in
    Debian) echo "sid stretch jessie" ;;
    Ubuntu) echo "utopic trusty" ;;
    *) err "Unknown host distribution \"$host_distro\"" ;;
  esac
}

build_ubnt_debs ()
{
    local arch="$1"
    echo "#-> build_ubnt_debs [${0}] [${1}] [${2}] arch=${arch}"
cat <<EOT > ${HOME}/.pbuilderrc
PBUILDERSATISFYDEPENDSCMD=/usr/lib/pbuilder/pbuilder-satisfydepends-experimental
HOOKDIR="/var/cache/pbuilder/hook.d"
export DH_VERBOSE=1
EOT
    ln -s -f /usr/lib/pbuilder/pbuilder-satisfydepends-experimental /usr/lib/pbuilder/pbuilder-satisfydepends
    aptitude install -y rsync git less cowbuilder ccache devscripts equivs build-essential yasm
    local orig="$(create_orig )"
    local dsc="$(create_dsc stretch $orig )"
    local changes="$(build_debs stretch $dsc ${arch})"
    echo "<-# build_ubnt_debs"
}

build_all () {
    log "#-> build_all ( ) "
  local OPTIND OPTARG
  local orig_opts="" dsc_opts="" deb_opts="" modlist=""
  local archs="" distros="" orig="" depinst=false par=false
  while getopts 'a:bc:df:ijkK:l:m:no:p:s:tT:u:v:z:' o "$@"; do
    case "$o" in
      a) archs="$archs $OPTARG";;
      b) orig_opts="$orig_opts -b";;
      c) distros="$distros $OPTARG";;
      d) deb_opts="$deb_opts -d";;
      f) dsc_opts="$dsc_opts -f$OPTARG";;
      i) depinst=true;;
      j) par=true;;
      k) deb_opts="$deb_opts -k";;
      K) deb_opts="$deb_opts -K$OPTARG";;
      l) modlist="$OPTARG";;
      m) orig_opts="$orig_opts -m$OPTARG"; dsc_opts="$dsc_opts -m$OPTARG";;
      n) orig_opts="$orig_opts -n";;
      o) orig="$OPTARG";;
      p) dsc_opts="$dsc_opts -p$OPTARG";;
      s) dsc_opts="$dsc_opts -s$OPTARG";;
      t) deb_opts="$deb_opts -t";;
      T) deb_opts="$deb_opts -T$OPTARG";;
      u) dsc_opts="$dsc_opts -u$OPTARG";;
      v) orig_opts="$orig_opts -v$OPTARG";;
      z) orig_opts="$orig_opts -z$OPTARG"; dsc_opts="$dsc_opts -z$OPTARG";;
    esac
  done
  shift $(($OPTIND-1))
  [ -n "$archs" ] || archs="amd64 i386"
  [ -n "$distros" ] || distros="$(default_distros)"
    log "    build_all ( ) #1"

  ! $depinst || aptitude install -y \
    rsync git less cowbuilder ccache \
    devscripts equivs build-essential yasm
  [ -n "$orig" ] || orig="$(create_orig $orig_opts HEAD | tail -n1)"
    # echo "    build_all ( ) #2"
  if [ -n "$modlist" ]; then
    local modtmp="$(mktemp /tmp/modules-XXXXXXXXXX.conf)"
    > $modtmp
    for m in "$modlist"; do printf '%s\n' "$m" >> $modtmp; done
    dsc_opts="$dsc_opts -f${modtmp}"; fi
  [ -n "$orig" ] || orig="$(create_orig $orig_opts HEAD | tail -n1)"
  mkdir -p ../log
  > ../log/changes.txt
  echo; echo; echo; echo
  trap 'echo "Killing children...">&2; for x in $(jobs -p); do kill $x; done' EXIT
  if [ "${orig:0:2}" = ".." ]; then
    echo "true" > ../log/builds-ok.txt
    for distro in $distros; do
      echo "Creating $distro dsc..." >&2
      local dsc="$(create_dsc $dsc_opts $distro $orig 2>../log/$distro.txt | tail -n1)"
      echo "Done creating $distro dsc." >&2
      if [ "${dsc:0:2}" = ".." ]; then
        local lopts="-b"
        for arch in $archs; do
          {
            echo "Building $distro-$arch debs..." >&2
            local changes="$(build_debs $lopts $deb_opts $distro $dsc $arch 2>../log/$distro-$arch.txt | tail -n1)"
            echo "Done building $distro-$arch debs." >&2
            if [ "${changes:0:2}" = ".." ]; then
              echo "$changes" >> ../log/changes.txt
            else
              echo "false" > ../log/builds-ok.txt
            fi
          } &
          $par || wait
          lopts="-B"
        done
      fi
    done
    ! $par || wait
  fi
  [ -z "$modlist" ] || rm -f $modtmp
  trap - EXIT
  cat ../log/changes.txt
  test "$(cat ../log/builds-ok.txt)" = true || exit 1
    # echo "<-# build_all ( ) "
}

usage () {
  cat >&2 <<EOF
$0 [opts] [cmd] [cmd-opts]

options:

  -d Enable debugging mode.

commands:

  archive-orig

  build-all

    [ This must be run as root! ]

    -a Specify architectures
    -c Specify distributions
    -d Enable cowbuilder debug hook
    -f <modules.conf>
      Build only modules listed in this file
    -i Auto install build deps on host system
    -j Build debs in parallel
    -k Don't override pbuilder image configurations
    -K [/path/to/keyring.asc]
       Use custom keyring file for sources.list in build environment
       in the format of: apt-key exportall > /path/to/file.asc
    -l <modules>
    -m [ quicktest | non-dfsg ]
      Choose custom list of modules to build
    -n Nightly build
    -o <orig-file>
      Specify existing .orig.tar.xz file
    -p <module>
      Include otherwise avoided module
    -s [ paranoid | reckless ]
      Set FS bootstrap/build -j flags
    -t Use system /etc/apt/sources.list in build environment(does not include /etc/apt/sources.list.d/*.list)
    -T [/path/to/sources.list]
       Use custom /etc/apt/sources.list in build environment
    -u <suite-postfix>
      Specify a custom suite postfix
    -v Set version
    -z Set compression level

  build-debs <distro> <dsc-file> <architecture>

    [ This must be run as root! ]

    -B Binary architecture-dependent build
    -b Binary-only build
    -d Enable cowbuilder debug hook
    -k Don't override pbuilder image configurations
    -K [/path/to/keyring.asc]
       Use custom keyring file for sources.list in build environment
       in the format of: apt-key exportall > /path/to/file.asc
    -t Use system /etc/apt/sources.list in build environment
    -T [/path/to/sources.list]
       Use custom /etc/apt/sources.list in build environment

  create-dbg-pkgs

  create-dsc <distro> <orig-file>

    -f <modules.conf>
      Build only modules listed in this file
    -m [ quicktest | non-dfsg ]
      Choose custom list of modules to build
    -p <module>
      Include otherwise avoided module
    -s [ paranoid | reckless ]
      Set FS bootstrap/build -j flags
    -u <suite-postfix>
      Specify a custom suite postfix
    -z Set compression level

  create-orig <treeish>

    -m [ quicktest | non-dfsg ]
      Choose custom list of modules to build
    -n Nightly build
    -v Set version
    -z Set compression level

EOF
  exit 1
}

while getopts 'dh' o "$@"; do
  case "$o" in
    d) set -vx;;
    h) usage;;
  esac
done
shift $(($OPTIND-1))

cmd="$1"; [ -n "$cmd" ] || usage
shift
case "$cmd" in
  archive-orig) archive_orig "$@" ;;
  build-all) build_all "$@" ;;
  build-debs) build_debs "$@" ;;
  create-dbg-pkgs) create_dbg_pkgs ;;
  create-dsc) create_dsc "$@" ;;
  create-orig) create_orig "$@" ;;
  build-ubnt-debs) build_ubnt_debs "$@" ;;
  *) usage ;;
esac
