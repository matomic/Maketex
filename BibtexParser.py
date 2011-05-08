#!/usr/bin/env python

import re as re
from sys import stderr;

# a parser class for .bib file. Now it only distinguishes between @STRING and non @STRING items
class BibtexParser:
	strdefs = list()
	entries = dict() # list of dictionary for each entry
	__key_re = re.compile('^@[^{}\s]*{([^,\s]*)\s*', re.I | re.S)
	__entry_re = re.compile('^@([^{}]*)\s*{(.*)}', re.I | re.S)
	__field_re = re.compile('([^,]*),(.*)', re.I | re.S)

	# constructor
	def __init__(this, file):
		balanced = 0 # check balanced braces
		it = '';

		with open(file,"r") as f:
			for l in f:
				balanced += (l.count('{') - l.count('}'))
				
				it += l;

				if balanced == 0 and len(it) > 0: # when balanced is achieved and something to save
					this.__append_item(it)
					it = '';

	def __append_item(this, str):
		m = this.__entry_re.match(str)
		if m:
			if m.group(1).lower() == "string":
				this.strdefs.append(str)
			else:
				type = m.group(1);
				m = this.__field_re.match(m.group(2))
				if m:
					key = m.group(1);
					this.entries[key.lower()] = {"type" : type, "value" : m.group(0)}
				else:
					pass #  something is wrong with the bib file (or this code)

	def gen_bib_from_keys(this, keys):
		for s in this.strdefs:
			print(s)

		for k in sorted(keys, key = str.lower):
			try:
				print("@" + this.entries[k.lower()]['type'] +
						"{" + this.entries[k.lower()]['value'] + "}\n")
			except KeyError:
				print >> stderr, ("Key " + k + " not found\n");
				continue
