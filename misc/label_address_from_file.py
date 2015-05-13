# vim: tabstop=4:softtabstop=4:shiftwidth=4:noexpandtab:

# Copyright: (c)2015 Chris Kuethe <chris.kuethe+github@gmail.com>
# License: Perl Artistic <http://dev.perl.org/licenses/artistic.html>
# Description: adds names to known register addresses

doc = Document.getCurrentDocument()
infile = doc.askFile('Select annotation file', None, None)

with open(infile, "r") as f:
	for line in f:
		(addr, label) = line.split()
		if '0x' in addr:
			addr = int(addr, 16)
		else:
			addr = int(addr, 10)
		try:
			doc.setNameAtAddress(addr, label)
			doc.log("0x%x %s" % (addr, label))
			#seg = doc.getSegmentAtAddress(a)
			#seg.setTypeAtAddress(a, 4, Segment.TYPE_INT)
			doc.getSegmentAtAddress(addr).setTypeAtAddress(addr, 4, Segment.TYPE_INT)
		except AttributeError:
			pass
doc.refreshView()
