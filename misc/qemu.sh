#!/bin/sh
qemu-system-arm	\
	-M vexpress-a9 \
	-m 512M \
	-kernel zImage \
	-dtb vexpress-v2p-ca9.dtb \
	-append "verbose debug console=ttyAMA0 rw panic=5 root=/dev/mmcblk0p1" \
	-initrd initrd.img.gz \
	-sd usbarmory_rootfs.img \
	-net user -net nic,model=lan9118 \
	-nographic -no-reboot -snapshot
