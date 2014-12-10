#!/bin/sh -e

echo "configuring USB"

# it took a little while to find out that the i.MX53 uses
# a ChipIdea core and thus "ci_hdrc.0" is the right driver 
# but this gets it right...
DEV=$(ls /sys/class/udc | head -1)

GADGET=/sys/kernel/config/usb_gadget/usbarmory
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
mkdir -p functions/acm.$N
mkdir -p functions/ecm.$N
mkdir -p functions/eem.$N
mkdir -p functions/mass_storage.$N

BLOCKDEV=/dev/mmcblk0p2

echo 1 > functions/mass_storage.$N/stall
echo 0 > functions/mass_storage.$N/lun.0/cdrom
echo 0 > functions/mass_storage.$N/lun.0/ro
echo 0 > functions/mass_storage.$N/lun.0/nofua
echo 1 > functions/mass_storage.$N/lun.0/removable
echo $BLOCKDEV > functions/mass_storage.$N/lun.0/file

# first byte of address must be even
HOST="48:6f:73:74:50:43" # "HostPC"
SELF="42:61:64:55:53:42" # "BadUSB"
echo $HOST > functions/ecm.$N/host_addr
echo $SELF > functions/ecm.$N/dev_addr
echo $HOST > functions/eem.$N/host_addr
echo $SELF > functions/eem.$N/dev_addr

C=1
mkdir -p configs/c.$C/strings/0x409
echo "Config $C: ECM network" > configs/c.$C/strings/0x409/configuration 
echo 250 > configs/c.$C/MaxPower 
ln -s functions/acm.$N configs/c.$C/
ln -s functions/mass_storage.$N configs/c.$C/
ln -s functions/ecm.$N configs/c.$C/

C=2
mkdir -p configs/c.$C/strings/0x409
echo "Config $C: EEM network" > configs/c.$C/strings/0x409/configuration 
echo 250 > configs/c.$C/MaxPower 
ln -s functions/acm.$N configs/c.$C/
ln -s functions/mass_storage.$N configs/c.$C/
ln -s functions/eem.$N configs/c.$C/

# but this does it automatically! :-)
echo $DEV > UDC
ls /sys/class/udc | head -1 > UDC

ifconfig $N 192.0.2.1 netmask 255.255.255.252 up
route add -net default gw 192.0.2.2
