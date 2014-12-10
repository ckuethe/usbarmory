Buildroot
=========

To make this work, you'll need to download the u-boot archive from
https://github.com/inversepath/u-boot-usbarmory and repack it as a
compressed tar archive, then adjust the buildroot configuration to
use this new archive.

After compiling, write the resulting u-boot.imx and rootfs to the
first partition of an microsd, optionally a second partition (VFAT)
can be created to demonstrate the mass storage gadget

Assuming that your target microsd is sdb on your build host:

	dd if=/dev/zero of=/dev/sdb bs=1024k count=64
	parted /dev/sdb --script mklabel msdos
	parted /dev/sdb --script mkpart primary ext4 1M 41M
	parted /dev/sdb --script mkpart primary fat32 41M 75M
	partprobe /dev/sdb
	dd if=u-boot.imx of=/dev/sdb seek=2 bs=512
	gzip -d < root.fs.gz | dd bs=1024k of=/dev/sdb1
	gzip -d < msdos.fs.gz | dd bs=1024k of=/dev/sdb2

Insert the microsd card into your USB Armory, plug it in and in about
10 seconds you'll have serial, network and mass storage access.
