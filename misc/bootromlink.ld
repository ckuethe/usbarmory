MEMORY
{	
	rom0	(rx)	: ORIGIN =        0x0, LENGTH = 16K
	rom1	(rx)	: ORIGIN =   0x404000, LENGTH = 48K
	scram	(rwx)	: ORIGIN = 0x07000000, LENGTH = 16K
	tzram	(rwx)	: ORIGIN = 0x0fffc000, LENGTH = 16K
	regs0	(rw)	: ORIGIN = 0x53f80000, LENGTH = 0x80000
	regs1	(rw)	: ORIGIN = 0x63f80000, LENGTH = 0x80000
	iram	(rwxa)	: ORIGIN = 0xf8000000, LENGTH = 128K
}


SECTIONS
{
	.text 0x0  :
	{
	/* absolute, read/execute */
	. = 0x0000;
	bootrom-0.o (.blob)
	}

	.rom1 0x404000 :
	{
	. = 0x0;
	bootrom-1.o (.blob)
	}

	.regs0 0x53f8000 : { empty.o (.regs0) }

	.regs1 0x63f8000 : { empty.o (.regs1) }

	.iram 0xf8000000: { empty.o (.iram) }

	.scram 0x0700000: { empty.o (.scram) }
}


