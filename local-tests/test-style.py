#!/usr/bin/python

import os
import re
import sys
import tempfile

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
	sys.stderr.write('Error: File \'%s\' does not seem to be part of the Multi2Sim trunk\n' % file_name)
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

def check_line_length(lines):

	for line_num in range(len(lines)):

		# Calculate length
		length = 0
		for i in range(len(lines[line_num])):
			if lines[line_num][i] == '\t':
				length += 8 - (length % 8)
			else:
				length += 1

		# Check valid length
		if length > 100:
			add_error(line_num, 'line with %d characters ' % (length) + \
				'(up to 80 recommended, 100 max., tab counts as 8)')

def check_strings(lines):

	for line_num in range(len(lines)):

		line = lines[line_num]
		index = 0
		while index < len(line):
			if line[index] == '"':
				index += 1
				while index < len(line):
					
					# End of string
					if line[index] == '"':
						break

					# Escaped character
					if line[index] == '\\':
						line = line[:index] + 'x' + line[index + 2:]
						index += 1
						continue

					# Any character but space
					if line[index] != ' ':
						line = line[:index] + 'x' + line[index + 1:]
						index += 1
						continue

					# Skip space
					index += 1
					continue
			index += 1
		lines[line_num] = line


# Get the next character as an array [line_num, index]. If there are no more characters,
# [-1, -1] is returned.
def get_next_char(lines, line_num, index):

	# Already at an invalid position
	if line_num < 0 or index < 0 or line_num >= len(lines):
		return [-1, -1]
	
	# Get next
	index += 1
	while index >= len(lines[line_num]):
		index = 0
		line_num += 1
		if line_num >= len(lines):
			return [-1, -1]
	
	# Return
	return [line_num, index]
	

# Get the previous character as an array [line_num, index]. If there are no more characters,
# [-1, -1] is returned.
def get_prev_char(lines, line_num, index):

	# Already at an invalid position
	if line_num < 0 or index < 0:
		return [-1, -1]
	
	# Get previous
	index -= 1
	while index < 0:
		line_num -= 1
		if line_num < 0:
			return [-1, -1]
		index = len(lines[line_num]) - 1
	
	# Return
	return [line_num, index]
	

# Given an open curly bracket, square bracket, or parenthesis at line 'line_num'
# and position 'index', find its closing match. A 2-element is returned containing
# values [ line_num, index ] where the closing match was found.
def get_matching_bracket(lines, line_num, index):

	# Check type of bracket
	open_bracket = lines[line_num][index]
	if open_bracket == '[':
		close_bracket = ']'
	elif open_bracket == '{':
		close_bracket = '}'
	elif open_bracket == '(':
		close_bracket = ')'
	else:
		sys.stderr.write('get_matching_bracket: invalid character \'%c\'\n"' % \
			(lines[line_num][index]))
		sys.exit(1)
	
	# Find closing match
	orig_line_num = line_num
	orig_index = index
	num_brackets = 1
	while True:

		# Next character
		[line_num, index] = get_next_char(lines, line_num, index)
		if line_num < 0:
			sys.stderr.write('line %d:%d ' \
				% (orig_line_num + 1, orig_index + 1) + \
				'no matching bracket found\n')
			sys.exit(1)

		# One more open bracket
		if lines[line_num][index] == open_bracket:
			num_brackets += 1

		# Closing bracket
		if lines[line_num][index] == close_bracket:
			num_brackets -= 1
			if num_brackets == 0:
				return [ line_num, index ]

# Get the first occurrence of a given character starting at line 'line_num' and position
# 'index'. A 2-element array is returned containing values [ line_num, index ] where
# the character was found, or [ -1, -1 ] if it was not present.
def get_next_occurrence(lines, line_num, index, c):

	while True:

		# Check character
		if lines[line_num][index] == c:
			return [line_num, index]

		# Next character
		[line_num, index] = get_next_char(line_num, index)
		if line_num < 0:
			return [-1, -1]
	

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
	check_line_length(lines)
	check_comments(lines)
	check_trailing_spaces(lines)
	check_copyright(lines)
	check_includes(lines, m2s_root)
	check_strings(lines)


	# Close file
	f.close()

	# Print errors
	print_errors(full_path)


def check_tool(tool_name):

	ret = os.system('which ' + tool_name + ' > /dev/null')
	if ret:
		sys.stderr.write('\nError: Tool \'' + tool_name + '\' not installed in your system.\n' + \
			'Please install this tool before running the style checker. In Ubuntu, you\n' + \
			'can run the following command:\n\n' + \
			'\tsudo apt-get install ' + tool_name + '\n\n')
		sys.exit(1)


