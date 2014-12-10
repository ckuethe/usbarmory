Buildroot
=========

To make this work, you'll need to download the u-boot archive from
https://github.com/inversepath/u-boot-usbarmory and repack it as a
compressed tar archive, then adjust the buildroot configuration to
use this new archive.

After compiling, write the resulting u-boot.imx and rootfs to the
first partition of an microsd, optionally a second partition (VFAT)
can be created to demonstrate the mass storage gadget
