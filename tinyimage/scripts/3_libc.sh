#!/bin/sh

# from the busybox source directory, build busybox and install it
# into /tmp/dir_busybox. Do this as non-root so that you can't break
# your host system. The target directory can be overlaid with other
# packages (like linux and dropbear) to produce a root filesystem


DIR=${PWD}/out/dir_libc
cd src/uClibc-0.9.33.2
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

# optionally, you can pass in a generated configuration file
if [ $# -eq 1 -a -f $1 ] ; then
	T=$(mktemp -p .)
	cp $1 $T
	mv $T .config
else
	cp ../../config/uclibc-config .config
fi
make menuconfig
make -j4 all DESTDIR=$DIR install

mkdir -p $DIR/root
cp .config $DIR/root/uclibc
