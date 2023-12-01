#!/bin/bash
if [ "$(whoami)" != "root" ]; then
    echo "please run this script '$0' as root."
    exit 1
fi
dir=$(mktemp -d)
trap "rm -r $dir" EXIT
offset=$(sed -n "1,$(awk '/^exit 0$/{print NR; exit}' $0)p" $0 | wc -c)
unshare --mount /bin/bash -c "
mount -t tmpfs -o size=128M tmpfs $dir
mkdir -p $dir/squashfs $dir/overlay/upper $dir/overlay/work $dir/rootfs
mount -o offset=$offset $0 $dir/squashfs
mount -t overlay overlay -o lowerdir=$dir/squashfs,upperdir=$dir/overlay/upper,workdir=$dir/overlay/work $dir/rootfs
mount -t proc /proc $dir/rootfs/proc
mount -t sysfs /sys $dir/rootfs/sys
mount -o rbind /dev $dir/rootfs/dev
mount -o bind,ro /etc/resolv.conf $dir/rootfs/etc/resolv.conf
chroot $dir/rootfs /bin/bash $@
"
exit 0
