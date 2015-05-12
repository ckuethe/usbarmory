MEMORY
{	
	rom0:	: ORIGIN =        0x0, LENGTH = 16K
	rom1	: ORIGIN =   0x404000, LENGTH = 48K
	scram	: ORIGIN = 0x07000000, LENGTH = 32K
	tzram	: ORIGIN = 0x0fffc000, LENGTH = 16K
	regs0	: ORIGIN = 0x53f80000, LENGTH = 0x80000
	regs1	: ORIGIN = 0x63f80000, LENGTH = 0x80000
	dram	: ORIGIN = 0x70000000, LENGTH = 512M
	iram	: ORIGIN = 0xf8000000, LENGTH = 128K
}


SECTIONS
{
	.text 0x0  :
	{
	. = 0x0000;
	bootrom-0.o (.blob)
	}

	.rom1 0x404000 :
	{
	. = 0x0;
	bootrom-1.o (.blob)
	}

	.scram 0x07000000 : { vars.o (.scram) } >scram
	.tzram 0x0fffc000 : { vars.o (.tzram) } >tzram
	.regs0 0x53f80000 : { vars.o (.regs0) } >regs0
	.regs1 0x63f80000 : { vars.o (.regs1) } >regs1
	.dram  0x70000000 : { vars.o (.dram) } >dram
	.iram  0xf8000000 : { vars.o (.iram) } >iram
}


