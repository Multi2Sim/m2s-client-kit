#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
build_m2s_local_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/build-m2s-local.sh"
prog_name=$(echo $0 | awk -F/ '{ print $NF }')


#
# Syntax
#

function error()
{
	echo -e "\nerror: $1\n" >&2
	exit 1
}


function syntax()
{
	cat << EOF

Syntax:
    $prog_name [<options>] <local_dist>

This script check all source (*.c) files in 'multi2sim/src' for redundant
#includes. This is done by removing them one by one and checking if compilation
is still successful. The './configure' script must be run before this script
always using '--enable-debug'. If this flag is not enabled, wrong #includes
might be considered redundant.

Arguments:

  <local_dist>
        Complete path for local distribution of Multi2Sim. Redundant includes
	will be fixed here.

EOF
	exit 1
}



#
# Main Script
#

# Options
temp=`getopt -o r:h -l tag:,help -n $prog_name -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi
eval set -- "$temp"
rev=
rev_arg=
tag=
tag_arg=
while true ; do
	case "$1" in
	-h|--help)
		syntax
		;;
	-r) rev=$2 ; rev_arg="-r $2" ; shift 2 ;;
	--tag) tag=$2 ; tag_arg="--tag $2" ; shift 2 ;;
	--) shift ; break ;;
	*) echo "$1: invalid option" ; exit 1 ;;
	esac
done

# Arguments
[ $# == 1 ] || syntax

# Check argument
m2s_dir="$1"
[ ${m2s_dir:0:1} == "/" ] || error "local dist must be an absolute path"
[ -d "$m2s_dir" ] || error "$m2S_dir: cannot find path"
[ -f "$m2s_dir/Makefile" ] || error "$m2s_dir/Makefile: file not found"

# Warning
echo
echo "WARNING: Please make sure you ran './configure' with flag '--enable-debug'"
echo "         Wrong #includes could be removed otherwise. Also, make sure that"
echo "         you are running this script on a machine where all packages"
echo "         required by Multi2Sim are present."
echo

# Initial build
cd $m2s_dir || exit 1
echo -n "Initial build"
make >/dev/null 2>&1 || error "initial build failed"
echo " - ok"

# List files in distribution package multi2sim/src
cd $m2s_dir || exit 1
file_list=`find . -type f | grep -v "\.svn" | grep "\.c$"`

# Check files
cd $m2s_dir || exit 1
for file in $file_list
do
	echo "File $file:"

	python <<< "
import os
import re
import sys

# Get file
file_name = '$file'

# Discard any file with the '-missing.c' suffix, since it might contain code that
# is compiled conditionally
m = re.match(r\".*-missing\\.c\", file_name)
if m:
	sys.stdout.write('\tFile skipped (special file)\n')
	sys.exit(0)

f = open(file_name, 'r')
lines = f.readlines()
f.close()
line_num = 0
while line_num < len(lines):
	
	# Discard line that is not an '#include'
	line = lines[line_num]
	m = re.match(r\"\\#include *([^ \\n]*)[ \\n]*\", line)
	if not m:
		line_num += 1
		continue
	
	# Print included file
	included_file = m.group(1)
	sys.stdout.write('\tchecking include %s ... ' % (included_file))

	# Check whether this '#include' is 'mhandle.h'
	if included_file == '<lib/mhandle/mhandle.h>':
		sys.stdout.write('skipped (mandatory mhandle.h)\n')
		line_num += 1
		continue

	# Check whether this '#include' is a '.dat' file
	m = re.match(r\"[\\\"\\<].*\\.dat[\\\"\\>]\", included_file)
	if m:
		sys.stdout.write('skipped (.dat file)\n')
		line_num += 1
		continue

	# Check whether this '#include' is for the associated header
	m = re.match(r\".*/([^/]*)\\.c\", '$file')
	source_file = m.groups(1)
	m = re.match(r\"\\\"(.*)\\.h\\\"\", included_file)
	if m:
		header_file = m.groups(1)
	else:
		header_file = ''
	if header_file == source_file:
		sys.stdout.write('skipped (associated header)\n')
		line_num += 1
		continue
	
	# Make copy of file without that line
	new_lines = lines[:];
	del new_lines[line_num]
	f = open('$file', 'w')
	f.writelines(new_lines)
	f.close()

	# Try to compile
	result = os.system('make >/dev/null 2>&1')

	# Result
	if result == 2:
		
		# Restore original file and exit
		f = open('$file', 'w')
		f.writelines(lines)
		f.close()
		exit(1)

	elif result:
		
		# Restore original file and continue
		f = open('$file', 'w')
		f.writelines(lines)
		f.close()
		sys.stdout.write('ok\n')
		line_num += 1
		continue
	else:
		
		# Keep new file and continue
		sys.stdout.write('REDUNDANT\n')
		lines = new_lines[:]
		continue
" || break
done

# End
echo
exit 0

