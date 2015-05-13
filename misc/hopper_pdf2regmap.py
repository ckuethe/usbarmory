#!/usr/bin/env python

# vim: tabstop=4:softtabstop=4:shiftwidth=4:noexpandtab:

# Copyright: (c)2015 Chris Kuethe <chris.kuethe+github@gmail.com>
# License: Perl Artistic <http://dev.perl.org/licenses/artistic.html>
# Description: generate a register map from the reference manual

#TODO figure out how to extract register length from docs
#TODO figure out how to deal with "0xBase_0200" format

import re
import PyPDF2
import sys

if len(sys.argv) != 3:
	print "usage: %s <pdfsrc> <outfile>" % sys.argv[0]
	sys.exit(1)

infp = open(sys.argv[1], 'rb')
outfp = open(sys.argv[2], 'w')
pdf = PyPDF2.PdfFileReader(infp)
rgx = re.compile('Address: ([A-Z0-9_-]+) is [0-9A-F]{4}_[0-9A-F]{4}h.*? = ([0-9A-F]{4})_([0-9A-F]{4})h')

for i in range( pdf.getNumPages() ):
	sys.stderr.write("%d " % i)
	pg = pdf.getPage(i)
	txt = pg.extractText()

	for match in rgx.findall(txt):
		addr = int("%s%s" % (match[1], match[2]), 16)
		reg = "%d %s\n" % (addr, match[0])
		#print reg
		outfp.write(reg)

outfp.close()
