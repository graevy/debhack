#!/bin/bash

# https://wiki.debian.org/ManipulatingISOs#remaster
# basically i just read this page and then copied most of the relevant commands
# not sure how to make it boot "universally"?

usage() {
    echo
    echo "Usage: $0 debian-image files-to-add"
}

set -euxo pipefail

DIR=$(mktemp -d)
DEBBIE=$1
PRESEED=$2
MBR_TEMPLATE=$DIR/isohdpfx.bin

chmod -R +w $DIR

mkdir -p output

# Extract MBR template file to disk
dd if="$DEBBIE" bs=1 count=432 of="$MBR_TEMPLATE"

# open her up
#cat $DEBBIE | bsdtar -C $DIR -xf -
xorriso -osirrox on -indev $DEBBIE -extract / $DIR

# repack her
cp $PRESEED $DIR

# tell the ramdisk to use the preseed?
# appending these after the "--- quiet" block passes them to the inird instead of the kernel
INITRD_PARAMS="priority=high locale=en_US.UTF-8 keymap=us file=\/cdrom\/preseed.cfg"
sed -i "/append/s/\$/ $INITRD_PARAMS/" $DIR/isolinux/txt.cfg

# /path/to/debian-12.6.0-amd64-netinst.iso -> 12.6.0
# accounts for - in the path
SEMVER=$(echo $DEBBIE | rev | cut -d'-' -f 3 | rev)
# e.g. amd64
ARCH=$(echo $DEBBIE | rev | cut -d'-' -f 2 | rev)

#DEB=$(basename $DEBBIE)
#DEB="${BASENAME%.*}"

xorriso -as mkisofs \
    -r -V "Debian $SEMVER $ARCH n" \
    -o "output/debian-$SEMVER-$ARCH-the-sequel.iso" \
    -J -J -joliet-long -cache-inodes \
    -isohybrid-mbr "$MBR_TEMPLATE" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 -boot-info-table -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
    "$DIR"

rm -r $DIR
