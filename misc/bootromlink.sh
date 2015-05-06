#!/bin/sh -x

X="arm-linux-gnueabihf-"
E="mx53boot.elf"

rm -f empty.o bootrom-*.o $E

echo | ${X}as -o empty.o
cp empty.o bootrom-0.o
cp empty.o bootrom-1.o

F="--set-section-flags .blob=alloc,contents,load,code"
${X}objcopy --add-section .blob=bootrom-0-16k.bin $F bootrom-0.o 
${X}objcopy --add-section .blob=bootrom-1-48k.bin $F bootrom-1.o 

${X}ld -e 0xc0 -T bootromlink.ld -o $E
