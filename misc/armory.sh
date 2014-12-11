#!/bin/bash

KERN_VER=3.16.2
KERN_DIST=linux-${KERN_VER}.tar.xz
UBOOT_DIST=usbarmory.zip
IMX_DIST=imx_usb_loader.zip
TOP=$PWD

set -e
#set -x

#TODO
# much more error checking and cleanup (de-configuring loopdevs)
# add local caching to debootstrap
# generate minimal ramdisk to allow network install
# useful usb boot
# signature checks of sources
# investigate verified boot
# add a trustzone call to strobe "USBARMORY" in morse code on the LED? O:-)
# add interactive drop-into-chroot mode during build?

check_prereqs() {
	# TODO figure out what packages are actually required
	# TODO figure out how to do this on redhat and gentoo derivatives
	DEBS="linaro-boot-utils gcc-arm-linux-gnueabihf qemu-system-arm qemu-user-static debootstrap u-boot-tools wget xutils-dev"
	dpkg -S $DEBS > /dev/null
	if [ $? -ne 0 ] ; then
		echo some build dependencies are missing, attempting to install
		sudo apt-get install $DEBS
	fi
	true
}

download_sources() {
	mkdir -p "${TOP}/dist"
	cd "${TOP}/dist"
	test -f $KERN_DIST || wget https://www.kernel.org/pub/linux/kernel/v3.0/$KERN_DIST
	test -f $UBOOT_DIST || wget https://github.com/inversepath/u-boot-usbarmory/archive/$UBOOT_DIST
	test -f $IMX_DIST || wget -O $IMX_DIST https://github.com/boundarydevices/imx_usb_loader/archive/master.zip
}

extract_sources() {
	mkdir -p "${TOP}/src"
	cd "${TOP}/src"
	test -d u-boot-usbarmory-usbarmory || unzip -q ../dist/$UBOOT_DIST
	test -d imx_usb_loader-master || unzip -q ../dist/$IMX_DIST
	test -d linux-${KERN_VER} || tar xf ../dist/$KERN_DIST
}

do_build() {
	mkdir -p "${TOP}/build/loader" "${TOP}/build/kernel" "${TOP}/build/uboot"
	JFLAG="-j$(nproc)"

	cd "${TOP}/build/loader"
	lndir -silent "${TOP}/src/imx_usb_loader-master" >/dev/null 2>&1
	make
	
	export ARCH=arm CROSS_COMPILE="arm-none-eabi-"
	cd "${TOP}/build/uboot"
	lndir -silent "${TOP}/src/u-boot-usbarmory-usbarmory" >/dev/null 2>&1
	make usbarmory_config
	make $JFLAG
	cp u-boot.imx "${TOP}/out"
	
	mkdir -p "${TOP}/build/kernel"
	cd "${TOP}/build/kernel"
	lndir -silent "${TOP}/src/linux-${KERN_VER}" >/dev/null 2>&1

	#FIXME where is the proper kernel config?
	#cp linux-${KERN_VER}.config .config
	make defconfig
	make $JFLAG uImage LOADADDR=0x70008000 | grep "Image .* is ready"
	make $JFLAG modules

	#FIXME defer this and "make install" into the loop image?
	cp arch/arm/boot/uImage "${TOP}/out"
	make INSTALL_MOD_PATH="${TOP}/out" modules_install
}

boot_usb() { :
	# https://linux-sunxi.org/FEL/USBBoot
	# https://sel4.systems/Hardware/sabreLite/
	# https://eewiki.net/display/linuxonarm/i.MX53+Quick+Start
	# https://community.freescale.com/thread/321850
	# https://github.com/boundarydevices/imx_usb_loader/
}

patch_filesystem() { :
	#TODO
	#  enable serial console
	#  resize fs
	#  set hostname, resolver
	#  install openssh, openvpn
	#  create usb ethernet, serial
	#  reject no-password root ssh; allow usbserial login to set password, etc
	# echo 's0:2345:respawn:/sbin/getty -L 115200 ttyS0 vt102'
}

make_sdimage() {
	cd "${TOP}/build/"
	MB=256 #FIXME figure out better filesystem size, 1GB and make it easy to enlarge after install?
	ROOTFS=armory_rootfs
	
	F=${ROOTFS}.fs
	dd if=/dev/zero of=$F bs=1024k count=${MB}
	L=$(sudo losetup --show --partscan --find $F)
	sudo dd if="../out/u-boot.imx" of=$L bs=512 seek=2 conv=notrunc

	# partitioning info
	#	https://eewiki.net/display/linuxonarm/i.MX53+Quick+Start#i.MX53QuickStart-SetupmicroSD/SDcard
	#	http://linux-sunxi.org/Bootable_SD_card
	#	http://linux-sunxi.org/Manual_build_howto#boot.cmd
	#	http://elinux.org/RPi_Easy_SD_Card_Setup
	echo '1,,0x83,*' | sudo sfdisk --in-order --Linux --unit M $L
	sudo partprobe $L

	# format
	sudo mkfs.ext4 -F ${L}p1 -L $ROOTFS -b 1024 $(( $(( $MB - 2 )) * 1024))
	UUID=$(blkid /dev/loop0p1 | cut -d ' ' -f 3)

	# mount filesystem
	#FIXME should this go in the build directory
	mkdir -p $ROOTFS
	sudo mount ${L}p1 $ROOTFS

	# install kernel
	sudo mkdir $ROOTFS/boot $ROOTFS/etc
	sudo cp ../out/uImage $ROOTFS/boot
	sudo cp -r ../out/lib $ROOTFS
	echo "usbarmory" | sudo tee $ROOTFS/etc/hostname
	sudo touch $ROOTFS/etc/resolv.conf

	# default parameters at
	# https://github.com/inversepath/u-boot-usbarmory/blob/usbarmory/include/configs/usbarmory.h
	cat << __EOF__ | sudo tee ${ROOTFS}/boot/uEnv.txt
uname_r=${KERN_VER}

__EOF__

	# install debian image
	# https://wiki.ubuntu.com/ARM/RootfsFromScratch
	# https://wiki.ubuntu.com/ARM/RootfsFromScratch/QemuDebootstrap
	# FIXME add other packages?
	sudo qemu-debootstrap --arch=armhf wheezy ${ROOTFS} https://mirrors.kernel.org/debian/

	# unmount
	sudo umount ${ROOTFS}
	sudo losetup -d $L
	mv ${F} "${TOP}/out/"
}

# main builder stuff is here
check_prereqs
download_sources
extract_sources
do_build
#boot_usb
make_sdimage
