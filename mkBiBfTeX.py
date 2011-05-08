#!/usr/bin/env python

from sys import argv
import re as re
import BibtexParser as BP

def parseTeX(ftex):
	cites = list()

	with open(ftex) as f:
		m = re.findall(r'\\(onlinec|noc|c)ite{([^%{}]*)}',f.read())
		for cs in m:
			for cite in cs[1].strip().split(', '):
				if cite not in cites:
					cites.append(cite)

	return cites

if __name__ == '__main__':
	keys = parseTeX(argv[1])
	b = BP.BibtexParser(argv[2])
	b.gen_bib_from_keys(keys)
