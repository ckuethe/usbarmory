#!/bin/sh -e

X="arm-linux-gnueabihf-"
E="mx53boot.elf"

rm -f empty.o bootrom-*.o vars.o $E

echo | ${X}as -o empty.o
cp empty.o bootrom-0.o
cp empty.o bootrom-1.o

cat <<EOF | ${X}gcc -x c -c - -o vars.o
#include <stdint.h>

uint8_t __attribute__((section(".scram"))) _scram[32*1024] ; // includes alias
uint8_t __attribute__((section(".debug"))) _debug[36*1024] ;
uint8_t __attribute__((section(".sbpa"))) _sbpa[256*1024] ;
uint8_t __attribute__((section(".tzram"))) _tzram[16*1024] ;
uint8_t __attribute__((section(".regs0"))) _regs0[0x80000] ;
uint8_t __attribute__((section(".regs1"))) _regs1[0x80000] ;
uint8_t __attribute__((section(".iram"))) _iram[128*1024] ;
uint8_t __attribute__((section(".dram"))) _dram[4*1024] ;

EOF

F="--set-section-flags .blob=alloc,contents,load,code"
${X}objcopy --add-section .blob=bootrom-0-16k.bin $F bootrom-0.o 
${X}objcopy --add-section .blob=bootrom-1-48k.bin $F bootrom-1.o 

${X}ld -e 0xc0 -T bootromlink.ld -o $E
${X}objdump -x $E
${X}size $E
