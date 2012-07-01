#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_SCRIPT_PATH="$M2S_CLIENT_KIT_PATH/samples/test-nmoesi"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
sim_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/sim-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

cluster_name="test-nmoesi"



#
# Syntax
#

function syntax()
{
	cat << EOF

Run a verification of the NMOESI coherence protocol.

* Secondary verification scripts
	None

* Associated clusters
	test-nmoesi

--

EOF

	# Print verification script interface
	cat $HOME/$M2S_CLIENT_KIT_DOC_PATH/verification-script-interface.txt
	exit 1
}


function error()
{
	echo -e "\nerror: $1\n" >&2
	exit 1
}




#
# Main Program
#

# Command
if [ $# -lt 1 ]
then
	syntax
fi
command=$1 ; shift

# Process command
if [ "$command" == submit ]
then

	# Options
	temp=`getopt -o r: -l configure-args:,tag: -n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	revision=
	tag=
	configure_args=
	while true
	do
		case "$1" in
		-r) revision=$2 ; shift 2 ;;
		--tag) tag=$2 ; shift 2 ;;
		--configure-args) configure_args=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done
	[ -z "$revision" ] || revision_arg="-r $revision"
	[ -z "$tag" ] || tag_arg="--tag $tag"
	[ -z "$configure_args" ] || configure_args_arg="--configure-args \"$configure_arg\""

	# Get argument
	[ $# == 1 ] || error "syntax: submit <server>[:<port>] [<options>]"
	server_port=$1

	# Create cluster
	$sim_cluster_sh create $cluster_name || exit 1

	# Create test cases
	config_id=0
	while true
	do
		# Check if configuration exists
		config_path="$HOME/$M2S_CLIENT_KIT_SCRIPT_PATH/config-$config_id"
		[ -d "$config_path" ] || break

		# Tests
		test_id=0
		while true
		do
			# Check if test exists
			test_path="$config_path/test-$test_id"
			[ -d "$test_path" ] || break

			# CPU configuration file
			cpu_config_arg=
			cpu_config_send_arg=
			if [ -e $config_path/cpu-config ]
			then
				cpu_config_arg="--cpu-config cpu-config"
				cpu_config_send_arg="--send $HOME/$M2S_CLIENT_KIT_TMP_PATH/cpu-config"
				cp $config_path/cpu-config $HOME/$M2S_CLIENT_KIT_TMP_PATH || exit 1
			fi

			# GPU configuration file
			gpu_config_arg=
			gpu_config_send_arg=
			if [ -e $config_path/gpu-config ]
			then
				gpu_config_arg="--gpu-config gpu-config"
				gpu_config_send_arg="--send $HOME/$M2S_CLIENT_KIT_TMP_PATH/gpu-config"
				cp $config_path/gpu-config $HOME/$M2S_CLIENT_KIT_TMP_PATH || exit 1
			fi

			# Memory configuration file
			mem_config_arg="--mem-config mem-config"
			mem_config_send_arg="--send $HOME/$M2S_CLIENT_KIT_TMP_PATH/mem-config"
			cp $config_path/mem-config $HOME/$M2S_CLIENT_KIT_TMP_PATH || exit 1
			cat $test_path/commands >> $HOME/$M2S_CLIENT_KIT_TMP_PATH/mem-config || exit 1

			# Add job
			$sim_cluster_sh add $cluster_name "config-$config_id/test-$test_id" \
				--sim-args "$cpu_config_arg $gpu_config_arg $mem_config_arg" \
				--sim-args "--cpu-sim detailed" \
				$cpu_config_send_arg $gpu_config_send_arg $mem_config_send_arg \
				|| exit 1

			# Next
			test_id=`expr $test_id + 1`
		done

		# Next
		config_id=`expr $config_id + 1`
	done

	# Submit cluster
	$sim_cluster_sh submit $cluster_name $server_port \
		$revision_arg $tag_arg $configure_args_arg \
		|| exit 1
	
elif [ "$command" == kill ]
then

	# Kill cluster
	$sim_cluster_sh kill $cluster_name

elif [ "$command" == state ]
then

	# Return state of cluster
	$sim_cluster_sh state $cluster_name

elif [ "$command" == wait ]
then

	# Wait for cluster
	$sim_cluster_sh wait $cluster_name

elif [ "$command" == process ]
then

	# Options
	temp=`getopt -o f -n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	force=0
	while true
	do
		case "$1" in
		-f) force=1 ; shift 1 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Import cluster if needed.
	# Use '-a' option in 'sim-cluster.sh import' to receive the benchmark
	# binaries as well.
	cluster_path="$HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name"
	if [ ! -d "$cluster_path" -o "$force" == 1 ]
	then
		$sim_cluster_sh import -a $cluster_name \
			|| exit 1
	fi

	# Check output for each test
	passed_count=0
	failed_count=0
	crashed_count=0
	unknown_count=0
	total=0
	config_id=-1
	test_id=-1
	while true
	do
		# Next
		test_id=`expr $test_id + 1`
		config_path="$cluster_path/config-$config_id"
		test_path="$config_path/test-$test_id"
		if [ ! -d "$test_path" ]
		then
			config_id=`expr $config_id + 1`
			test_id=0
			config_path="$cluster_path/config-$config_id"
			test_path="$config_path/test-$test_id"
			[ -d "$test_path" ] || break
		fi
		test_name="config-$config_id/test-$test_id"

		# Files
		sim_err="$test_path/sim.err"
		total=`expr $total + 1`

		# Unknown if any output file does not exist
		if [ ! -e "$sim_err" ]
		then
			unknown_count=`expr $unknown_count + 1`
			echo "$test_name - unknown"
			continue
		fi

		# Look for 'fatal'/'panic' in Multi2Sim output
		grep -i "\(^fatal\)\|\(^panic\)" $sim_err > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			crashed_count=`expr $crashed_count + 1`
			echo "$test_name - crashed"
			continue
		fi

		# Find NMOESI check and its result
		grep "^>>> check .* - failed$" $sim.err > /dev/null 2>&1
		retval=$?

		# Outputs match
		if [ "$retval" == 0 ]
		then
			failed_count=`expr $failed_count + 1`
			echo "$test_name - failed"
		else
			passed_count=`expr $passed_count + 1`
		fi
	done

	# Summary. Exit with error code 1 if not all simulations passed
	echo -n "$total total, "
	echo -n "$passed_count passed, "
	echo -n "$failed_count failed, "
	echo -n "$crashed_count crashed, "
	echo "$unknown_count unknown"
	[ $total == $passed_count ] || exit 1

elif [ "$command" == remove ]
then

	# Remove cluster
	$sim_cluster_sh remove $cluster_name

else

	error "$command: invalid command"

fi

