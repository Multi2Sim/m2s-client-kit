#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
m2s_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/m2s-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

cluster_name="amdapp-2.5-si-emu"


#
# Syntax
#

function syntax()
{
	cat << EOF

Run emulation for 'amdapp-2.5-si' benchmarks, activating the self-check option. The
result of the simulations are then checked for 'Passed' or 'Failed' messages to
validate the Multi2Sim Southern Islands emulator.

* Secondary verification scripts
	None

* Associated clusters
	amdapp-2.5-si-emu

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
	exe=
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

	# BinarySearch
	bench_name="BinarySearch"
	size_list="65536 131072 262144 524288 1048576 2097152"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BinomialOption
	bench_name="BinomialOption"
	size_list="128 192 256 320 384 512"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BitonicSort
	bench_name="BitonicSort"
	size_list="1024 2048 4096 8192 16384 32768"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BlackScholes
	# NOTE: sizes "8192 16384 32768 65536 131072 262144" provide exactly
	# the same number of simulated instructions.
	bench_name="BlackScholes"
	size_list="262144 1048576 8388608"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# BoxFilter
	#bench_name="BoxFilter"
	#size_list="1"
	#size_index=0
	#for size in $size_list
	#do
	#	$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
	#		amdapp-2.5-si/$bench_name \
	#		--sim-arg "--si-sim functional" \
	#		--bench-arg " -q -e" \
	#		|| exit 1
	#	size_index=`expr $size_index + 1`
	#done
	
	# DCT
	bench_name="DCT"
	size_list="128 256 512 768 896 1024"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# DwtHaar1D
	bench_name="DwtHaar1D"
	size_list="4096 8192 16384 32768 65536 131072"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# FastWalshTransform
	bench_name="FastWalshTransform"
	size_list="4096 16384 32768 65536 131072 262144"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# FFT
	# NOTE: '-x <size>' parameter does not have any effect here.
	bench_name="FFT"
	size_list="0"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# FloydWarshall
	bench_name="FloydWarshall"
	size_list="64 128 256"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# Histogram
	bench_name="Histogram"
	size_list="512 768 1024 1280 1536 1792"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done
	
	# MatrixMultiplication
	bench_name="MatrixMultiplication"
	size_list="32 64 128 192 256"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
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
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# PrefixSum
	bench_name="PrefixSum"
	size_list="16384"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# QuasiRandomSequence
	bench_name="QuasiRandomSequence"
	size_list="256 512 1024 2048 4096"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done


	# RadixSort
	# Note: sizes larger than 65536 fail natively, bad self-check implementation.
	#bench_name="RadixSort"
	#size_list="8192 16384 32768 65536"
	#size_index=0
	#for size in $size_list
	#do
	#	$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
	#		amdapp-2.5-si/$bench_name \
	#		--sim-arg "--si-sim functional" \
	#		--bench-arg "-x $size -q -e" \
	#		|| exit 1
	#	size_index=`expr $size_index + 1`
	#done

	# RecursiveGaussian
	bench_name="RecursiveGaussian"
	size_list="3 5 7 9 11"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# Reduction
	bench_name="Reduction"
	size_list="409600 819200 1228800 1638400 2048000 3276800"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done
	
	# ScanLargeArrays
	bench_name="ScanLargeArrays"
	size_list="8192 16384 32768 65536 131072 262144"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	
	# SimpleConvolution
	bench_name="SimpleConvolution"
	size_list="64 128 256 512 1024"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -y $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# SobelFilter
	bench_name="SobelFilter"
	size_list="1 2 3 4 5 6"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
	done

	# URNG
	bench_name="URNG"
	size_list="1 2 3 4 5 6"
	size_index=0
	for size in $size_list
	do
		$m2s_cluster_sh add $cluster_name "$bench_name/$size_index" \
			amdapp-2.5-si/$bench_name \
			--sim-arg "--si-sim functional" \
			--bench-arg "-x $size -q -e" \
			|| exit 1
		size_index=`expr $size_index + 1`
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

	# Get list of benchmarks
	cd $cluster_path
	bench_list=
	dir_list=`find -maxdepth 1 -type d -regex "\./.*" | sort`
	for dir in $dir_list
	do
		bench_list="$bench_list ${dir:2}"
	done


	#
	# Verification of Emulation
	#

	# Get list of jobs
	job_list=`$m2s_cluster_sh list $cluster_name` || exit 1

	# Check output for each job in the cluster
	passed_count=0
	failed_count=0
	crashed_count=0
	unknown_count=0
	exit_code=0
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
	[ $total == $passed_count ] || exit_code=1


	#
	# Generate CPU/GPU cycles plot
	#

	# Create temporary files
	inifile_script=`mktemp`
	inifile_script_output=`mktemp`

	# Iterate through benchmarks
	bench_index=0
	bench_count=`echo $bench_list | wc -w`
	for bench in $bench_list
	do
		# Reset statistic files
		cpu_time_list=0
		cpu_inst_list=0
		gpu_time_list=0
		gpu_inst_list=0

		# Progress
		progress=`expr $bench_index \* 100 / $bench_count`
		echo -ne "\rPlotting ... ${progress}%"

		# Iterate through input sizes
		input_size=-1
		while true
		do
			# Input size directory
			input_size=`expr $input_size + 1`
			input_size_dir="$cluster_path/$bench/$input_size"
			[ -d "$input_size_dir" ] || break

			# Read results
			sim_err="$input_size_dir/sim.err"
			cp /dev/null $inifile_script
			echo "read x86 Time 0" >> $inifile_script
			echo "read x86 Instructions 0" >> $inifile_script
			echo "read SouthernIslands Time 0" >> $inifile_script
			echo "read SouthernIslands Instructions 0" >> $inifile_script
			$inifile_py $sim_err run $inifile_script > $inifile_script_output
			for i in 1
			do
				read cpu_time
				read cpu_inst
				read gpu_time
				read gpu_inst
			done < $inifile_script_output

			# Add to lists
			cpu_time_list="$cpu_time_list, $cpu_time"
			cpu_inst_list="$cpu_inst_list, $cpu_inst"
			gpu_time_list="$gpu_time_list, $gpu_time"
			gpu_inst_list="$gpu_inst_list, $gpu_inst"
		done

		python -c "
import matplotlib.pyplot as plt
import numpy


#
# CPU Emulation Time
#

cpu_time_list = [ $cpu_time_list ]
cpu_time_list.pop(0)

fig = plt.gcf()
fig.set_size_inches(4.0, 2.5)

plt.plot(cpu_time_list, 'bo-')
plt.title('CPU Emulation Time')
plt.xlabel('Problem Size')
plt.ylabel('Time (s)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(numpy.arange(len(cpu_time_list)))
plt.savefig('$cluster_path/$bench/cpu-time.png', dpi=100, bbox_inches='tight')


#
# CPU Instructions
#

cpu_inst_list = [ $cpu_inst_list ]
cpu_inst_list.pop(0)
cpu_inst_list[:] = [ x / 1000.0 for x in cpu_inst_list ]

plt.clf()
plt.plot(cpu_inst_list, 'bo-')
plt.title('CPU Emulated Instructions')
plt.xlabel('Problem Size')
plt.ylabel('Instructions (x 1k)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(numpy.arange(len(cpu_inst_list)))
plt.savefig('$cluster_path/$bench/cpu-inst.png', dpi=100, bbox_inches='tight')


#
# GPU Emulation Time
#

gpu_time_list = [ $gpu_time_list ]
gpu_time_list.pop(0)

plt.clf()
plt.plot(gpu_time_list, 'bo-')
plt.title('GPU Emulation Time')
plt.xlabel('Problem Size')
plt.ylabel('Time (s)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(numpy.arange(len(gpu_time_list)))
plt.savefig('$cluster_path/$bench/gpu-time.png', dpi=100, bbox_inches='tight')


#
# GPU Instructions
#

gpu_inst_list = [ $gpu_inst_list ]
gpu_inst_list.pop(0)
gpu_inst_list[:] = [ x / 1.0e3 for x in gpu_inst_list ]

plt.clf()
plt.plot(gpu_inst_list, 'bo-')
plt.title('GPU Emulated Instructions')
plt.xlabel('Problem Size')
plt.ylabel('Instructions (x 1k)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(numpy.arange(len(gpu_inst_list)))
plt.savefig('$cluster_path/$bench/gpu-inst.png', dpi=100, bbox_inches='tight')
" || exit 1

		# Next
		bench_index=`expr $bench_index + 1`

	done
	
	# Remove temporary file
	echo -e "\rPlotting ... 100%"
	rm -f $inifile_script_output
	rm -f $inifile_script



	#
	# Create HTML report
	#

	# Header
	html_file="$cluster_path/report.html"
	cp /dev/null $html_file
	echo "<html><body>" >> $html_file
	echo "<h1>Report for '$cluster_name'</h1>" >> $html_file

	# Benchmarks
	for bench in $bench_list
	do
		echo "<h2>$bench</h2>" >> $html_file
		echo "<img src=\"$bench/cpu-time.png\" width=300px/>" >> $html_file
		echo "<img src=\"$bench/cpu-inst.png\" width=300px/>" >> $html_file
		echo "<img src=\"$bench/gpu-time.png\" width=300px/>" >> $html_file
		echo "<img src=\"$bench/gpu-inst.png\" width=300px/>" >> $html_file
	done

	# End
	echo "</body></html>" >> $html_file


	#
	# Exit code
	#

	exit $exit_code

elif [ "$command" == remove ]
then

	# Remove cluster
	$m2s_cluster_sh remove $cluster_name

else

	error "$command: invalid command"

fi

