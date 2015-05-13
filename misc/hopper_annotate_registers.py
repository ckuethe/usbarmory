# vim: tabstop=4:softtabstop=4:shiftwidth=4:noexpandtab:

# Copyright: (c)2015 Chris Kuethe <chris.kuethe+github@gmail.com>
# License: Perl Artistic <http://dev.perl.org/licenses/artistic.html>
# Description: adds names to known register addresses

import re
import requests

doc = Document.getCurrentDocument()
regmap_url = 'https://raw.githubusercontent.com/boundarydevices/devregs/master/dat/devregs_imx53.dat'
req = requests.get(regmap_url)
for line in req.text.splitlines():
	if '0x' not in line:
		continue
	m = re.search('^(\w+)\s+(0[Xx][0-9a-fA-F]{8})\s*$', line)
	if m is not None:
		a = int(m.group(2),16)
		n = m.group(1)
		doc.log("0x%x %s" % (a, n))
		try:
			doc.setNameAtAddress(a, n)
			seg = doc.getSegmentAtAddress(a)
			seg.setTypeAtAddress(a, 4, Segment.TYPE_INT)
		except AttributeError:
			pass
doc.refreshView()
