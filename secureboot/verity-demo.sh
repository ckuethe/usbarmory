#!/bin/sh

DEV="/dev/loop0p1"
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

# attach this device to /dev/mapper/usbarmory_verity
veritysetup $DISKPARAMS create usbarmory_verity $DEV $DEV $ROOT_HASH

# lookeeee!! it works!
veritysetup status usbarmory_verity

# detach the mapper volume
veritysetup remove usbarmory_verity

# print out the superblock
veritysetup $DISKPARAMS dump $DEV

# and manually verify the partition. include the command to do it at will
CMD="veritysetup -v $DISKPARAMS verify $DEV $DEV $ROOT_HASH"
echo $CMD >> $PARAMS
$CMD

echo "please save '$PARAMS' - it contains important information about your verity volume"
