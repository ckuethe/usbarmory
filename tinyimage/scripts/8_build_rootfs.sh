#!/bin/sh

cd out
FS=tinyimage

sudo rm ${FS}.*
#Assemble all of the packages into a filesystem
tar -cf ${FS}.tar -C dir_linux .
tar -rf ${FS}.tar -C dir_uboot .
tar -rf ${FS}.tar -C dir_busybox .
tar -rf ${FS}.tar -C dir_dropbear .
tar -rf ${FS}.tar -C ../config/overlay .

SZ=$(du --block-size 1M ${FS}.tar | cut -f 1)
SZ=$(( $SZ + 4 ))

rm -f $FS.ext4
truncate --size ${SZ}M $FS.ext4

sudo id
LOOP=$(sudo losetup --find --show $FS.ext4)
sudo parted $LOOP --script mklabel msdos
sudo parted $LOOP --script mkpart primary ext4 1M 100%
sudo dd if=dir_uboot/boot/u-boot.imx of=$LOOP bs=512 seek=2

sudo mkfs.ext4 -L usbarmory ${LOOP}p1 
rm -rf mnt
mkdir mnt
sleep 3
sudo umount ${LOOP}p1 # because ubuntu will helpfully mount this in the wrong place
sudo mount ${LOOP}p1 mnt

sudo tar -C mnt -xf ${FS}.tar
sudo mkdir -p mnt/dev mnt/proc mnt/sys mnt/tmp mnt/var
sudo chown -R root:root mnt
sudo chmod 04555 mnt/bin/busybox
sudo chmod 01777 mnt/tmp

#sudo mkcramfs -n usbarmory /mnt ${FS}.cramfs
sudo mksquashfs mnt ${FS}.squashfs -all-root
(cd mnt ; sudo find . | sudo cpio --create --format='newc') | gzip > $FS.cpio.gz

#i know, this reads like "goto fail ; goto fail;"
sudo umount ${LOOP}p1
sudo umount ${LOOP}p1
sudo losetup -d $LOOP

xz < $FS.ext4 > $FS.ext4.xz
bzip2 < $FS.ext4 > $FS.ext4.bz2
gzip < $FS.ext4 > $FS.ext4.gz

#sudo dd if=$FS.ext4 of=/dev/sdb bs=128k
