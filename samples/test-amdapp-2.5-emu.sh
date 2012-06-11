#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
sim_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/sim-cluster.sh"


cluster_name="amdapp-2.5-emu"


#
# Syntax
#

function syntax()
{
	cat << EOF

Run emulation for AMDAPP-2.5 benchmarks, activating the self-check option. The
result of the simulations are then checked for 'Passed' or 'Failed' messages to
validate the Multi2Sim Evergreen emulator.

* Secondary verification scripts
	None

* Associated clusters
	amdapp-2.5-emu

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
	temp=`getopt -o r: -l configure-args: -n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	revision=
	configure_args=
	while true
	do
		case "$1" in
		-r) revision=$2 ; shift 2 ;;
		--configure-args) configure_args=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done
	[ -z "$revision" ] || revision_arg="-r $revision"
	[ -z "$configure_args" ] || configure_args_arg="--configure-args \"$configure_arg\""

	# Get argument
	[ $# == 1 ] || error "syntax: submit <server>[:<port>] [<options>]"
	server_port=$1

	# Create cluster
	$sim_cluster_sh create $cluster_name || exit 1

	# BinarySearch
	bench_name="BinarySearch"
	size_list="2048 4096 8192 16384 32768 65536 131072 262144"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BinomialOption
	bench_name="BinomialOption"
	size_list="128 192 256 320 384 512 640"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BitonicSort
	bench_name="BitonicSort"
	size_list="1024 2048 3072 4096 5120 7168 8192 10240"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BlackScholes
	bench_name="BlackScholes"
	size_list="262144 1048576 8388608"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done	
	# DCT
	bench_name="DCT"
	size_list="128 256 512 768 896 1024 1280"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# DwtHaar1D
	bench_name="DwtHaar1D"
	size_list="2048 4096 8192 16384 32768 65536 131072"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# FastWalshTransform
	bench_name="FastWalshTransform"
	size_list="2048 4096 16384 32768 65536 131072 524288"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# FloydWarshall
	bench_name="FloydWarshall"
	size_list="64 128 256 512"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# Histogram
	bench_name="Histogram"
	size_list="256 512 768 1024 1152 1280 2048 2560"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done
	
	# MatrixMultiplication
	bench_name="MatrixMultiplication"
	size_list="16 32 64 128 256 512"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -y $size -z $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# MatrixTranspose
	bench_name="MatrixTranspose"
	size_list="16 32 64 128 256 512 1024"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# PrefixSum
	bench_name="PrefixSum"
	size_list="16384 32768 65536 131072 524288 1048576"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done


	# RadixSort
	bench_name="RadixSort"
	size_list="512000 1024000 1536000 2048000 2560000"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# RecursiveGaussian
	bench_name="RecursiveGaussian"
	size_list="1 2 3 4 5 6 7 8 9 10"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# Reduction
	bench_name="Reduction"
	size_list="409600 819200 1228800 1638400 2048000 3276800 4096000"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done
	
	# ScanLargeArrays
	bench_name="ScanLargeArrays"
	size_list="1024 2048 4096 8192 16384 32768 65536 131072 262144"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	
	# SobelFilter
	bench_name="SobelFilter"
	size_list="1 2 3 4 5 6 7 8 9 10"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# URNG
	bench_name="URNG"
	size_list="1 2 3 4 5 6 7 8 9 10"
	size_index=0
	for size in $size_list
	do
		$sim_cluster_sh add $cluster_name "$bench_name/$size_index" \
			AMDAPP-2.5/$bench_name \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done			
	
	
	
	# Submit cluster
	$sim_cluster_sh submit $cluster_name $server_port \
		$revision_arg $configure_args_arg \
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

	# Import cluster if needed
	cluster_path="$HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name"
	if [ ! -d "$cluster_path" -o "$force" == 1 ]
	then
		$sim_cluster_sh import $cluster_name \
			|| exit 1
	fi

	# Get list of jobs
	job_list=`$sim_cluster_sh list $cluster_name` || exit 1

	# Check output for each job in the cluster
	passed_count=0
	failed_count=0
	crashed_count=0
	unknown_count=0
	total=0
	for job in $job_list
	do
		sim_out="$cluster_path/$job/ctx-0/sim.out"
		sim_err="$cluster_path/$job/sim.err"
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
		grep -i "\(^[ ]*Failed\)\|\(^[ ]*Error\)" $sim_out > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			failed_count=`expr $failed_count + 1`
			echo "$job - failed"
			continue
		fi

		# Look for 'fatal'/'panic' in Multi2Sim output
		grep -i "\(^fatal\)\|\(^panic\)" $sim_err > /dev/null 2>&1
		retval=$?
		if [ "$retval" == 0 ]
		then
			crashed_count=`expr $crashed_count + 1`
			echo "$job - crashed"
			continue
		fi

		# Unknown
		unknown_count=`expr $unknown_count + 1`
		echo "$job - unknown"
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

