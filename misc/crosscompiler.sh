#!/bin/sh

# You probably don't need this. At least on ubuntu, the crosscompiler is ok
# arm-linux-gnueabihf-gcc (Ubuntu/Linaro 4.9.1-16ubuntu6) 4.9.1

# http://kunen.org/uC/gnu_tool.html
# http://www.infopoort.nl/index.php/Software:ARM_Toolchain

TOP=~/usbarmory/
TOOLCHAIN_DIR=$TOP/toolchain
TGT="arm-none-eabi"

mkdir -p $TOP/dist $TOP/src $TOP/build

if [ 0 -eq 1 ] ; then
cd $TOP/dist
S="https://releases.linaro.org/"
wget -nc	\
	$S/14.11/components/toolchain/gcc-linaro/4.9/gcc-linaro-4.9-2014.11.tar.xz \
	$S/14.09/components/toolchain/binutils-linaro/binutils-linaro-2.24.0-2014.09.tar.xz \
	$S/14.09/components/toolchain/newlib-linaro/newlib-linaro-2.1.0-2014.09.tar.bz2
fi


echo "building cross compiler for $TGT in $TOOLCHAIN_DIR - this will take a while..."
exec 1>$TOP/build/buildlog
if [ 1 -eq 1 ] ; then
echo unpacking
cd $TOP/src
rm -rf binutils-linaro-* gcc-linaro-* newlib-linaro-*
tar xf $TOP/dist/binutils-linaro-*-2014.09.*
tar xf $TOP/dist/newlib-linaro-*-2014.09.*
tar xf $TOP/dist/gcc-linaro-*-2014.11.*
fi

rm -rf $TOOLCHAIN_DIR
mkdir -p $TOOLCHAIN_DIR
cd $TOP/build
rm -rf binutils-linaro gcc-linaro newlib-linaro
mkdir -p binutils-linaro gcc-linaro newlib-linaro
COMMON="--target=$TGT --disable-nls --disable-libssp --prefix=$TOOLCHAIN_DIR --disable-werror --enable-interwork --enable-multilib --disable-dlopen"

cd $TOP/build/binutils-linaro
$TOP/src/binutils-linaro-*-2014.09/configure $COMMON --with-sysroot
make -j4 all
make install

cd $TOP/build/gcc-linaro
$TOP/src/gcc-linaro-*-2014.11/configure $COMMON --enable-languages=c --disable-bootstrap --with-system-zlib --with-newlib --with-headers=`../../src/newlib-linaro-*-2014.09/newlib/libc/include/`
make -j4 all-gcc
make install-gcc

cd $TOP/build/newlib-linaro
$TOP/src/newlib-linaro-*-2014.09/configure $COMMON --disable-newlib-supplied-syscalls
sh
sed -e 's/^\(INFOFILES = \)\(.*\)/\1/' < $TOP/src/newlib-linaro-*-2014.09/etc/Makefile.in > x
mv x $TOP/src/newlib-linaro-*-2014.09/etc/Makefile.in
make -j4
make install

cd $TOP/build/gcc-linaro
make -j4
make install

echo "cross compiler for $TGT installed in $TOOLCHAIN_DIR" > /dev/stdout
