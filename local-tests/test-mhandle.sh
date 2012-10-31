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

# List files in distribution package
cd $temp_dir/$m2s_dir/src || exit 1
file_list=`find . -type f | grep -v "\.svn" | grep "\.c$"`

# Check files
missing_mhandle=0
for file in $file_list
do
	# Don't check if the current file is 'mhandle.c'
	echo $file | grep -q "\<mhandle.c$" \
		&& continue

	# Check if there are memory allocation calls
	grep "\(\<free *(\)\|\(\<malloc *(\)\|\(\<calloc *(\)\|\(\<strdup *\)\|\(\<strndup *\)" \
		$file -q \
		|| continue
	
	# Check if file includes 'mhandle.h'
	grep "#include .*\<mhandle\.h\>" $file -q \
		&& continue

	# Missing
	[ $missing_mhandle == 1 ] || echo
	missing_mhandle=1
	echo -e "\tmissing 'mhandle.h' - $file"
done

# Report error
if [ $missing_mhandle == 1 ]
then
	echo "Error: missing inclusions of 'mhandle.h' found"
	rm -rf $temp_dir
	exit 1
fi

# End
rm -rf $temp_dir
echo "Passed!"
exit 0

