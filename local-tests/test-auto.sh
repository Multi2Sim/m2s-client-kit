#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_TEST_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-auto"

file_match_py="$M2S_CLIENT_KIT_BIN_PATH/file-match.py"
build_m2s_local_sh="$M2S_CLIENT_KIT_BIN_PATH/build-m2s-local.sh"
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
    $prog_name [<options>] <tests>

Arguments:

  <tests>
	List of tests to launch. The list can be formed of one or more of the
	following elements:

	list         List all available tests and stop.

	all	     Run all tests.

	<id>         Run test with numeric identifier <id>, as shown in the list
		     presented with command 'list'.

	<name>	     Run test named <name>.

	<id1>-<id2>  Run a range of tests, given by their numeric identifiers.


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
[ $# -gt 0 ] || syntax

# Get list of tests
cd $M2S_CLIENT_KIT_TEST_PATH || error "cannot find test path"
test_list=
for t in `find -maxdepth 1 -type d | grep -v "\.svn" | grep -v "^\.$" | sort`
do
	t="${t#\.\/}"
	test_list="$test_list $t"
done

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
		[ found=0 ] || continue
	done
	test_list="$new_test_list"
fi

#echo $test_list
#exit #############

# Obtain local copy
$build_m2s_local_sh $rev_arg $tag_arg || exit 1

# Run tests
echo
echo "Running tests:"
echo
total_count=0
failed_count=0
passed_count=0
for t in $test_list
do
	# Info
	echo -n $t
	test_path="$M2S_CLIENT_KIT_TEST_PATH/$t"
	test_sh="$test_path/test.sh"
	test_out="$test_path/test.out"
	test_err="$test_path/test.err"

	# Run script
	[ -f "$file_match_py" ] || error "$file_match_py: cannot run script"
	[ -f "$test_sh" ] || error "$test_sh: unexisting test"
	cd $test_path || error "$test_path: unexisting directory"
	out="$M2S_CLIENT_KIT_TMP_PATH/test.out"
	err="$M2S_CLIENT_KIT_TMP_PATH/test.err"
	$test_sh >$out 2>$err

	# Check outputs
	failed=0
	if [ -f $test_out ]
	then
		$file_match_py $out $test_out || failed=1
	fi
	if [ -f $test_err ]
	then
		$file_match_py $err $test_err || failed=1
	fi

	# Remove temporaries
	rm -f $out $err

	# Report error
	total_count=`expr $total_count + 1`
	if [ $failed == 0 ]
	then
		echo " - passed"
		passed_count=`expr $passed_count + 1`
	else
		echo " - failed"
		failed_count=`expr $failed_count + 1`
	fi
done

# End
echo
echo "$total_count tests, $passed_count passed, $failed_count failed"
rm -f $temp_file
exit 0

