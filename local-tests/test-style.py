#!/usr/bin/python

import ConfigParser
import os
import re
import subprocess
import sys
import tempfile
import time

error_list = []


# Standard C types
std_types = [ \
	'signed', \
	'unsigned', \
	'char', \
	'short', \
	'int', \
	'long', \
	'float', \
	'double', \
	'enum', \
	'struct', \
	'union', \
	'void' \
]
	
# Non-standard C types
non_std_types = [ \
	'FILE', \
	'va_list', \
	'off_t', \
	'off64_t', \
	'size_t', \
	'ssize_t', \
	'fpos_t', \
	'fpos64_t', \
	\
	'sig_atomic_t', \
	'sigset_t', \
	'pid_t', \
	'uid_t', \
	'sighandler_t', \
	'sig_t', \
	\
	'Elf32_Half', \
	'Elf64_Half', \
	'Elf32_Word', \
	'Elf32_Sword', \
	'Elf64_Word', \
	'Elf64_Sword', \
	'Elf32_Xword', \
	'Elf32_Sxword', \
	'Elf64_Xword', \
	'Elf64_Sxword', \
	'Elf32_Addr', \
	'Elf64_Addr', \
	'Elf32_Off', \
	'Elf64_Off', \
	'Elf32_Section', \
	'Elf64_Section', \
	'Elf32_Versym', \
	'Elf64_Versym', \
	'Elf32_Ehdr', \
	'Elf64_Ehdr', \
	'Elf32_Shdr', \
	'Elf64_Shdr', \
	'Elf32_Sym', \
	'Elf64_Sym', \
	'Elf32_Syminfo', \
	'Elf64_Syminfo', \
	'Elf32_Rel', \
	'Elf64_Rel', \
	'Elf32_Rela', \
	'Elf64_Rela', \
	'Elf32_Phdr', \
	'Elf64_Phdr', \
	'Elf32_Dyn', \
	'Elf64_Dyn', \
	'Elf32_Verdef', \
	'Elf64_Verdef', \
	'Elf32_Verdaux', \
	'Elf64_Verdaux', \
	'Elf32_Verneed', \
	'Elf64_Verneed', \
	'Elf32_Vernaux', \
	'Elf64_Vernaux', \
	'Elf32_auxv_t', \
	'Elf64_auxv_t', \
	'Elf32_Nhdr', \
	'Elf64_Nhdr', \
	'Elf32_Move', \
	'Elf64_Move', \
	'Elf32_gptab', \
	'Elf32_RegInfo', \
	'Elf_Options', \
	'Elf_Options_Hw', \
	'Elf32_Lib', \
	'Elf64_Lib', \
	'Elf32_Conflict' \
]



# Check whether a line of code is a variable declaration. Returns the number of
# lines spanned by the declaration, or 0 if the line is not a declaration.
def is_decl(lines, line_num):
	
	# Split line in tokens
	line = re.sub(r"[ \t]*(.*$)", r"\1", lines[line_num])
	tokens = line.split()

	# Empty
	if len(tokens) == 0:
		return 0

	# Not a declaration
	token = tokens[0]
	if not token in std_types and \
			not token in non_std_types and \
			not token.endswith('_t'):
		return 0

	# Declaration - check number of lines
	start_line_num = line_num
	while line_num < len(lines):
		if re.match(r".*;[ \t]*", lines[line_num]):
			break
		line_num += 1

	# Return number of lines
	return line_num - start_line_num + 1


# Return true if a declaration contains an assignment
def is_decl_with_assign(lines):

	for line in lines:
		if re.match(r"[^\"]*=.*", line):
			return True

	return False


# Return the type of a declaration (e.g. 'sig_set_t', 'struct', ...)
def get_decl_type(lines):

	if len(lines) == 0:
		sys.stderr.write('get_decl_type: no lines passed')
		sys.exit(1)
	line = re.sub(r"^[ \t]*(.*$)", r"\1", lines[0])
	tokens = line.split()
	if len(tokens) == 0:
		sys.stderr.write('get_decl_type: 0 tokens obtained')
		sys.exit(1)
	return tokens[0]


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


# Return number of tabs prefixing the line
def get_indent(lines, line_num):
	
	# Invalid line
	if line_num < 0 or line_num >= len(lines):
		return 0

	# Obtain tabs
	tabs = 0
	for index in range(len(lines[line_num])):
		if lines[line_num][index] == '\t':
			tabs += 1
		else:
			break

	# Return number of tabs
	return tabs


