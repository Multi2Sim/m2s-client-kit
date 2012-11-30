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

def check_includes_is_standard(include, m2s_root):
	
	if not re.match(r"#include <.*>", include):
		return False
	file_name = re.sub(r"#include <(.*)>", r"\1", include)
	return not os.path.exists(m2s_root + '/src/' + file_name)


def check_includes_is_library(include, m2s_root):

	if not re.match(r"#include <.*>", include):
		return False
	file_name = re.sub(r"#include <(.*)>", r"\1", include)
	return os.path.exists(m2s_root + '/src/' + file_name)


def check_includes_is_local(include):

	if re.match(r"#include \".*\"", include):
		return True
	return False


def check_includes(lines, m2s_root):

	# Skip copyright and blank lines
	line_num = 0
	while line_num < len(lines):
		if lines[line_num] != '' and \
				not re.match(r".*/\*.*", lines[line_num]) and \
				not re.match(r" \*.*", lines[line_num]) and \
				not re.match(r".*\*/.*", lines[line_num]):
			break;
		line_num += 1

	# Get blank lines and includes
	includes = []
	while line_num < len(lines):
		if lines[line_num] != '' and \
				not re.match(r"#include .*", lines[line_num]):
			break;
		includes.append(lines[line_num])
		line_num += 1
	
	# No include is fine
	if includes == []:
		return
	
	# Exactly two blank lines after includes
	blank_lines = 0
	while len(includes) and includes[len(includes) - 1] == '':
		blank_lines += 1
		includes.pop()
	if blank_lines != 2:
		add_error(line_num, 'exactly two blank lines expected after #includes')
	
	# Create groups
	include_groups = []
	include_group = []
	while len(includes):
		include = includes.pop(0)
		if include == '':
			if include_group == []:
				add_error(line_num, 'only one blank line expected between #include groups')
			else:
				include_groups.append(include_group[:])
				include_group = []
		else:
			include_group.append(include)
	if include_group != []:
		include_groups.append(include_group[:])

	# At the most 3 include groups
	if len(include_groups) > 3:
		add_error(line_num, 'set of %d #include groups found, but a maximum of 3 is expected' % \
			(len(include_groups)))
		return
	
	# Check that each group is sorted
	for i in range(len(include_groups)):
		include_group = include_groups[i]
		if include_group != sorted(include_group):
			add_error(line_num, 'set of #includes in group %d are not sorted' % (i + 1))
	
	# Print types
	#for i in range(len(include_groups)):
	#	print
	#	print 'Group', i
	#	include_group = include_groups[i]
	#	for include in include_group:
	#		print include
	#		print '\tis_standard: ', check_includes_is_standard(include, m2s_root)
	#		print '\tis_library:  ', check_includes_is_library(include, m2s_root)
	#		print '\tis_local:    ', check_includes_is_local(include)
	
	# One include group
	standard_includes = []
	standard_includes_index = -1
	library_includes = []
	library_includes_index = -1
	local_includes = []
	local_includes_index = -1
	for include_group_index in range(len(include_groups)):
		include_group = include_groups[include_group_index]
		include = include_group[0]
		if check_includes_is_standard(include, m2s_root):
			if standard_includes_index > -1:
				add_error(line_num, 'groups of #includes %d and %d use standard #includes (e.g., <stdio.h>)' % \
					(standard_includes_index + 1, include_group_index + 1))
			standard_includes = include_group
			standard_includes_index = include_group_index
		elif check_includes_is_library(include, m2s_root):
			if library_includes_index > -1:
				add_error(line_num, 'groups of #includes %d and %d use library #includes (e.g., <lib/util/debug.h>)' % \
					(library_includes_index + 1, include_group_index + 1))
			library_includes = include_group
			library_includes_index = include_group_index
		elif check_includes_is_local(include):
			if local_includes_index > -1:
				add_error(line_num, 'groups of #includes %d and %d use local #includes (e.g., "cpu.h")' % \
					(local_includes_index + 1, include_group_index + 1))
			local_includes = include_group
			local_includes_index = include_group_index
		else:
			add_error(line_num, 'cannot determine type of #include \'%s\'' % (include))
	
	# Check order of groups
	if standard_includes_index > -1 and library_includes_index > -1 \
			and standard_includes_index > library_includes_index:
		add_error(line_num, 'standard includes should appear before library includes')
	if standard_includes_index > -1 and local_includes_index > -1 \
			and standard_includes_index > local_includes_index:
		add_error(line_num, 'standard includes should appear before local includes')
	if library_includes_index > -1 and local_includes_index > -1 \
			and library_includes_index > local_includes_index:
		add_error(line_num, 'library includes should appear before local includes')
		
	# Check types
	for include in standard_includes:
		if not check_includes_is_standard(include, m2s_root):
			add_error(line_num, 'line \'%s\' should be a standard Linux #include (e.g., <stdio.h>)' % (include))
	for include in library_includes:
		if not check_includes_is_library(include, m2s_root):
			add_error(line_num, 'line \'%s\' should be a Multi2Sim library #include (e.g., <lib/util/debug.h>)' % (include))
	for include in local_includes:
		if not check_includes_is_local(include):
			add_error(line_num, 'line \'%s\' should be a local #include (e.g., "cpu.h")' % (include))




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
	check_includes(lines, m2s_root)

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
