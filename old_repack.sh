set -euxo pipefail

DIR=$(mktemp -d)
DEBBIE=$1
PRESEED=$2


# open her up
#cat $DEBBIE | bsdtar -C $DIR -xf -
xorriso -osirrox on -indev $DEBBIE -extract / $DIR
chmod -R +w $DIR

# repack her
cp $PRESEED $DIR

# bash moment
# appending these after the "--- quiet" block passes them to the inird instead of the kernel
INITRD_PARAMS="priority=high file=\/cdrom\/preseed.cfg"
sed -i "/append/s/\$/ $INITRD_PARAMS/" $DIR/isolinux/txt.cfg

# ungodly genisoimage block
genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o preseeded-debbie.iso $DIR

isohybrid preseeded-debbie.iso
