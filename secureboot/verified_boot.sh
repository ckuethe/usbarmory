#!/bin/sh

# WARNING Work In Progress
# 
# At the end of this script, there should be a set of files
# (uboot.{elf,bin,imx,uboot} + linux.fit) that implement uboot's
# verfied boot scheme. It depends on having a trustworthy copy of
# the signing certificate somewhere, eg. ROM, or at least a hash of
# the certificate in ROM.
#
# Once a trusted kernel loads, it can use verity to check the filesystem.

# References
# http://git.denx.de/?p=u-boot.git;a=blob_plain;f=doc/uImage.FIT/howto.txt
# http://git.denx.de/?p=u-boot.git;a=blob_plain;f=doc/uImage.FIT/signature.txt
# http://git.denx.de/?p=u-boot.git;a=blob_plain;f=doc/uImage.FIT/kernel.its
# http://www.denx-cs.de/doku/?q=m28verifiedboot
# http://www.chromium.org/chromium-os/u-boot-porting-guide/using-nv-u-boot-on-the-samsung-arm-chromebook

usage() {
cat <<EOF
Usage: $0 [-t] -u <UBOOTDIR> [-b <BOARD>] [-n <NAME>] [-z <ZIMAGE>] [-d <DTB>] [-i <INITRD>]
	Defaults
	========
	UBOOTDIR -> unspecified, required
	INITRD   -> unspecified, optional
	NAME     -> "verified_boot"
	ZIMAGE   -> "zImage"
	BOARD    -> "usbarmory" (ie. 'make \$BOARD_conig')
	DTB      -> "\$BOARD.dtb"
	-t       -> test mode, no-verify = false
EOF
exit 1
}


A_LNX="0x60008000"
A_RDK=""
A_DTB=""

VFY_MODE="-r"
BOARD="usbarmory"
NAME="verified_boot"
ZIMAGE="zImage"
WRKDIR=$PWD
ARGS=$(getopt -o ghtb:u:d:n:i:z: -- "$@")

eval set -- "$ARGS"

while : ; do
	case "$1" in
		-g) GENERATE="yes" ; shift ;;
		-t) VFY_MODE="" ; shift ;;
		-n) NAME=$2 ; shift 2 ;;
		-u) UBOOTDIR=$2 ; shift 2 ;;
		-b) BOARD=$2 ; test -z "$DTB" && DTB="${BOARD}.dtb"; shift 2 ;;
		-d) DTB=$2 ; shift 2 ;;
		-i) INITRD=$2 ; shift 2 ;;
		-z) ZIMAGE=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) usage ; exit 1 ;;
	esac
done

if [ -z "$ZIMAGE" -o ! -f "$ZIMAGE" ] ; then
	echo "can't read kernel: '$ZIMAGE'"
	exit 1;
fi

if [ -z "$DTB" -o ! -f "$DTB" ] ; then
	echo "can't read dtb: '$DTB'"
	exit 1;
fi

if [ -n "$INITRD" -a ! -f "$INITRD" ] ; then
	echo "can't read initrd: '$INITRD'"
	exit 1;
fi

if [ -z "$UBOOTDIR" -o ! -d "$UBOOTDIR" ] ; then
	echo "missing uboot source directory'"
	exit 1;
fi

set -e

# Generate signing key. directory is RO to prevent accidental deletion
mkdir -p "${NAME}/keys"
if [ ! -f "${NAME}/keys/${BOARD}.key" ] ; then
	chmod +w "${NAME}/keys"
	openssl genrsa -F4 -out "${NAME}/keys/${BOARD}.key" 2048
	chmod -R -w "${NAME}/keys"
fi

# certificate can be (re)generated from the key if it goes missing
if [ ! -f "${NAME}/keys/${BOARD}.crt" ] ; then
	chmod +w "${NAME}/keys"
	openssl req -batch -new -x509 -key "${NAME}/keys/${BOARD}.key" -out "${NAME}/keys/${BOARD}.crt"
	chmod -R -w "${NAME}/keys"
fi

# Test for - and maybe compile - mkimage with signing enabled
# sandbox runs on host architecture and can build tools
JFLAG="-j$(nproc)"
mkimage -h 2>&1 | grep -q "Signing / verified boot options"
if [ $? -ne 0 ] ; then
	cd $UBOOTDIR
	make mrproper
	rm -rf o_sandbox
	make $JFLAG O=o_sandbox sandbox_config tools
	PATH="${UBOOTDIR}/o_sandbox/tools/:$PATH"
	cd $WRKDIR
fi
export PATH="${UBOOTDIR}/o_sandbox/tools/:$PATH"

