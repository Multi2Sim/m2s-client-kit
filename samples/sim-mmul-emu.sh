#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
sim_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/sim-cluster.sh"


cluster_name="mmul-emu"
matrix_size_list="16 32 64 128 256 512 1024"


#
# Syntax
#

function syntax()
{
	cat << EOF

Syntax:
    $prog_name <command> [<arguments>]

Run a simulation for benchmark MatrixMultiplication in suite AMDAPP-2.5, using a
functional emulation, and activating the self-check option in the benchmark.
Square matrices are multiplied with sizes ranging between 16 x 16 and 1k x 1k.

Possible values for <command> are:

  run <server>[:<port>]
      Create a cluster and submit it to a server, optionally specifying the SSH
      port. Commands "sim-cluster.sh list/state/kill/import/remove" can be used
      later to manage the created cluster.

  process [-f]
      Import output files of the cluster if they do not exist already locally,
      and process them to generate plots, filter data, validate results, etc.
      Optional flag '-f' forces the output files to be imported again from the
      server, even if they already existed locally.

EOF
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
if [ "$command" == run ]
then

	# Get argument
	[ $# == 1 ] || error "invalid syntax for command"
	server_port=$1

	# Create cluster
	$sim_cluster_sh create $cluster_name || exit 1
	for x in $matrix_size_list
	do
		$sim_cluster_sh add $cluster_name "size-$x" \
			AMDAPP-2.5/MatrixMultiplication \
			--bench-arg "-x $x -y $x -z $x -q -e" \
			|| exit 1
	done

	# Submit cluster
	$sim_cluster_sh submit $cluster_name $server_port \
		|| exit 1
	
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
		$sim_cluster_sh import $cluster_name \
			|| exit 1
	fi

	# Check output for each problem size
	passed_count=0
	failed_count=0
	crashed_count=0
	unknown_count=0
	total=0
	for x in $matrix_size_list
	do
		sim_out="$cluster_path/size-$x/ctx-0/sim.out"
		sim_err="$cluster_path/size-$x/sim.err"
		total=`expr $total + 1`

		# Look for 'Passed!' in simulation output
		grep -i "^Passed\!" $sim_out > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			passed_count=`expr $passed_count + 1`
			continue
		fi

		# Look for 'Failed'/'Error' in simulation output
		grep -i "\(^Failed\)\|\(^Error\)" $sim_out > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			failed_count=`expr $failed_count + 1`
			echo "Size $x - failed"
			continue
		fi

		# Look for 'fatal'/'panic' in Multi2Sim output
		grep -i "\(^fatal\)\|\(^panic\)" $sim_err > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			crashed_count=`expr $crashed_count + 1`
			echo "Size $x - crashed"
			continue
		fi

		# Unknown
		unknown_count=`expr $unknown_count + 1`
		echo "Size $x - unknown"
	done

	# Summary. Exit with error code 1 if not all simulations passed
	echo "$passed_count passed, $failed_count failed, $crashed_count crashed, $unknown_count unknown"
	[ $total == $passed_count ] || exit 1
else

	error "$command: invalid command"

fi

