#!/bin/sh

#You may need to install some extra packages...
#sudo apt-get install cramfsprogs squashfs-tools gcc-arm-linux-gnueabihf

mkdir -p src out
cd src
U="https://www.kernel.org/pub/linux/kernel/v2.x/linux-3.18.tar.xz"
test -f $(basename $U) || echo wget $U
U="https://github.com/inversepath/u-boot-usbarmory/archive/usbarmory.zip"
test -f $(basename $U) || echo wget $U
U="http://busybox.net/downloads/busybox-1.22.1.tar.bz2"
test -f $(basename $U) || echo wget $U
U="https://matt.ucc.asn.au/dropbear/releases/dropbear-2014.66.tar.bz2"
test -f $(basename $U) || echo wget $U

unzip -qo usbarmory.zip
tar xf linux-3.18.tar.xz
tar xf busybox-1.22.1.tar.bz2
tar xf dropbear-2014.66.tar.bz2
