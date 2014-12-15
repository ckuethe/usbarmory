#!/bin/sh -e

echo "configuring USB"

test -f /etc/modprobe.sh && . /etc/modprobe.sh

CONF=/sys/kernel/config/usb_gadget
test -d $CONF || mount $(basename $CONF)

GADGET=$CONF/usbarmory
mkdir -p $GADGET
cd $GADGET || exit 1

echo 0xcafe > idVendor 
echo 0xbabe > idProduct 
echo 0x0082 > bcdDevice

mkdir -p strings/0x409
echo "fedcba9876543210" > strings/0x409/serialnumber
echo "Inverse Path" > strings/0x409/manufacturer 
echo "USB Armory" > strings/0x409/product 

N="usb0"
mkdir -p configs/c.1/strings/0x409
echo 250 > configs/c.1/MaxPower 
# always want serial console
mkdir -p functions/acm.$N
ln -s functions/acm.$N configs/c.1/

if $(false) ; then
	# this requires user configuration
	mkdir -p functions/mass_storage.$N
	BLOCKDEV=/dev/mmcblk0p2

	echo 1 > functions/mass_storage.$N/stall
	echo 0 > functions/mass_storage.$N/lun.0/cdrom
	echo 0 > functions/mass_storage.$N/lun.0/ro
	echo 0 > functions/mass_storage.$N/lun.0/nofua
	echo 1 > functions/mass_storage.$N/lun.0/removable
	echo $BLOCKDEV > functions/mass_storage.$N/lun.0/file
	ln -s functions/mass_storage.$N configs/c.1/
fi

# first byte of address must be even; odd => multicast
HOST="48:6f:73:74:50:43" # "HostPC"
SELF="42:61:64:55:53:42" # "BadUSB"

if $(true) ; then
	net="ecm"
else
	net="eem"
fi
mkdir -p functions/${net}.$N
echo $HOST > functions/${net}.$N/host_addr
echo $SELF > functions/${net}.$N/dev_addr
ln -s functions/${net}.$N configs/c.1/

echo "multifunction gadget" > configs/c.1/strings/0x409/configuration 

# it took a little while to find out that the i.MX53 uses
# a ChipIdea core and thus "ci_hdrc.0" is the right driver 
# but this gets it right...
UDC=$(ls /sys/class/udc | head -1)
echo $UDC > UDC

ifconfig $N 192.0.2.1 netmask 255.255.255.252 up
route add -net default gw 192.0.2.2