# Generate dtb of signer's public key
KDTB="${NAME}_${BOARD}_keys.dtb"
mv $(mktemp tmpXXXXXXXX) "${NAME}/${KDTB}"
cat  << EOF_0 | dtc -I dts -O dtb -o "${NAME}/${KDTB}"
/dts-v1/;

/ {
        model = "Keys";

        signature {
                key-$BOARD {
                        required = "conf";
                        algo = "sha1,rsa2048";
			key-name-hint = "$BOARD";
                };
        };
};
EOF_0

# Create tempfiles
mv $(mktemp tmpXXXXXXXX) "${NAME}/veriboot.zimage"
mv $(mktemp tmpXXXXXXXX) "${NAME}/veriboot.dtb"
mv $(mktemp tmpXXXXXXXX) "${NAME}/veriboot.its"
mv $(mktemp tmpXXXXXXXX) "${NAME}/veriboot.fit"

if [ -n "$INITRD" ] ; then
	mv $(mktemp tmpXXXXXXXX) "${NAME}/veriboot.initrd"
	cp "$INITRD" "${NAME}/veriboot.initrd"
fi
cp "$ZIMAGE" "${NAME}/veriboot.zimage"
cp "$DTB" "${NAME}/veriboot.dtb"

#
# Generate FIT control file
#
cat >> "${NAME}/veriboot.its" << EOF_1
/dts-v1/;

/ {
	description = "Signed image containing Linux, DTB, and (optionally) Initrd";
	#address-cells = <1>;

	images {
		kernel@1 {
			description = "Linux kernel";
			data = /incbin/("veriboot.zimage");
			type = "kernel";
			arch = "arm";
			os = "linux";
			compression = "gzip";
			load = <60008000>;
			entry = <60008000>;
			hash@1 {
				algo = "sha1";
			};
		};
		fdt@1 {
			description = "Device Tree Blob";
			data = /incbin/("veriboot.dtb");
			type = "flat_dt";
			arch = "arm";
			compression = "none";
			hash@1 {
				algo = "sha1";
			};
		};
EOF_1

test -n "$INITRD" && cat >> "${NAME}/veriboot.its" << EOF_2
		ramdisk@1 {
			description = "Ramdisk";
			data = /incbin/("veriboot.initrd");
			type = "ramdisk";
			arch = "arm";
			os = "linux";
			compression = "none";
			load = <00000000>;
			entry = <00000000>;
			hash@1 {
				algo = "sha1";
			};
		};
EOF_2

cat >> "${NAME}/veriboot.its" << EOF_3
	};
	configurations {
		default = "config@1";
EOF_3

if [ -z "$INITRD" ] ; then
cat >> "${NAME}/veriboot.its" << EOF_4
		config@1 {
			description = "No Ramdisk";
			kernel = "kernel@1";
			fdt = "fdt@1";
			signature@1 {
				algo = "sha1,rsa2048";
				key-name-hint = "$BOARD";
				sign-images = "fdt", "kernel";
			};
		};
EOF_4
else
	cat >> "${NAME}/veriboot.its" << EOF_5
		config@1 {
			description = "Ramdisk";
			kernel = "kernel@1";
			fdt = "fdt@1";
			ramdisk = "ramdisk@1";
			signature@1 {
				algo = "sha1,rsa2048";
				key-name-hint = "$BOARD";
				sign-images = "fdt", "kernel", "ramdisk";
			};
		};
EOF_5
fi

cat >> "${NAME}/veriboot.its" << EOF_6
	};
};
EOF_6

cd "$NAME"
COMMENT="Built by $(id -un)@$(hostname) at $(date --rfc-3339=seconds -u)"
mkimage $VFY_MODE -f "veriboot.its" -k keys -K "$KDTB" -c "$COMMENT" -F "${NAME}_${BOARD}.fit" >/dev/null
rm -f veriboot.*
mv $(mktemp tmpXXXXXXXX) "${NAME}_${BOARD}.chk"
fit_check_sign -f "${NAME}_${BOARD}.fit" -k "$KDTB" >> "${NAME}_${BOARD}.chk" 2>&1

# Save full path to Key DTB; we're gonna embed it into uboot
KEY_DTB="${PWD}/${KDTB}"
cd $UBOOTDIR
make mrproper
make $JFLAG CROSS_COMPILE=arm-linux-gnueabihf- O="o_${BOARD}" "${BOARD}_config"
make $JFLAG CROSS_COMPILE=arm-linux-gnueabihf- O="o_${BOARD}" EXT_DTB="$KEY_DTB"

