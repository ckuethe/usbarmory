#!/bin/sh

# from the dropbear source directory, build dropbear and install it
# into /tmp/dir_dropbear. Do this as non-root so that you can't break
# your host system. The target directory can be overlaid with other
# packages (like linux and busybox) to produce a root filesystem

DIR=${PWD}/out/dir_dropbear
cd src/dropbear-2014.66

export CROSS_COMPILE=arm-linux-gnueabihf
export CC="$CROSS_COMPILE-gcc"
export LD="$CROSS_COMPILE-gcc"
export AR="$CROSS_COMPILE-ar"
#env CC=arm-linux-gnueabihf-gcc LDFLAGS=-Wl,--gc-sections CFLAGS="-ffunction-sections -fdata-sections -O3" 
./configure --prefix=/usr --host x86_64-unknown-linux-gnu --target arm-linux-gnueabihf --disable-zlib

# optionally, you can pass in a generated configuration file
if [ $# -eq 1 -a -f $1 ] ; then
	cp $1 options.h
else
	:
	cp ../../config/dropbear-options.h options.h
fi

vi options.h
rm -rf $DIR
make CC=$CC MULTI=1 STATIC=1 PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" DESTDIR=$DIR
make CC=$CC MULTI=1 STATIC=1 DESTDIR=$DIR install

mkdir -p ${DIR}/etc/dropbear ${DIR}/root
cp options.h ${DIR}/root/dropbear-options.h

# generate some host keys
ln -s dropbearmulti dropbearkey
for t in rsa dss ecdsa ; do
	./dropbearkey -t ${t} -f ${DIR}/etc/dropbear/dropbear_${t}_host_key
done
