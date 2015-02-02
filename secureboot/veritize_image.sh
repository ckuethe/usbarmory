#!/bin/sh

# this looks a lot like verity_sdcard.sh, but it takes a single partition
# sdcard image and emits a verity image (and root hash) with a resized root
# partition suitable for use as the lower partition of an overlayfs 

if [ $# -eq 1 -a "x$1" = "x-h" ] ; then
	echo "usage: $0 <infile> <outfile>"
	exit 1
fi

FILE=$1
if [ ! -f $FILE ] ; then
	echo "missing input file"
	exit 1
fi

#XXX check to see if file is already attached

# https://bugs.freedesktop.org/show_bug.cgi?id=56703
LOOP=$(losetup --find --show --partscan $FILE)

MAXPART=$(parted $LOOP --script --machine print | grep "^[0-9]*:" |cut -d: -f1 | sort -n)
if [ $MAXPART -ne 1 ] ; then
	echo "unexpected number of partitions ($MAXPART) - aborting"
	losetup --detach ${LOOP}
	exit 1;
fi

DEV="${LOOP}p1"
fsck -p $DEV
e2label $DEV usbarmory_verity


#wipe free space
#TARGET=$(mktemp -p . -d mount_XXXXXXXXXX)
#mount $DEV $TARGET
#ZERO=$(mktemp -p $TARGET tmpXXXXXXXXX)
#dd if=/dev/zero of=$ZERO bs=1M
#rm -f $ZERO
#umount $TARGET
#rmdir $TARGET

# shrink filesystem
e2fsck -f $DEV
BLK_FSLEN=$(resize2fs -M $DEV 2>&1 | grep "blocks long" | cut -d ' ' -f5)
SEC_FSLEN=$(( $BLK_FSLEN * 8 ))
PART_INFO=$(parted $LOOP --script --machine unit s print | tail -1)
PART_TYPE=$(echo $PART_INFO | cut -d : -f 5)
SEC_PART_START=$(echo $PART_INFO | cut -d : -f 2 | tr -dc '0-9')
SEC_PART_END=$(( $SEC_PART_START + $SEC_FSLEN ))

# can't shrink partitions, so gotta delete and add. Fffffuuuuuuuuuuu....
parted $LOOP --script mklabel msdos
parted $LOOP --script unit s mkpart primary $PART_TYPE $SEC_PART_START $SEC_PART_END
partprobe $LOOP

# figure out how much space is needed for the hash tree
HASH_TEMP=$(mktemp tmp.hash.XXXXXXXXXX)
HASH_INFO=$(mktemp tmp.info.XXXXXXXXXX)
veritysetup -v format $DEV $HASH_TEMP > $HASH_INFO
BLOCK_SIZE=$(grep "Data block size:" $HASH_INFO | sed -e 's/.*:[[:blank:]]*//')
BLK_DATALEN=$(grep "Data blocks:" $HASH_INFO | sed -e 's/.*:[[:blank:]]*//')
SEC_HASHLEN=$(env BLOCKSIZE=500 du $HASH_TEMP | cut -f 1)
#rm -f $HASH_TEMP $HASH_INFO

if [ $BLK_FSLEN -ne $BLK_DATALEN ] ; then
	echo "woopsy, math error: $BLK_FSLEN != $BLK_DATALEN"
	losetup --detach $LOOP
	exit 1
fi

echo "Data end sector $SEC_PART_END"
# compute size of larger partition to make room for hash tree
SEC_HASH_OFFSET=$(( $SEC_PART_END + 8 ))
echo "hash start sector $SEC_HASH_OFFSET"
BYTE_HASH_OFFSET=$(( $SEC_HASH_OFFSET * 512 ))
echo "hash start byte $BYTE_HASH_OFFSET"
echo "Hash size $SEC_HASHLEN sectors"
SEC_PART_END=$(( $SEC_HASH_OFFSET + $SEC_HASHLEN + 32 ))
echo "hash end sector $SEC_PART_END"

#resize image
parted $LOOP --script unit s resizepart 1 $SEC_PART_END
partprobe $LOOP
env BLOCKSIZE=512 truncate -o -s $SEC_PART_END $FILE 

DISKPARAMS="--hash-offset=$BYTE_HASH_OFFSET --data-blocks=$BLK_DATALEN"
HASH_INFO=$(mktemp tmp.verityinfo_$(basename $DEV).XXXXXXXXXX)
date >> $HASH_INFO

# using resized filesystem, build the hash tree at the end of the partition
veritysetup $DISKPARAMS format $DEV $DEV >> $HASH_INFO
ROOT_HASH=$(grep "Root hash:" $HASH_INFO | sed -e 's/.*:[[:blank:]]*//')

# and manually verify the partition. include the command to do it at will
CMD="veritysetup -v $DISKPARAMS verify $DEV $DEV $ROOT_HASH"
echo $CMD >> $HASH_INFO
$CMD
losetup --detach $LOOP

echo "please save '$HASH_INFO' - it contains important information about your verity volume"
