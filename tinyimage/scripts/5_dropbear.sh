#!/bin/sh

# from the dropbear source directory, build dropbear and install it
# into /tmp/dir_dropbear. Do this as non-root so that you can't break
# your host system. The target directory can be overlaid with other
# packages (like linux and busybox) to produce a root filesystem

DIR=${PWD}/out/dir_dropbear
SR="--sysroot ${PWD}/out/dir_libc"
cd src/dropbear-2014.66

make -i clean
export LDFLAGS="$SR -Wl,--gc-sections"
export CFLAGS="$SR -ffunction-sections -fdata-sections -O3"
./configure --prefix=/usr --build=x86_64-unknown-linux-gnu --host=arm-linux-gnueabihf --disable-zlib

# optionally, you can pass in a generated configuration file
if [ $# -eq 1 -a -f $1 ] ; then
	cp $1 options.h
else
	:
	cp ../../config/dropbear-options.h options.h
fi

vi options.h
rm -rf $DIR
make MULTI=1 STATIC=1 PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" DESTDIR=$DIR
make MULTI=1 STATIC=1 DESTDIR=$DIR install

mkdir -p ${DIR}/etc/dropbear ${DIR}/root
cp options.h ${DIR}/root/dropbear-options.h

# generate some host keys
ln -s dropbearmulti dropbearkey
for t in rsa dss ecdsa ; do
	./dropbearkey -t ${t} -f ${DIR}/etc/dropbear/dropbear_${t}_host_key
done
