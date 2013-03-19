#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_TEST_MANUAL_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-manual"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
build_m2s_local_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/build-m2s-local.sh"
prog_name=$(echo $0 | awk -F/ '{ print $NF }')
log_file="$HOME/$M2S_CLIENT_KIT_RESULT_PATH/test-manual.log"
temp_log_file="$HOME/$M2S_CLIENT_KIT_TMP_PATH/test-manual.log"


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
	-h|--help) syntax ;;
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

# Get list of configuration directories
cd $HOME/$M2S_CLIENT_KIT_TEST_MANUAL_PATH \
	|| error "cannot find 'test-manual' path"
script_list=""
for script in `find -maxdepth 1 -type f -executable | grep -v "\.svn" | grep -v "^\.$" | sort`
do
	script_list="$script_list ${script:2}"
done

# Dump header in log file
echo >> $log_file
echo >> $log_file
echo ">>> Manual tests launched on `date`" >> $log_file

# Start execution
cd $HOME/$M2S_CLIENT_KIT_TEST_MANUAL_PATH || exit 1
index=1
hline="================================================================================"
for script in $script_list
do
	# Print script info
	clear
	echo $hline
	echo "= Test $index - '$script'"
	echo $hline
	echo
	./$script info

	# Wait for user input
	echo
	echo "Press ENTER to run the test ..."
	read
	echo $hline

	# Run test
	echo -n "Test $index - '$script' - " >> $log_file
	./$script run 2>&1 | tee $temp_log_file
	echo $hline
	echo

	# Check success
	while [ 1 ]
	do
		echo -n "Was the test successful? [y/n] "
		read answer
		if [ "$answer" == "y" -o "$answer" == "Y" ]
		then
			echo "passed" >> $log_file
			break
		elif [ "$answer" == "n" -o "$answer" == "N" ]
		then
			echo "failed (output shown below)" >> $log_file
			echo >> $log_file
			echo $hline >> $log_file
			cat $temp_log_file >> $log_file
			echo $hline >> $log_file
			break
		fi
	done

	# Next
	index=`expr $index + 1`
done

# Final message
rm -f $temp_log_file
clear
echo "Manual tests finished, log dumped in '$log_file'"
echo
exit 0

