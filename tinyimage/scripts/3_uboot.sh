#!/bin/sh

# from the uboot source directory, build uboot and install it
# into /tmp/dir_uboot. Do this as non-root so that you can't break
# your host system. The target directory can be overlaid with other
# packages (like linux and busybox) to produce a root filesystem

DIR=${PWD}/out/dir_uboot
cd src/u-boot-usbarmory-usbarmory
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
make usbarmory_config
make -j4 u-boot.imx
make HOSTCC="${CROSS_COMPILE}gcc -static" env #needs static linkage

rm -rf $DIR
mkdir -p ${DIR}/boot ${DIR}/etc ${DIR}/sbin 
cp u-boot.imx $DIR/boot
cp tools/env/fw_printenv $DIR/sbin
ln $DIR/sbin/fw_printenv $DIR/sbin/fw_setenv
echo "/dev/mmcblk0 0x60000 0x2000" > $DIR/etc/fw_env.config
