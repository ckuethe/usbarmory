#!/bin/sh

###########################################################################
## Configuration
SUITE="wheezy"
ARCH="armel"
MIRROR="https://mirrors.kernel.org/debian/"
PACKAGES="ssh,dmsetup,cryptsetup,cryptsetup-bin,tcc,ecryptfs-utils"
TARBALL="${PWD}/wheezy-packages.tgz"
TARGET="/tmp/root"

mkdir -p $TARGET

set -e
set -x

###########################################################################
if true ; then ### Make the disk image
FILE="Q_sbarmory-big.img"
dd if=/dev/zero of=$FILE bs=1024k count=4
truncate --size=2G $FILE

LOOP=$(losetup --find --show $FILE)
parted $LOOP --script mklabel msdos
parted $LOOP --script mkpart primary ext4 2M 512M
parted $LOOP --script mkpart primary ext4 512M 2G

dd if=/dev/zero of=${LOOP}p1 bs=1024k count=1
dd if=/dev/zero of=${LOOP}p2 bs=1024k count=1

mkfs.ext4 -L usbarmory_verity ${LOOP}p1
mount ${LOOP}p1 $TARGET
mkdir ${TARGET}/.overlay
mkfs.ext4 -L usbarmory_rw ${LOOP}p2
mount ${LOOP}p2 ${TARGET}/.overlay
fi

###########################################################################
if false ; then ## Generate package tarball
qemu-debootstrap $SUITE $TARGET $MIRROR \
	--make-tarball=$TARBALL \
	--include=$PACKAGES --arch=$ARCH \
	--components=main,non-free,contrib
fi

###########################################################################
if false ; then ## Install the base OS
qemu-debootstrap $SUITE $TARGET $MIRROR \
	--unpack-tarball=$TARBALL \
	--include=$PACKAGES --arch=$ARCH \
	--components=main,non-free,contrib
fi

###########################################################################
if false ; then ## Local filesystem patches
chroot $TARGET passwd -d root
echo 'usbarmory' > ${TARGET}/etc/hostname
printf "export LANG=C\nexport LC_ALL=C" >> ${TARGET}/etc/profile
mkdir ${TARGET}/.overlay
ln -s /proc/mounts ${TARGET}/etc/mtab
cat >> ${TARGET}/etc/fstab << EOF
/dev/mmcblk0p1 /                  ext4      ro,verify,suid,exec,auto,nouser,async 0 0
/dev/mmcblk0p2 /.overlay          ext4      rw,suid,exec,auto,nouser,async 1 1
none           /                  overlayfs lowerdir=/,upperdir=/.overlay  0 0
none           /proc              procfs    defaults                       0 0
none           /sys               sysfs     defaults                       0 0
none           /sys/kernel/config configfs  defaults                       0 0
EOF

tar -C $TARGET -zcf rootfs.tgz .
fi

###########################################################################
if false ; then ## tar up the final root image
tar -C $TARGET -zxf rootfs.tgz
fi

umount ${LOOP}p2
umount ${LOOP}p1

###########################################################################
# ripped right out of verity-demo.sh
DEV="${LOOP}p1"
# create the hash table in a separate file
HASH_TEMP=$(mktemp hashesXXXXXXXXXX)
PARAMS=$(mktemp verityXXXXXXXXXX)

# figure out how much space is needed for the hash tree
veritysetup -v format $DEV $HASH_TEMP > $PARAMS
BLOCK_SIZE=$(grep "Data block size:" $PARAMS | sed -e 's/.*:[[:blank:]]*//')
DATA_BLOCKS=$(grep "Data blocks:" $PARAMS | sed -e 's/.*:[[:blank:]]*//')
HASH_BLOCKS=$(env BLOCKSIZE=$BLOCK_SIZE ls -s $HASH_TEMP | cut -f 1 -d ' ')
rm -f $HASH_TEMP $PARAMS

# compute size of shrunken filesystem to make room for hash tree
NEW_FS_BLOCKS=$(( $DATA_BLOCKS - $HASH_BLOCKS - 2 ))
NEW_FS_BYTES=$(( $NEW_FS_BLOCKS * $BLOCK_SIZE ))
NEW_FS_SIZE=$(( $NEW_FS_BYTES / 1024 ))
HASH_OFFSET=$(( $NEW_FS_BYTES + 4096 ))

# resize filesystem to make room for hash tree
umount -f $DEV
e2fsck -f $DEV
resize2fs $DEV ${NEW_FS_SIZE}K
e2fsck -f $DEV

DISKPARAMS="--hash-offset=$HASH_OFFSET --data-blocks=$NEW_FS_BLOCKS"
PARAMS="$(basename $DEV)_verity.txt"

# using resized filesystem, build the hash tree at the end of the partition
veritysetup $DISKPARAMS format $DEV $DEV >> $PARAMS
ROOT_HASH=$(grep "Root hash:" $PARAMS | sed -e 's/.*:[[:blank:]]*//')

# and manually verify the partition. include the command to do it at will
CMD="veritysetup -v $DISKPARAMS verify $DEV $DEV $ROOT_HASH"
echo $CMD >> $PARAMS
$CMD

echo "please save '$PARAMS' - it contains important information about your verity volume"
