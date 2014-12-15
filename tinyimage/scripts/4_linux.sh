#!/bin/sh

# from the linux source directory, build linux and install it
# into /tmp/dir_linux Do this as non-root so that you can't break
# your host system. The target directory can be overlaid with other
# packages (like dropbear and busybox) to produce a root filesystem


DIR=${PWD}/out/dir_linux
cd src/linux-3.18

cp ../../../imx53-usbarmory.dts arch/arm/boot/dts
sed -e 's/imx53-smd.dtb/imx53-usbarmory.dtb/' < arch/arm/boot/dts/Makefile > x
mv x arch/arm/boot/dts/Makefile

export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
cp ../../config/linux-config .config
make -j4 uImage LOADADDR=0x70008000 dtbs modules

rm -rf $DIR
mkdir -p ${DIR}/boot ${DIR}/lib ${DIR}/root
make modules_install INSTALL_MOD_PATH=${DIR}
cp arch/arm/boot/uImage System.map arch/arm/boot/dts/imx53-usbarmory.dtb ${DIR}/boot
cp arch/arm/boot/dts/imx53-usbarmory.dts ${DIR}/root/
cp .config ${DIR}/root/linux.config