def add_error(line_num, text):

	global error_list
	
	error_list.append([line_num, text])


def print_errors():

	# No errors
	if error_list == []:
		return

	# Header
	sys.stdout.write( \
		'\n' + \
		'*' * 80 + '\n' + \
		'WARNING: There are still some issues in the code format that could not be fixed\n' + \
		'automatically. Please address the issues listed below manually, then re-run this\n' + \
		'script before committing your code.\n' +
		'*' * 80 + \
		'\n\n');
	
	# Errors
	error_list.sort()
	for error in error_list:
		print '\tLine %d: %s' % (error[0] + 1, error[1])
	print


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


def check_svn():

	# If 'exe_path' is '/home/user/m2s-client-kit/local-tests/test-style.py',
	# 'client_kit_path' is '/home/ubal/m2s-client-kit'
	exe_path = os.path.abspath(__file__)
	local_tests_path = os.path.dirname(exe_path)
	client_kit_path = os.path.split(local_tests_path)[0]

	# Check valid client_kit_path
	if not os.path.isdir(os.path.join(client_kit_path, '.svn')):
		sys.stderr.write('\nError: Failed to locate client kit.\n\n')
		sys.exit(1)
	
	# INI file containing last check
	tmp_dir = os.path.join(client_kit_path, 'tmp')
	ini_file = os.path.join(tmp_dir, 'test-style.ini')
	config = ConfigParser.ConfigParser()
	config.read(ini_file)

	try:
		last_check_str = config.get('General', 'LastCheck', 0)
		last_check = float(last_check_str)
	except:
		last_check = 0
	
	# Skip check if it was done recently
	if last_check != 0 and time.time() - last_check < 60 * 60 * 24:
		return

	# Check latest SVN version
	svn_current_output = subprocess.check_output(['svn', 'info', client_kit_path])
	svn_head_output = subprocess.check_output(['svn', 'info', '-r', 'HEAD', client_kit_path])
	current_revision = re.sub(r".*^Revision: ([0-9]*)$.*", r"\1", svn_current_output, flags = re.M | re.S)
	head_revision = re.sub(r".*^Revision: ([0-9]*)$.*", r"\1", svn_head_output, flags = re.M | re.S)
	if current_revision < head_revision:
		sys.stderr.write('\nError: SVN Repository \'m2s-client-kit\' is not up to date.\n' + \
			'Please update to the latest revision by running these commands:\n\n' + \
			'\tcd ' + client_kit_path + '\n' + \
			'\tsvn up\n\n')
		sys.exit(1)

	# Record last check
	try:
		config.add_section('General')
	except:
		pass
	last_check = time.time()
	config.set('General', 'LastCheck', last_check)
	with open(ini_file, 'wb') as config_file:
		config.write(config_file)


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
	
	
def run_indent(in_file, out_file):

	# Get list of options and types
	options = get_indent_options()

	# Create command line
	command_line = 'indent'
	for option in options:
		command_line += ' ' + option
	for t in non_std_types:
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
		'8 using option Edit - Preferences - Editor - Tab Width.\n' + \
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

	# Convert global includes into local if possible
	source_file_dir = os.path.dirname(source_file_name)
	for i in range(len(includes)):
		if not is_library_include(includes[i], m2s_root):
			continue
		include_file_name = m2s_root + '/src/' + re.sub(r"<(.*)>", r"\1", includes[i])
		include_file_dir = os.path.dirname(include_file_name)
		if os.path.samefile(include_file_dir, source_file_dir):
			include_file_base = os.path.basename(include_file_name)
			includes[i] = '"' + include_file_base + '"'
	
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


def process_stdint_types(lines):

	line_num = 0
	while line_num < len(lines):
		lines[line_num] = re.sub(r"\bint8_t\b", r"char", lines[line_num])
		lines[line_num] = re.sub(r"\bint16_t\b", r"short", lines[line_num])
		lines[line_num] = re.sub(r"\bint32_t\b", r"int", lines[line_num])
		lines[line_num] = re.sub(r"\bint64_t\b", r"long long", lines[line_num])
		lines[line_num] = re.sub(r"\buint8_t\b", r"unsigned char", lines[line_num])
		lines[line_num] = re.sub(r"\buint16_t\b", r"unsigned short", lines[line_num])
		lines[line_num] = re.sub(r"\buint32_t\b", r"unsigned int", lines[line_num])
		lines[line_num] = re.sub(r"\buint64_t\b", r"unsigned long long", lines[line_num])
		line_num += 1


