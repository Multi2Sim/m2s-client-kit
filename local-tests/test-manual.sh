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
    $prog_name [<options>] <range>


Arguments:

  <range>
	Tests to run. This value can be given in the following formats:
	all		Run all tests
	list		Show list of available tests
	<name>		Run test with name <id> (can be given with of without
			the '.sh' extension)
	<id>		Run test number <id>
	<id1>-<id2>	Run tests from <id1> to <id2>


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
[ $# == 0 ] && syntax

# Get list of configuration directories
cd $HOME/$M2S_CLIENT_KIT_TEST_MANUAL_PATH \
	|| error "cannot find 'test-manual' path"
script_list=""
for script in `find -maxdepth 1 -type f -executable | grep -v "\.svn" | grep -v "^\.$" | sort`
do
	script_list="$script_list ${script:2}"
done

# Obtain tests
final_script_list=
script_index_list=
script_list_count=`echo $script_list | awk '{ print NF }'`
if [ $# = 1 -a "$1" = "all" ]
then
	final_script_list="$script_list"
elif [ $# = 1 -a "$1" = "list" ]
then
	echo
	echo "List of available tests:"
	echo
	index=1
	for s in $script_list
	do
		s="${s%\.sh}"
		echo "${index}. $s"
		index=`expr $index + 1`
	done
	echo
	exit 0
else
	while [ $# -gt 0 ]
	do
		# Try to interpret argument as a test name
		name=$1
		id=`echo $script_list | awk '{
			for (i = 1; i <= NF; i++)
			{
				if ("'$name'" == $i || "'$name'" ".sh" == $i)
				{
					print i;
					exit;
				}
			}
			print 0
		}'`
		if [ $id != 0 ]
		then
			echo $name | egrep -q ".*\.sh" || name="${name}.sh"
			final_script_list="$final_script_list $name"
			script_index_list="$script_index_list $id"
			shift
			continue
		fi

		# Try to interpret as a test index
		tokens=`echo $1 | awk -F- '{ print NF }'`
		[ $tokens = 1 -o $tokens = 2 ] || error "$1: invalid argument"
		id1=`echo $1 | awk -F- '{ print $1 }'`
		id2=`echo $1 | awk -F- '{ print $2 }'`
		[ $tokens = 2 ] || id2="$id1"

		# Check rage
		[ $id1 -ge 1 -a $id1 -le $script_list_count ] || error "$id1 is an invalid test index"
		[ $id2 -ge 1 -a $id2 -le $script_list_count ] || error "$id2 is an invalid test index"
		for i in `seq $id1 $id2`
		do
			s=`echo $script_list | awk '{ print $'$i' }'`
			final_script_list="$final_script_list $s"
			script_index_list="$script_index_list $i"
		done
		shift
	done
fi
script_list="$final_script_list"

# Obtain local copy
$build_m2s_local_sh $rev_arg $tag_arg \
	|| exit 1

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
	# Get script index
	script_index=`echo $script_index_list | awk '{ print $'$index' }'`

	# Print script info
	clear
	echo $hline
	echo "= Test $script_index - '$script'"
	echo $hline
	echo
	./$script info

	# Wait for user input
	echo
	echo "Press ENTER to run the test ..."
	read
	echo $hline

	# Run test
	echo -n "Test $script_index - '$script' - " >> $log_file
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

