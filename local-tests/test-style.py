#!/usr/bin/python

import os
import re
import sys

error_list = []


def get_m2s_root(file_name):

	# Check full path given
	if file_name.find('..') >= 0 or not file_name.startswith('/'):
		sys.stderr.write('error: get_m2s_root: \'file_name\' must be a full path\n')
		sys.exit(1)

	# Find AUTHORS file
	items = file_name.split('/')
	del items[0]
	while len(items) > 1:
		
		# Extract one
		items.pop()

		# Construct file name
		m2s_root = ''
		for item in items:
			m2s_root += '/' + item
		authors_file = m2s_root + '/AUTHORS'

		# File found
		if os.path.exists(authors_file):
			return m2s_root
	
	# Not found
	sys.stderr.write('error: file \'%s\' is not within the Multi2Sim trunk\n' % file_name)
	sys.exit(1)


def add_error(line_num, text):

	global error_list
	
	error_list.append([line_num, text])


def print_errors(file_name):
	
	# File name
	print 'File \'%s\'' % (file_name)

	# No errors
	if len(error_list) == 0:
		print '\tCoding style OK'
		return

	error_list.sort()
	for error in error_list:
		print '\tline %d: %s' % (error[0] + 1, error[1])


def check_indent(lines, line_num, num_tabs, num_spaces):

	# Error string
	error_string = 'wrong indentation, %d tabs and %d spaces expected' % \
		(num_tabs, num_spaces)

	# Empty line is fine
	if lines[line_num] == '':
		return
	
	# Check minimum length
	length = len(lines[line_num])
	if length < num_tabs + num_spaces:
		add_error(line_num, error_string)
		return

	# Check tabs
	for i in range(num_tabs):
		if lines[line_num][i] != '\t':
			add_error(line_num, error_string)
			return
	
	# Check spaces
	for i in range(num_spaces):
		if lines[line_num][num_tabs + i] != ' ':
			add_error(line_num, error_string)
			return

	# If the spaces and tabs are the whole string, fine
	if length == num_tabs + num_spaces:
		return

	# Otherwise, check that next character is not tab or space
	if lines[line_num][num_tabs + num_spaces] in ['\t', ' ']:
		add_error(line_num, error_string)
		return

def get_indent(lines, line_num):

	num_tabs = 0
	for i in range(len(lines[line_num])):
		if lines[line_num][i] != '\t':
			return num_tabs
		num_tabs += 1

	return num_tabs


def check_copyright(lines):
	
	# Structure of copyright notice is:
	# 18 lines with notice + one line blank + rest of file

	# Line 0: begin of notice
	if len(lines) < 19 or not re.match(r".*/\*.*", lines[0]):
		add_error(0, 'copyright notice expected')
		return
	
	# Lines 1-16: intermediate lines
	for i in range(1, 17):
		if not re.match(r" \*.*", lines[i]):
			add_error(line_num, 'wrong format for copyright notice')
			return
	
	# Line 17: end of notice
	if not re.match(r".*\*/.*", lines[17]):
		add_error(17, 'end of copyright notice expected')
		return

	# Line 18: blank line
	if lines[18] != '':
		add_error(18, 'blank line expected after copyright notice')
		return

	# Line 19: beginning of code
	if len(lines) > 19 and lines[19] == '':
		add_error(19, 'beginning of code expected right here')
		return
		

def check_comments(lines):

	line_num = 0
	while line_num < len(lines):

		# Remove all embedded comments
		lines[line_num] = re.sub(r"/\*.*\*/", r"/* COMMENT */", lines[line_num])

		# Invalid type of comment
		if re.match(r".*//.*", lines[line_num]):
			add_error(line_num, 'double-slash comments now allowed - use /* xxx */ instead')

		# Check beginning and end of comments
		comment_begin = re.match(r".*/\*.*", lines[line_num])
		comment_end = re.match(r".*\*/.*", lines[line_num])

		# Check that end of comment is end of string
		if comment_end and not lines[line_num].endswith('*/'):
			add_error(line_num, 'end of comment should be end of line')

		# Start of multi-line comment
		if comment_begin and not comment_end:

			# Convert line
			lines[line_num] = re.sub(r"(.*)/\*.*", r"\1/* COMMENT", lines[line_num])
			num_tabs = get_indent(lines, line_num)
			line_num += 1

			# Convert following lines
			while line_num < len(lines):
				
				# Check indentation
				check_indent(lines, line_num, num_tabs, 1)

				# Check first character
				line = lines[line_num].strip()
				if len(line) == 0 or line[0] != '*':
					add_error(line_num, 'line of multiple-line comment should begin with \'*\'')

				# Check if it is the last line
				comment_end = re.match(r".*\*/.*", lines[line_num])
				if comment_end and not lines[line_num].endswith('*/'):
					add_error(line_num, 'end of comment should be end of line')
				if comment_end:
					break

				# Convert line
				lines[line_num] = '\t' * num_tabs + ' * COMMENT'

				# Next line
				line_num += 1
				continue

			# Last line
			if line_num < len(lines):
				lines[line_num] = '\t' * num_tabs + ' */'

		# Next line
		line_num += 1
		continue


def check_style(file_name):

	# Get full path for file
	full_path = os.path.abspath(file_name)
	m2s_root = get_m2s_root(full_path)

	# Open file
	try:
		f = open(full_path, 'r')
	except:
		sys.stderr.write('error: %s: file not found\n' % (file_name))
		sys.exit(1)
	
	# Read file
	content = f.read()
	lines = content.split('\n')

	# Global checks
	check_comments(lines)
	check_copyright(lines)

	# Close file
	f.close()

	# Print errors
	print_errors(full_path)


syntax = '''
Syntax:
    test-style.py <file>

Arguments:

  <file>
  	File to check style for.

'''


# Syntax
if len(sys.argv) != 2:
	sys.stderr.write(syntax)
	sys.exit(1)

# Check style for file
print
check_style(sys.argv[1])
print

