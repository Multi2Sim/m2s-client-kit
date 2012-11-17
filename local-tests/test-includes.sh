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
    $prog_name [<options>]


Options:

  -r <rev>
  	Multi2Sim revision to fetch and build. If none is specified, the latest
	available SVN revision on the server is fetched.

  --tag <tag>
  	Fetch subdirectory <tag> in the 'tags' directory on the Multi2Sim
	repository. If none is specified, the 'trunk' directory is fetched
	instead.

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
[ $# == 0 ] || syntax

# Obtain local copy
$build_m2s_local_sh $rev_arg $tag_arg \
	|| exit 1

# Temporary directory
temp_dir=`mktemp -d`

# Copy package
m2s_dir=`ls $HOME/m2s-client-kit/tmp/m2s-bin/multi2sim-*.tar.gz | sed "s/.*\(multi2sim-.*\)\.tar\.gz/\1/g"`
m2s_pkg="${m2s_dir}.tar.gz"
cp $HOME/m2s-client-kit/tmp/m2s-bin/$m2s_pkg $temp_dir || exit 1

# Extract development package
cd $temp_dir
tar -xzf $m2s_pkg || exit 1
cd $temp_dir/$m2s_dir/src || exit 1

# Initial build
cd $temp_dir/$m2s_dir
echo -n "Initial build"
./configure --enable-debug >/dev/null 2>&1 || error "build failed"
make >/dev/null 2>&1 || error "build failed"
echo " - ok"

# List files in distribution package
cd $temp_dir/$m2s_dir/src || exit 1
file_list=`find . -type f | grep -v "\.svn" | grep "\.c$"`
cd $temp_dir/$m2s_dir

# Check files
for file in $file_list
do
	echo "File $file:"
	file="src/$file"

	python <<< "
import os
import re
import sys

f = open('$file', 'r')
lines = f.readlines()
f.close()
for line_num in range(len(lines)):
	
	# Discard line that is not an '#include'
	line = lines[line_num]
	m = re.match(r\"\\#include *([^ \\n]*)[ \\n]*\", line)
	if not m:
		continue
	
	# Print included file
	included_file = m.group(1)
	sys.stdout.write('\tchecking include %s ... ' % (included_file))
	
	# Make copy of file without that line
	new_lines = lines[:];
	del new_lines[line_num]
	f = open('$file', 'w')
	f.writelines(new_lines)
	f.close()

	# Try to compile
	result = os.system('make >/dev/null 2>&1')

	# Restore original file
	f = open('$file', 'w')
	f.writelines(lines)
	f.close()

	# Result
	if result == 2:
		exit(1)
	elif result:
		sys.stdout.write('ok\n')
	else:
		sys.stdout.write('REDUNDANT\n')
" || break
done

# End
rm -rf $temp_dir
echo
exit 0

