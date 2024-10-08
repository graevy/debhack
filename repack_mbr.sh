#!/bin/bash

# https://wiki.debian.org/ManipulatingISOs#remaster

usage() {
    echo
    echo "Usage: $0 debian-image"
}

set -euxo pipefail

DIR=$(mktemp -d ./tmp.XXXXXXXX)
DEBBIE=$1
MBR_TEMPLATE=$DIR/isohdpfx.bin

mkdir -p output

# extract debbie
xorriso -osirrox on -indev $DEBBIE -extract / $DIR

# backup permissions
PERMS=$(mktemp ./tmp.XXXXXX)
chmod +w $PERMS
find $DIR -exec stat --format '%a %n' {} \; > $PERMS

# make it all writable
chmod -R 777 $DIR

# extract MBR template file to disk. scariest hardcode of my life
dd if="$DEBBIE" bs=1 count=432 of="$MBR_TEMPLATE"

# repack her
cp preseed.cfg $DIR

# insert the disclaimer
cp DONTBOOT $DIR

# so, the debian installer starts with isolinux.cfg and then includes other cfg files which are parsed in-place
# once the installer enters a menu option, the kernel is booted and if the installation fails, we return to the menu
# here is an example menu option, the install entry in isolinux/txt.cfg:

# label install
#     menu label ^Install
#     kernel /install.amd/vmlinuz
#     append vga=788 initrd=/install.amd/initrd.gz --- quiet 

# (--- is a delimiter between args passed to the kernel cmdline and the initrd cmdline)

# i shove the preseed in either the initrd or the installer filetree to have the fewest moving parts
# installer filetree seems the most intuitive so i pass the cmdline arg to the kernel to load the preseed here
# the initrd doesn't require args like this, but the newer kernels are self-booting so here we are
KERNEL_PARAMS='auto=true priority=critical locale=en_US.UTF-8 keymap=us file=/cdrom/preseed.cfg'

ISOLINUX=$DIR/isolinux
# set a 50 decisecond timeout for whatever the default menu entry is:
sed -i 's/timeout 0/timeout 50/' $ISOLINUX/isolinux.cfg

# set the install menu entry in txt.cfg as default:
sed -i '1i\default install' $ISOLINUX/txt.cfg

# insert kernel params into txt.cfg's default install menu entry:
sed -i "/append/ s|append|append $KERNEL_PARAMS|" $ISOLINUX/txt.cfg

# if one of the installer imports doesn't exist, the import just doesn't happen and we proceed as normal;
# remove the default graphical install/speech synthesis/dark contrast options,
# which contain defaults/timeouts that will interfere with autoselecting `install`
rm -f $ISOLINUX/gtk.cfg $ISOLINUX/spkgtk.cfg $ISOLINUX/spk.cfg $ISOLINUX/drk.cfg $ISOLINUX/drkgtk.cfg

# could also extract the includes from their files?
# sed -i '/include gtk.cfg/d' $DIR/isolinux/menu.cfg
# sed -i '/include spkgtk.cfg/d' $DIR/isolinux/menu.cfg
# sed -i '/include spk.cfg/d' $DIR/isolinux/menu.cfg

# pathetic creature of meat and bone
# cp backgrounds/splash.png $DIR/isolinux/splash.png

# restore old permissions
while IFS=' ' read -r perm file; do
    if [ -e "$file" ]; then
        chmod "$perm" "$file"
    fi
done < $PERMS

# /path/to/debian-12.6.0-amd64-netinst.iso -> debian-12.6.0-amd64-netinst
DEB=$(basename $DEBBIE)
DEB="${DEB%.*}"

# afaict, including semver/arch in the volume name is just for autodetection standards
SEMVER=$(echo $DEB | cut -d'-' -f 2)
ARCH=$(echo $DEB | cut -d'-' -f 3)

OUTPUT=output/$DEB-repacked.iso

# absolutely arcane. most of the flags are explained at the link at the top of the file
xorriso -as mkisofs \
    -r -V "Debian $SEMVER $ARCH n" \
    -o $OUTPUT \
    -J -J -joliet-long -cache-inodes \
    -isohybrid-mbr "$MBR_TEMPLATE" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 -boot-info-table -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
    "$DIR"

rm $PERMS
rm -r $DIR
