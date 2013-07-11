#!/usr/bin/python

# Copyright (C) 2013 Rafael Ubal
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

import sys
import re

syntax = """
Syntax: file-match.py <file> <regexp>

Check whether <file> matches the regular expression in file <regexp>, given as a
Phython-style regular expression. Possible error codes returned are:

	0   File matches regular expression.
	1   File does not match.
	>1  Some other error occurred.

For a detailed documentation on how to write regular expression on Python,
please visit:
	
	http://docs.python.org/2/library/re.html

"""

# Print syntax
if len(sys.argv) != 3:
	sys.stderr.write(syntax)
	sys.exit(2)

# Read arguments
file_name = sys.argv[1]
regexp_name = sys.argv[2]

# Read files
try:
	file_desc = open(file_name, 'r')
	file_str = file_desc.read()
except:
	sys.stderr.write(file_name + ': cannot open file\n')
	sys.exit(2)
try:
	regexp_desc = open(regexp_name, 'r')
	regexp_str = regexp_desc.read()
except:
	sys.stderr.write(regexp_name + ': cannot open file\n')
	sys.exit(2)

# File must match 'regexp' as a whole, and not just a subset of it. Add the
# extra characters in the beginning and end of 'regexp' to match beginning and
# end of the file.
regexp_str = r'\A' + regexp_str + r'\Z'

# Compile regular expression
try:
	r = re.compile(regexp_str, re.DOTALL)
except Exception as e:
	sys.stderr.write(regexp_name + ': invalid regular expression - ' + \
			str(e) + '\n')
	sys.exit(2)

# Match input
if r.match(file_str):
	sys.exit(0)
else:
	sys.exit(1)

