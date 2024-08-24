#!/bin/bash

# https://wiki.debian.org/ManipulatingISOs#remaster
# not sure how to make it boot "universally"?

usage() {
    echo
    echo "Usage: $0 debian-image"
}

set -euxo pipefail

DIR=$(mktemp -d)
DEBBIE=$1
MBR_TEMPLATE=$DIR/isohdpfx.bin

chmod -R +w $DIR

mkdir -p output

# Extract MBR template file to disk
dd if="$DEBBIE" bs=1 count=432 of="$MBR_TEMPLATE"

# open her up
xorriso -osirrox on -indev $DEBBIE -extract / $DIR

# repack her
cp preseed.cfg $DIR

# next, we have to tell the kernel to use the preseed by appending cmdline args
# we have to edit a series of files -- starting with isolinux.cfg, which sequentially imports gtk.cfg, txt.cfg, and menu.cfg.
# we will strip the graphical installer option imported in gtk.cfg, and set the timeout to 50ds instead of the default (no automatic choice)
# the menu entries look like the default contents of isolinux/txt.cfg:

# label install
#     menu label ^Install
#     kernel /install.amd/vmlinuz
#     append vga=788 initrd=/install.amd/initrd.gz --- quiet 

# (--- is a delimiter between args passed to the kernel cmdline and the initrd cmdline)

# set a 50 decisecond timeout:
sed -i 's/timeout 0/timeout 50/' $DIR/isolinux/isolinux.cfg

# enable the prompt (this enables auto timeout)
sed -i 's/prompt 0/prompt 1/' $DIR/isolinux/isolinux.cfg

# set the install menu entry in txt.cfg as default:
sed -i '1i\default install' $DIR/isolinux/txt.cfg

# inject kernel params into txt.cfg's default install menu entry:
KERNEL_PARAMS='auto=true priority=critical locale=en_US.UTF-8 keymap=us file=/cdrom/preseed.cfg DEBCONF_DEBUG=5'
sed -i "/append/ s|append|append $KERNEL_PARAMS|" $DIR/isolinux/txt.cfg

# next, remove the graphical install option which is also set as default in gtk.cfg by editing it out of menu.cfg:
sed -i '/include gtk.cfg/d' $DIR/isolinux/menu.cfg

# remove unused gtk.cfg.
rm $DIR/isolinux/gtk.cfg

# pathetic creature of flesh and bone
# cp splash.png $DIR/isolinux/splash.png

# /path/to/debian-12.6.0-amd64-netinst.iso -> 12.6.0
# accounts for - in the path
SEMVER=$(echo $DEBBIE | rev | cut -d'-' -f 3 | rev)
# e.g. amd64
ARCH=$(echo $DEBBIE | rev | cut -d'-' -f 2 | rev)

DEB=$(basename $DEBBIE)
DEB="${DEB%.*}"

xorriso -as mkisofs \
    -r -V "Debian $SEMVER $ARCH n" \
    -o "output/$DEB-repacked.iso" \
    -J -J -joliet-long -cache-inodes \
    -isohybrid-mbr "$MBR_TEMPLATE" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 -boot-info-table -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
    "$DIR"

# rm -r $DIR
