#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
m2s_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/m2s-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

cluster_name="minibench-emu"
bench_list="test-sort test-printf"


#
# Syntax
#

function syntax()
{
	cat << EOF

Run a simulation for benchmark MatrixMultiplication in suite AMDAPP-2.5, using a
functional emulation, and activating the self-check option in the benchmark.
Square matrices are multiplied with sizes ranging between 16 x 16 and 1k x 1k.

* Secondary verification scripts
	None

* Associated clusters
	mmul-emu

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
	temp=`getopt -o r: -l configure-args:,tag:,exe: -n $prog_name -- "$@"`
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
		--exe) exe=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done
	[ -z "$revision" ] || revision_arg="-r $revision"
	[ -z "$tag" ] || tag_arg="--tag $tag"
	[ -z "$configure_args" ] || configure_args_arg="--configure-args \"$configure_arg\""
	[ -z "$exe" ] || exe_arg="--exe $exe"

	# Get argument
	[ $# == 1 ] || error "syntax: submit <server>[:<port>] [<options>]"
	server_port=$1

	# Create cluster
	$m2s_cluster_sh create $cluster_name || exit 1
	for bench in $bench_list
	do
		$m2s_cluster_sh add $cluster_name $bench minibench/$bench \
			|| exit 1
	done

	# Submit cluster
	$m2s_cluster_sh submit $cluster_name $server_port \
		$revision_arg $tag_arg $configure_args_arg $exe_arg \
		|| exit 1
	
elif [ "$command" == kill ]
then

	# Kill cluster
	$m2s_cluster_sh kill $cluster_name

elif [ "$command" == state ]
then

	# Return state of cluster
	$m2s_cluster_sh state $cluster_name

elif [ "$command" == wait ]
then

	# Wait for cluster
	$m2s_cluster_sh wait $cluster_name

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

	# Import cluster if needed
	cluster_path="$HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name"
	if [ ! -d "$cluster_path" -o "$force" == 1 ]
	then
		$m2s_cluster_sh import $cluster_name \
			|| exit 1
	fi

	# Check output for each problem size
	passed_count=0
	failed_count=0
	crashed_count=0
	unknown_count=0
	total=0
	for bench in $bench_list
	do
		sim_err="$cluster_path/$bench/sim.err"
		sim_out="$cluster_path/$bench/ctx-0/sim.out"
		sim_ref="$cluster_path/$bench/ctx-0/sim.ref"
		total=`expr $total + 1`

		# Look for 'fatal'/'panic' in Multi2Sim output
		grep -i "\(^fatal\)\|\(^panic\)" $sim_err > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			crashed_count=`expr $crashed_count + 1`
			echo "$bench - crashed"
			continue
		fi

		# Check that simulation finished
		sim_finished=`$inifile_py $sim_err exists CPU`
		if [ "$sim_finished" == 0 ]
		then
			unknown_count=`expr $unknown_count + 1`
			echo "$bench - unknown"
			continue
		fi

		# Compare reference and effective outputs
		diff $sim_out $sim_ref > /dev/null
		retval=$?

		# Outputs match
		if [ "$retval" == 0 ]
		then
			passed_count=`expr $passed_count + 1`
		else
			failed_count=`expr $failed_count + 1`
			echo "$bench - failed"
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
	$m2s_cluster_sh remove $cluster_name

else

	error "$command: invalid command"

fi

