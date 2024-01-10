#!/bin/bash

read -r -d '' docs <<- EOF
Usage:
    $0 EXE ROOTFS APP [USER]

  EXE:    output executable file
  ROOTFS: rootfs path
  APP:    application to run
  USER:   run at specific user (default: root)
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

if [[ $# -ne 3 ]] && [[ $# -ne 4 ]]; then
  usage
fi

exe=$1
if [[ -f $exe ]]; then
  rm -f $exe
fi

rootfs=$2
if ! [[ -d $rootfs ]]; then
  error "rootfs '$rootfs' not exist"
fi

app=$3

user=$4
if [[ -z $user ]]; then
  user=root
fi

sudo tar cf - $rootfs | mksquashfs - $exe -tar -comp zstd
{ cat template.sh | sed -e "s/<user>/$user/g" -e "s/<app>/${app//\//\\/}/g"; cat $exe; } > $exe.tmp
mv $exe.tmp $exe
chmod +x $exe