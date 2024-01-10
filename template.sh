#!/bin/bash
if [ "$(whoami)" != "root" ]; then
  echo "please run this script '$0' as root." >&2
  exit 1
fi

read -r -d '' docs <<- EOF
Usage:
    $0 [OPTIONS]

Options:
    -b, --bind src:dst    bind directory
    -d, --debug           enter debug mode
    -e, --env var[=val]   environment variable
    -h, --help            display this help and exit
    -o, --overlay path    set directory for overlayfs (default: tmpfs)
    -t, --tmpsz xxM|xxG   set tmpfs size for overlayfs (default: 128M)
    -v, --verbose         display script options and actions (for script debug only)

Example:
    $0
    $0 --bind /host/path/0:/client/path/0 --bind /host/path/1:/client/path/1
    $0 --env ENV0=value0 --env ENV1=value1 
    $0 --overlay /path/to/overlay
    $0 --tmpsz 16M
    $0 --debug
EOF
usage() {
  echo "$docs" >&2
  exit 1
}

error() {
  if [[ -n $1 ]]; then echo "$0: $1" >&2; fi
  echo "See '$0 --help'." >&2
  exit 1
}

checkopt() {
  if [[ $2 =~ ^- ]] || [ -z $2 ]; then
    error "option '$1' requires an argument"
  fi
}

ARGS=`getopt -o b:de:ho:t:v -l bind:,debug,env:,help,overlay:,tmpsz:,verbose -n "$0" -- "$@"`
if [ $? -ne 0 ]; then
  error
fi
eval set -- "${ARGS}"
while true
do
  case "$1" in
    -b|--bind)
      checkopt "-b/--bind" $2
      bind=(${2//:/ })
      if [[ ${#bind[@]} -ne 2 ]]; then
        error "invalid bind"
      fi
      if ! ([[ -d ${bind[0]} ]] || [[ -f ${bind[0]} ]]); then
        error "bind source '${bind[0]}' not exist"
      fi
      binds[${#binds[@]}]=$2
      shift 2
      ;;
    -d|--debug)
      debug=true
      shift
      ;;
    -e|--env)
      checkopt "-b/--bind" $2
      if ! [[ $2 =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.*$ ]]; then
        error "invalid env definition '$2'"
      fi
      envs[${#envs[@]}]=$2
      shift 2
      ;;
    -h|--help)
      usage
      shift
      ;;
    -o|--overlay)
      checkopt "-o/--overlay" $2
      if ! [[ -d $2 ]]; then
        error "overlay '$2' not exist"
      fi
      overlay=$2
      shift 2
      ;;
    -t|--tmpsz)
      checkopt "-t/--tmpsz" $2
      if ! [[ "$2" =~ ^[0-9]+[MGmg]$ ]]; then
        error "invalid tmpsz"
      fi
      tmpsz=$2
      shift 2
      ;;
    -v|--verbose)
      verbose=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Internal error!"
      exit 1
      ;;
  esac
done

if [[ -z $debug ]]; then
  debug=false
fi

if [[ -z $tmpsz ]]; then
  tmpsz=128M
fi

if [[ -z $verbose ]]; then
  verbose=false
fi

if [[ $verbose = true ]]; then
  echo "debug=$debug"
  echo "binds=[${binds[@]}]"
  echo "envs=[${envs[@]}]"
  echo "overlay=$overlay"
  echo "tmpsz=$tmpsz"
  echo "verbose=$verbose"
  set -x
fi

pbinds() {
  local binds=("$@")
  for i in $(seq -s ' ' 0 $((${#binds[@]} - 1))); do
    bind=${binds[i]}
    bind=(${bind//:/ })
    echo mount -o rbind ${bind[0]} $dirws/rootfs/${bind[1]}
  done
}

penvs() {
  local envs=("$@")
  for i in $(seq -s ' ' 0 $((${#envs[@]} - 1))); do
    echo -n ${envs[i]} ''
  done
}

offset=$(sed -n "1,$(awk '/^exit 0$/{print NR; exit}' $0)p" $0 | wc -c)
dirws=$(mktemp -d)
trap "rm -r $dirws" EXIT
unshare -mpf --mount-proc /bin/bash -c "
if [[ '$verbose' = true ]]; then set -x; fi
mount -o bind,ro $0 $0
mount -t tmpfs -o size=$tmpsz tmpfs $dirws
mkdir -p $dirws/squashfs $dirws/overlay $dirws/rootfs
if [[ -n '$overlay' ]]; then mount -o bind $overlay $dirws/overlay; fi
mkdir -p $dirws/overlay/upper $dirws/overlay/work
mount -o offset=$offset,ro $0 $dirws/squashfs
mount -t overlay overlay -o lowerdir=$dirws/squashfs,upperdir=$dirws/overlay/upper,workdir=$dirws/overlay/work $dirws/rootfs
mount -t proc /proc $dirws/rootfs/proc
mount -t sysfs /sys $dirws/rootfs/sys
mount -o rbind /dev $dirws/rootfs/dev
mkdir -p $dirws/rootfs/tmp/.X11-unix
mount -o bind /tmp/.X11-unix $dirws/rootfs/tmp/.X11-unix
mount -o bind,ro /etc/resolv.conf $dirws/rootfs/etc/resolv.conf
mount -o bind,ro /etc/hostname $dirws/rootfs/etc/hostname
mount -o bind,ro /etc/hosts $dirws/rootfs/etc/hosts
$(pbinds ${binds[@]})
if [[ '$debug' = true ]]; then
  chroot $dirws/rootfs /bin/env -i TERM=$TERM DISPLAY=$DISPLAY $(penvs ${envs[@]}) /bin/su <user> -l -s /bin/bash
else
  chroot $dirws/rootfs /bin/env -i TERM=$TERM DISPLAY=$DISPLAY $(penvs ${envs[@]}) /bin/su <user> -l --session-command <app>
fi
"

exit 0