def get_indent_options():

	# Options for 'indent' program
	options = []
	
	# Leave a blank line before a multi-line comment
	# Format all comments
	# Also modify comments an indentation level 1
	options.append('-bad')
	options.append('-fca')
	options.append('-fc1')
	
	# Blank line after function body
	options.append('-bap')
	
	# Insert '*' at the beginning of each new line of a multi-line comment
	options.append('-sc')
	
	# In code blocks, an open bracket should go to a new line.
	# Do it with 0 additional indentation levels.
	options.append('-bl')
	options.append('-bli0')
	
	# Cuddle up do-while loops
	options.append('-cdw')
	
	# In switch-case statement, 0 indentations for blocks and 'case'
	options.append('-cli0')
	options.append('-cbi0')
	
	# No space before semicolon in empty blocks
	options.append('-nss')
	
	# No space between function name and open parenthesis in function call
	options.append('-npcs')
	
	# Space after type cast
	options.append('-cs')
	
	# No space after 'sizeof'
	options.append('-nbs')
	
	# Space after 'for', 'if', and 'while'
	options.append('-saf')
	options.append('-sai')
	options.append('-saw')
	
	# No indentation for variable names after type in declarations.
	# No new line for multiple-variable declaration sharing type.
	options.append('-di1')
	options.append('-nbc')
	
	# Don't split function return type and name
	options.append('-npsl')
	
	# New line before open bracket in structure declaration and
	# function definition
	options.append('-bls')
	options.append('-blf')
	
	# Indentation of 1 tab, no extra indentation for broken lines,
	# no broken-line indentation depending on expression above
	options.append('-i8')
	options.append('-ci0')
	options.append('-nlp')

	# Return them
	return options
	
	
# Return list of 'typedef' types that need to be passed to 'indent' tool
def get_indent_types():

	types = []

	# Types in <stdio.h>
	types.append('FILE')
	types.append('va_list')
	types.append('off_t')
	types.append('off64_t')
	types.append('size_t')
	types.append('ssize_t')
	types.append('fpos_t')
	types.append('fpos64_t')

	# Types in <signal.h>
	types.append('sig_atomic_t')
	types.append('sigset_t')
	types.append('pid_t')
	types.append('uid_t')
	types.append('sighandler_t')
	types.append('sig_t')

	# Return them
	return types


def run_indent(in_file, out_file):

	# Get list of options and types
	options = get_indent_options()
	types = get_indent_types()

	# Create command line
	command_line = 'indent'
	for option in options:
		command_line += ' ' + option
	for t in types:
		command_line += ' -T ' + t
	command_line += ' ' + in_file + ' -o ' + out_file

	# Run it
	err = os.system(command_line)
	if err:
		sys.exit(1)


def run_meld(old_file, new_file):

	sys.stdout.write( \
		'\n' + \
		'Your input file has been formatted with some suggested changes. Now tool \'meld\'\n' + \
		'will open automatically to make you choose which changes you want to apply. Please\n' + \
		'click on the arrows pointing from the left to the right panel to apply a change.\n' + \
		'Then remember to save your changes.\n' + \
		'\n' + \
		'Note: for correct visualization of suggested changes, change meld\'s tab width to\n' + \
		'8 through option Edit - Preferences - Editor - Tab Width.\n' + \
		'\n' + \
		'Press ENTER to continue...\n')
	raw_input()

	err = os.system('meld ' + new_file + ' ' + old_file)
	if err:
		sys.exit(1)


def is_library_include(include, m2s_root):

	if not re.match(r"<.*>", include):
		return False
	file_name = re.sub(r"<(.*)>", r"\1", include)
	return os.path.exists(m2s_root + '/src/' + file_name)


def is_local_include(include):

	if re.match(r"\".*\"", include):
		return True
	return False