# Check declarations for a given code block
def process_var_decl_block(lines, line_num, index):

	# Get closing bracket
	close_line_num, close_index = get_matching_bracket(lines, line_num, index)

	# Check matching indentation
	indent_level = get_indent(lines, line_num)
	if indent_level != get_indent(lines, close_line_num):
		add_error(line_num, 'indentation of open and closing bracket (line %d) does not match' % close_line_num)
		return
	
	# Skip if this is a 'struct' or 'union' definition, and not a code block
	if line_num > 0:
		prev_line = lines[line_num - 1]
	else:
		prev_line = ''
	if re.match(r"^[ \t]*struct[ \t]+[^;]*$", prev_line) or \
			re.match(r"^[ \t]*union[ \t]+[^;]*$", prev_line):
		return

	# Check declarations
	line_num += 1
	indent_level += 1
	decl_allowed = True
	while line_num < close_line_num:
		
		# Ignore blank line
		if re.match(r"^[ \t]*$", lines[line_num]):
			line_num += 1
			continue

		# Ignore comment
		if re.match(r"[ \t]*/\*.*/*/[ \t]*", lines[line_num]):
			line_num += 1
			continue

		# Ignore if indentation level is higher
		if get_indent(lines, line_num) != indent_level:
			line_num += 1
			continue
		
		# Split line in tokens
		if is_decl(lines, line_num):
			if not decl_allowed:
				add_error(line_num, 'declaration only allowed at the beginning of code block')
			line_num += 1
			continue

		# Declaration within for loop
		if re.match(r"^for[ \t]+\([ \t]*int[ \t]+.*", lines[line_num]):
			add_error(line_num, 'no declaration allowed in header of \'for\' loop')

		# Not a declaration - no more declarations allowed
		decl_allowed = False
		line_num += 1
		continue
		

# Check that all variable declarations occur in the beginning if a code block
def process_var_decl(lines):

	line_num = 0
	while line_num < len(lines):
		num_open_brackets = lines[line_num].count('{')
		if num_open_brackets == 1:
			index = lines[line_num].index('{')
			process_var_decl_block(lines, line_num, index)
		elif num_open_brackets > 1:
			add_error(line_num, 'multiple open brackets in one line')
		line_num += 1


def print_decl_groups(decl_groups):

	print '*' * 80
	for group_id in range(len(decl_groups)):
		print 'Group %d' % group_id
		group = decl_groups[group_id]
		for decl_id in range(len(group)):
			print '\tDeclaration %d' % decl_id
			decl = group[decl_id]
			print '\t\t', decl
	print '*' * 80

# Make groups of variable declarations for a single block
def process_sort_decl_block(lines, line_num, index):

	# Get end of block
	open_line_num, open_index = [ line_num, index ]
	close_line_num, close_index = get_matching_bracket(lines, line_num, index)

	# Read declarations
	line_num += 1
	first_decl_line_num = -1
	last_decl_line_num = -1
	decl_group = []
	decl_with_assign_group = []
	while line_num < close_line_num:

		# Skip empty line
		if re.match(r"^[ \t]*$", lines[line_num]):
			line_num += 1
			continue

		# Declaration
		decl_num_lines = is_decl(lines, line_num)
		if decl_num_lines:

			# Add declaration
			decl = lines[line_num : line_num + decl_num_lines]
			if is_decl_with_assign(decl):
				decl_with_assign_group.append(decl)
			else:
				decl_group.append(decl)

			# Update first/last declaration lines
			last_decl_line_num = line_num + decl_num_lines - 1
			if first_decl_line_num < 0:
				first_decl_line_num = line_num

			# Next
			line_num += decl_num_lines
			continue

		# No more declarations
		break
	
	# No declaration found
	if decl_group == [] and decl_with_assign_group == []:
		return

	# Adjust beginning and end of declarations skipping empty lines
	while first_decl_line_num > 0 and \
			re.match(r"^[ \t]*$", lines[first_decl_line_num - 1]):
		first_decl_line_num -= 1
	while last_decl_line_num < len(lines) - 1 and \
			re.match(r"^[ \t]*$", lines[last_decl_line_num + 1]):
		last_decl_line_num += 1

	# Create replacement declaration block. This block includes:
	# 1) All declarations with assignments
	# 2) Rest of declarations split in groups as per type
	decl_groups = []
	for decl in decl_group:
		found = False
		for group in decl_groups:
			if get_decl_type(group[0]) == get_decl_type(decl):
				found = True
				group.append(decl)
				break
		if not found:
			decl_groups.append([ decl ])
	if decl_with_assign_group != []:
		decl_groups.insert(0, decl_with_assign_group)

	# Decide whether we want spaces between groups based on their size.
	# If there is at least one group with more than 3 declarations, yes.
	# If there is more than 1 group with 1 declaration, no
	num_groups_4_or_more_decl = 0
	num_groups_1_decl = 0
	for group in decl_groups:
		if len(group) > 3:
			num_groups_4_or_more_decl += 1
		elif len(group) == 1:
			num_groups_1_decl += 1
	if num_groups_4_or_more_decl > 0:
		force_spaces = True
	elif num_groups_1_decl > 1:
		force_spaces = False
	else:
		force_spaces = True

	# Create new lines with declarations
	new_lines = []
	for group in decl_groups:
		for decl in group:
			new_lines.extend(decl)
		if force_spaces:
			new_lines.append('')
	if not force_spaces:
		new_lines.append('')

	# Replace lines
	lines[first_decl_line_num : last_decl_line_num + 1] = new_lines



