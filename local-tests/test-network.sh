#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_TEST_NETWORK_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-network"

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
cd $HOME/$M2S_CLIENT_KIT_TEST_NETWORK_PATH \
	|| error "cannot find NETWORK test path"
config_dir_list=`find -maxdepth 1 -type d | grep -v "\.svn" | grep -v "^\.$"`

# Run tests
total_count=0
failed_count=0
passed_count=0
for config_dir in $config_dir_list
do
	# Info
	echo ${config_dir:2}
	config_full_path="$HOME/$M2S_CLIENT_KIT_TEST_NETWORK_PATH/$config_dir"

	# Get list of tests
	cd $HOME/$M2S_CLIENT_KIT_TEST_NETWORK_PATH/$config_dir \
		|| error "cannot cd to test directory"
	test_dir_list=`find -maxdepth 1 -type d | grep -v "\.svn" | grep -v "^\.$"`

	# Configuration files
	net_config="$config_full_path/net-config"
	[ -e "$net_config" ] || error "missing net-config in $config_dir"

	# Run tests
	temp_file=`mktemp`
	for test_dir in $test_dir_list
	do
		# Get test directory
		test_full_path="$HOME/$M2S_CLIENT_KIT_TEST_NETWORK_PATH/$config_dir/$test_dir"

		# Check Multi2Sim executable
		m2s_bin="$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-bin/m2s"
		[ -e $m2s_bin ] || error "cannot find Multi2Sim binary"

		# Reconstruct memory configuration file with commands
		net_config_commands="$HOME/$M2S_CLIENT_KIT_TMP_PATH/net-config"
		cp $net_config $net_config_commands || error "failed to overwrite net-config"
		cat "$test_full_path/commands" >> $net_config_commands \
			|| error "missing 'commands' in $config_dir - $test_dir"

		# Launch
		echo -ne "\t${test_dir:2}"
		$m2s_bin --net-sim mynet --net-config $net_config_commands \
			--net-max-cycles 10 >$temp_file 2>&1
		err=$?

		# If simulation terminated OK, check output
		if [ "$err" == 0 ]
		then
			grep -q "^>>> .* - failed$" $temp_file
			[ $? == 1 ] || err=1
		fi

		# Report error
		total_count=`expr $total_count + 1`
		if [ $err == 0 ]
		then
			echo " - passed"
			passed_count=`expr $passed_count + 1`
		else
			echo " - failed"
			failed_count=`expr $failed_count + 1`
		fi
	done
done

# End
echo "$total_count tests, $passed_count passed, $failed_count failed"
rm -f $temp_file
exit 0