def process_includes(lines, m2s_root):

	# Skip comments, blank lines, and compiler directives other than 'include'
	line_num = 0
	while line_num < len(lines):

		# If line is blank, next
		if re.match(r"^[ \t]*$", lines[line_num]):
			line_num += 1
			continue

		# If line is compiler directive other than 'include', next
		if re.match(r"^#.*", lines[line_num]) and \
				not re.match(r"#include[ \t]+.*", lines[line_num]):
			line_num += 1
			continue

		# If line is comment, skip
		if re.match(r"^[ \t]*/\*.*", lines[line_num]):
			while line_num < len(lines) and not re.match(r".*\*/.*", lines[line_num]):
				line_num += 1
			line_num += 1
			continue

		# Not a blank line and not a comment - first line
		break

	# File empty after skipping header
	if line_num >= len(lines):
		return

	# Create list of includes
	line_first_include = line_num
	line_last_include = -1
	includes = []
	while line_num < len(lines):
		
		# If line is blank, next
		if re.match(r"^[ \t]*$", lines[line_num]):
			line_num += 1
			continue

		# Line is an include
		m = re.match(r"^#include[ \t]*([<\"].*\.h[>\"])[ \t]*", lines[line_num])
		if m:
			line_last_include = line_num
			includes.append(m.groups(1)[0])
			line_num += 1
			continue

		# Line is not an include
		break

	# No includes found
	if len(includes) == 0:
		return

	# Sort includes
	for i in range(len(includes)):
		includes[i] = ( re.sub(r"[\.\-/<>\"]", r"_", includes[i]), includes[i] )
	includes.sort()
	includes = [ v for k, v in includes ]

	# Classify includes as standard, library, and local
	standard_includes = []
	library_includes = []
	local_includes = []
	for include in includes:
		if is_library_include(include, m2s_root):
			library_includes.append(include)
		elif is_local_include(include):
			local_includes.append(include)
		else:
			standard_includes.append(include)
	
	# Create new list of includes
	new_includes = []
	if len(standard_includes):
		new_includes.append('')
		new_includes.extend('#include ' + include \
			for include in standard_includes)
	if len(library_includes):
		new_includes.append('')
		new_includes.extend('#include ' + include \
			for include in library_includes)
	if len(local_includes):
		new_includes.append('')
		new_includes.extend('#include ' + include \
			for include in local_includes)
	new_includes.extend(['', ''])
	
	# Make 'line_first_include' embrace first blank line
	while line_first_include > 0 and \
			re.match(r"^[ \t]*$", lines[line_first_include - 1]):
		line_first_include -= 1

	# Make 'line_last_include' embrace last blank line
	while line_last_include < len(lines) - 1 and \
			re.match(r"^[ \t]*$", lines[line_last_include + 1]):
		line_last_include += 1

	# Replace lines
	lines[line_first_include : line_last_include + 1] = new_includes


def process_last_line(lines):

	while len(lines) > 0 and lines[-1] == '':
		lines.pop()


def process_comments(lines):

	line_num = 0
	while line_num < len(lines):
		lines[line_num] = re.sub(r"(.*)//(.*)$", r"\1/*\2*/", lines[line_num])
		line_num += 1

def run_pre_process(f):

	# Read file
	f.seek(0)
	content = f.read()
	lines = content.split('\n')

	# Replace C++ type comments
	process_comments(lines)

	# Write file
	f.seek(0)
	f.truncate(0)
	f.writelines(line + '\n' for line in lines)
	f.flush()


def run_post_process(f, m2s_root):

	# Read file
	f.seek(0)
	content = f.read()
	lines = content.split('\n')

	# Sort includes
	process_includes(lines, m2s_root)

	# One line at the end of file
	process_last_line(lines)

	# Write file
	f.seek(0)
	f.truncate(0)
	f.writelines(line + '\n' for line in lines)
	f.flush()



################################################################################
# Main program
################################################################################

syntax = '''
Syntax:
    test-style.py <file>

Arguments:

  <file>
  	File to check style for.

'''

# Check that command-line tools 'meld' and 'indent' are present
check_tool('meld')
check_tool('indent')

# Syntax
if len(sys.argv) != 2:
	sys.stderr.write(syntax)
	sys.exit(1)

# Get file name
file_name = os.path.abspath(sys.argv[1])
if not os.path.isfile(file_name):
	sys.stderr.write('\nError: File \'%s\' not found.\n\n' % (sys.argv[1]))
	sys.exit(1)

# Read Multi2Sim root directory
m2s_root = get_m2s_root(file_name)

# Create temporary input and output files
in_file = tempfile.NamedTemporaryFile()
out_file = tempfile.NamedTemporaryFile()
in_file_name = in_file.name
out_file_name = out_file.name

# Copy 'file_name' to 'in_file'
try:
	# Read from source
	f = open(file_name, 'r')
	lines = f.readlines()
	f.close()

	# Write to 'in_file'
	in_file.seek(0)
	in_file.truncate(0)
	in_file.writelines(lines)
	in_file.flush()

except:
	sys.stderr('\nError: Couldn\'t read input file.\n\n')
	sys.exit(1)

# Run 'indent' tool
run_pre_process(in_file)
run_indent(in_file_name, out_file_name)
run_post_process(out_file, m2s_root)

# Run 'meld'
run_meld(file_name, out_file_name)