# Make groups of variable declarations based on their type
def process_sort_decl(lines):

	line_num = 0
	while line_num < len(lines):

		# Number of open brackets
		num_open_brackets = lines[line_num].count('{')
		if num_open_brackets != 1:
			line_num += 1
			continue

		# Process this block
		index = lines[line_num].index('{')
		process_sort_decl_block(lines, line_num, index)

		# Next
		line_num += 1


# Check calls to malloc/calloc/realloc/strdup
def process_alloc(lines):

	line_num = 0
	while line_num < len(lines):

		if re.match(r".*\b(malloc|calloc|realloc|strdup)\b.*", lines[line_num]):
			add_error(line_num, 'function malloc/calloc/realloc/strdup not allowed, ' + \
				'use xmalloc/xcalloc/xrealloc/xstrdup')
		line_num += 1


def run_pre_indent_process(f):

	# Read file
	f.seek(0)
	content = f.read()
	lines = content.split('\n')

	# Passes
	process_comments(lines)
	process_stdint_types(lines)

	# Write file
	f.seek(0)
	f.truncate(0)
	f.writelines(line + '\n' for line in lines)
	f.flush()


def run_post_indent_process(f, m2s_root):

	# Read file
	f.flush()
	f.seek(0)
	content = f.read()
	lines = content.split('\n')

	# Passes
	process_includes(lines, m2s_root)
	process_last_line(lines)
	process_sort_decl(lines)

	# Write file
	f.seek(0)
	f.truncate(0)
	f.writelines(line + '\n' for line in lines)
	f.flush()


def run_post_meld_process(f):

	# Read file
	f.flush()
	f.seek(0)
	content = f.read()
	lines = content.split('\n')

	# Passes
	process_var_decl(lines)
	process_alloc(lines)

	# Print errors
	if error_list != []:
		print_errors()



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
source_file_name = os.path.abspath(sys.argv[1])
if not os.path.isfile(source_file_name):
	sys.stderr.write('\nError: File \'%s\' not found.\n\n' % (sys.argv[1]))
	sys.exit(1)

# Check that client kit is in the latest SVN revision
check_svn()

# Read Multi2Sim root directory
m2s_root = get_m2s_root(source_file_name)

# Create temporary input and output files
in_file = tempfile.NamedTemporaryFile()
out_file = tempfile.NamedTemporaryFile()
in_file_name = in_file.name
out_file_name = out_file.name

# Copy 'source_file' to 'in_file'
try:
	# Read from source
	source_file = open(source_file_name, 'r')
	lines = source_file.readlines()

	# Write to 'in_file'
	in_file.seek(0)
	in_file.truncate(0)
	in_file.writelines(lines)
	in_file.flush()

except:
	sys.stderr.write('\nError: Couldn\'t read input file.\n\n')
	sys.exit(1)

# Run 'indent' tool
run_pre_indent_process(in_file)
run_indent(in_file_name, out_file_name)
run_post_indent_process(out_file, m2s_root)

# Run 'meld'
run_meld(source_file_name, out_file_name)
run_post_meld_process(source_file)

