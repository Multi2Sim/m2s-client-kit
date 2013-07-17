#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_TEST_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-manual"

inifile_py="$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
build_m2s_local_sh="$M2S_CLIENT_KIT_BIN_PATH/build-m2s-local.sh"
prog_name=$(echo $0 | awk -F/ '{ print $NF }')
log_file="$M2S_CLIENT_KIT_RESULT_PATH/test-manual.log"
temp_log_file="$M2S_CLIENT_KIT_TMP_PATH/test-manual.log"


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


Runs tests that require user interaction, such as visualization tools,
navigation through visual diagrams, observation of trends in results, etc.

To add a new test, you just need to add a new subdirectory under
'm2s-client-kit/local-tests/test-manual/' with the following files:

	* info.txt	Information describing the type of test and the expected
			output. When any user runs the test, he/she should be
			able to determine whether the results are correct or not
			from this description.
	* test.sh	Shell script swith the equence of commands running the
			test. Any additional file required by the test can be in
			this directory. But when many tests use the same files,
			this script can copy them from other directories.


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

# Get list of tests
cd $M2S_CLIENT_KIT_TEST_PATH || error "cannot find test path"
test_list=
for t in `find -maxdepth 1 -type d | grep -v "\.svn" | grep -v "^\.$" | sort`
do
	t="${t#\.\/}"
	test_list="$test_list $t"
done
test_count=`awk '{ print NF }' <<< "$test_list"`

# Get tests
if [ $# = 1 -a "$1" = "list" ]
then
	echo
	echo "List of available tests:"
	echo
	index=1
	for t in $test_list
	do
		echo "$index. $t"
		index=`expr $index + 1`
	done
	echo
	exit 0
elif [ $# = 1 -a "$1" = "all" ]
then

	# Nothing to do here
	# Keep all tests
	test_list="$test_list"

else
	new_test_list=""
	while [ $# != 0 ]
	do
		# Get argument
		arg=${1%\.sh}
		shift

		# Check if it's a test name
		found=0
		for t in $test_list
		do
			if [ "$t" = "$arg" ]
			then
				new_test_list="$new_test_list $t"
				found=1
				break
			fi
		done
		[ $found = 0 ] || continue

		# Check if it's one ID
		id_count=`awk -F- '{ print NF }' <<< "$arg"`
		if [ $id_count = 1 ]
		then
			egrep -q "^[0-9]+$" <<< "$arg" || error "$arg: invalid test"
			[ $arg -ge 1 -a $arg -le $test_count ] || error "test ID $arg out of range"
			t=`awk '{ print $'$arg' }' <<< "$test_list"`
			new_test_list="$new_test_list $t"
			continue
		fi

		# Check if it's an ID range
		if [ $id_count = 2 ]
		then
			id1=`awk -F- '{ print $1 }' <<< "$arg"`
			id2=`awk -F- '{ print $2 }' <<< "$arg"`
			egrep -q "^[0-9]+$" <<< "$id1" || error "$arg: invalid test"
			egrep -q "^[0-9]+$" <<< "$id2" || error "$arg: invalid test"
			[ $id1 -ge 1 -a $id1 -le $test_count ] || error "test ID $id1 out of range"
			[ $id2 -ge 1 -a $id2 -le $test_count ] || error "test ID $id2 out of range"
			for id in `seq $id1 $id2`
			do
				t=`awk '{ print $'$id' }' <<< "$test_list"`
				new_test_list="$new_test_list $t"
			done
			continue
		fi

		# Invalid
		error "$arg: invalid test"
	done
	test_list="$new_test_list"
fi

# Obtain local copy
$build_m2s_local_sh $rev_arg $tag_arg \
	|| exit 1

# Dump header in log file
echo >> $log_file
echo >> $log_file
echo ">>> Manual tests launched on `date`" >> $log_file

# Start execution
cd $M2S_CLIENT_KIT_TEST_PATH || exit 1
hline="================================================================================"
for t in $test_list
do
	# Check that script exists
	cd $M2S_CLIENT_KIT_TEST_PATH || exit 1
	if [ ! -f $t/test.sh ]
	then
		echo >&2
		echo "Test '$t' - failed (test script not found)" >> $log_file
		echo "error: file $t/test.sh not found" >&2
		echo "Press ENTER to continue ..."
		echo >&2
		read
		continue
	fi

	# Print script info
	clear
	echo $hline
	echo "= Test '$t'"
	echo $hline
	echo
	[ -e $t/info.txt ] && cat $t/info.txt

	# Wait for user input
	echo
	echo "Press ENTER to run the test ..."
	read
	echo $hline

	# Run test
	cd $M2S_CLIENT_KIT_TEST_PATH/$t
	echo -n "Test '$t' - " >> $log_file
	./test.sh 2>&1 | tee $temp_log_file
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

