#!/bin/bash

M2S_CLIENT_KIT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/..
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_TEST_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-auto"

result_path="$M2S_CLIENT_KIT_RESULT_PATH/test-auto"
log_file="$M2S_CLIENT_KIT_RESULT_PATH/test-auto.log"
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
	sed_command='sed '"'"'s/\([]\^$*+?.()|{}[]\)/\\\1/g'"'"' test.out'
	cat << EOF

Syntax:
    $prog_name [<options>] <tests>

Runs simple tests and compares the standard output and standard error output
agains templates given as regular expressions. To add another test, you just
need to create one more subdirectory, with the following files:

	* test.sh   File containing the commands to be launched.
	* test.out  File containing a Python-like regular expression that the
		    standard output should match to pass the test.
	* test.err  File containing a regular expression that the standard error
	            output should match.

File 'test.sh' is mandatory and must appear in every test subdirectory. When the
script is invoked, it will be done on an empty temporary directory. Also, the
script can assume that the following environment variables are set:

	* M2S_BUILD_PATH	Path containing a built copy of the Multi2Sim
				tree. For example, source code files are
				accessible through \$M2S_BUILD_PATH/src.
	* M2S_TEST_PATH		Path containing all local tests. If the script
				needs files present in other tests, they can be
				accessed using this variable as a root.
	* M2S			Multi2Sim executable.
	* M2C			Multi2C executable.

Files 'test.out' and 'test.err' are optional. If either one is missing, that
specific check will not be performed. If you need to create a regular expression
to match exactly the content of an existing file, you can use the following
command to escape all special characters:

	$sed_command

Though the basic syntax of Python regular expressions matches Unix expressions,
more complex expression have a Python-specific syntax. More information on
Python regular expressions can be found at

	http://docs.python.org/2/library/re.html


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
$build_m2s_local_sh $rev_arg $tag_arg || exit 1

# Create path for results and clear it
mkdir -p $result_path || exit 1
rm -f "$result_path/*"
rm -f $log_file

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
	out_copy="$result_path/$t.out"
	err_copy="$result_path/$t.err"
	M2S_TEST_PATH="$M2S_CLIENT_KIT_TEST_PATH" \
		       M2S_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build" \
		       M2S="$M2S_CLIENT_KIT_TMP_PATH/m2s-build/bin/m2s" \
		       M2C="$M2S_CLIENT_KIT_TMP_PATH/m2s-build/bin/m2c" \
		       timeout 10s $test_sh >$out 2>$err

	# Check outputs
	failed=0
	failed_out=0
	failed_err=0
	if [ -f $test_out ]
	then
		$file_match_py $out $test_out
		if [ $? != 0 ]
		then
			cp $out $out_copy
			failed_out=1
			failed=1
		fi
	fi
	if [ -f $test_err ]
	then
		$file_match_py $err $test_err
		if [ $? != 0 ]
		then
			cp $err $err_copy
			failed_err=1
			failed=1
		fi
	fi

	# Remove temporaries
	rm -f $out $err

	# Report error
	total_count=`expr $total_count + 1`
	if [ $failed == 0 ]
	then
		passed_count=`expr $passed_count + 1`
		echo " - passed"
	else
		echo
		echo
		failed_count=`expr $failed_count + 1`
		[ $failed_out = 0 ] || echo -e "\tMismatch in stdout - copy left in $out_copy"
		[ $failed_err = 0 ] || echo -e "\tMismatch in stderr - copy left in $err_copy"
		echo -e "\tFAILED"
		echo
	fi
done

# End
echo
echo "$total_count tests, $passed_count passed, $failed_count failed"
rm -f $temp_file
exit 0

