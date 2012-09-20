#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
m2s_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/m2s-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

cluster_name="amdapp-2.5-evg-timing"


#
# Syntax
#

function syntax()
{
	cat << EOF

Run an Evergreen GPU timing simulation for the amdapp-2.5-evg SDK.

* Secondary verification scripts
	None

* Associated clusters
	amdapp-2.5-timing

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


# List subdirectories in path "$1" of level "$2"
list_dirs()
{
        local path=$1
        local level=$2
        local dirs=
        local i x found
        local fulldirs=$(find $path -mindepth $level -maxdepth $level -type d)
        
	for i in $fulldirs
	do
                i=$(echo $i | awk -F/ '{print $NF}')
                found=0

                for x in $dirs
		do
                        if [ $x == $i ]
			then
				found=1
			fi
                done

                if [ $found == 0 ]
		then
			dirs="$dirs $i"
			echo $i
		fi
        done
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


	# Add jobs
	num_compute_units_list="2 4 6 8 10 12 14 16 18 20"
	for num_compute_units in $num_compute_units_list
	do
		# Create configuration file
		gpu_config="$HOME/$M2S_CLIENT_KIT_TMP_PATH/gpu-config"
		cp /dev/null $gpu_config || exit 1
		echo "[ Device ]" >> $gpu_config
		echo "NumComputeUnits = $num_compute_units" >> $gpu_config

		# BinarySearch
		bench_name="BinarySearch"
		size="2097152"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# BinomialOption
		bench_name="BinomialOption"
		size="128"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# BitonicSort
		bench_name="BitonicSort"
		size="1024"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# BlackScholes
		bench_name="BlackScholes"
		size="1048576"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# BoxFilter
		#bench_name="BoxFilter"
		#size="1"
		#$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
		#	amdapp-2.5-evg/$bench_name \
		#	--sim-arg "--evg-sim detailed" \
		#	--sim-arg "--evg-config gpu-config" \
		#	--sim-arg "--evg-report report-gpu-pipeline" \
		#	--sim-arg "--mem-report report-mem" \
		#	--bench-arg " -q" \
		#	--send "$gpu_config" \
		#	|| exit 1
		
		# DCT
		bench_name="DCT"
		size="512"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -y $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# DwtHaar1D
		bench_name="DwtHaar1D"
		size="131072"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# FastWalshTransform
		bench_name="FastWalshTransform"
		size="262144"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# FloydWarshall
		bench_name="FloydWarshall"
		size="128"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# Histogram
		bench_name="Histogram"
		size="1792"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -y $size -q" \
			--send "$gpu_config" \
			|| exit 1
		
		# MatrixMultiplication
		bench_name="MatrixMultiplication"
		size="256"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -y $size -z $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# MatrixTranspose
		bench_name="MatrixTranspose"
		size="1024"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -y $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# PrefixSum
		bench_name="PrefixSum"
		size="16384"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# RadixSort
		bench_name="RadixSort"
		size="65536"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# RecursiveGaussian
		bench_name="RecursiveGaussian"
		size="3"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# Reduction
		bench_name="Reduction"
		size="1638400"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
		
		# ScanLargeArrays
		bench_name="ScanLargeArrays"
		size="262144"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		
		# SobelFilter
		bench_name="SobelFilter"
		size="5"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
			|| exit 1
	
		# URNG
		bench_name="URNG"
		size="2"
		$m2s_cluster_sh add $cluster_name "$bench_name/$num_compute_units" \
			amdapp-2.5-evg/$bench_name \
			--sim-arg "--evg-sim detailed" \
			--sim-arg "--evg-config gpu-config" \
			--sim-arg "--evg-report report-gpu-pipeline" \
			--sim-arg "--mem-report report-mem" \
			--bench-arg "-x $size -q" \
			--send "$gpu_config" \
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
	avail_count=0
	missing_count=0
	crashed_count=0
	exit_code=0
	total=0
	for job in $job_list
	do
		sim_err="$cluster_path/$job/sim.err"
		total=`expr $total + 1`

		# Check if results are available
		if [ ! -e "$sim_err" ]
		then
			missing_count=`expr $missing_count + 1`
			echo "$job - missing"
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

		# Check if GPU results section is available
		section_exists=`$inifile_py $sim_err exists Evergreen`
		if [ "$section_exists" == 0 ]
		then
			missing_count=`expr $missing_count + 1`
			echo "$job - missing"
			continue
		fi

		# Available
		avail_count=`expr $avail_count + 1`
	done

	# Summary. Exit with error code 1 if not all simulations passed
	echo -n "$total total, "
	echo -n "$avail_count available, "
	echo -n "$crashed_count crashed, "
	echo "$missing_count missing"
	[ $total == $avail_count ] || exit_code=1


	#
	# Generate CPU/GPU cycles plot
	#

	# Create temporary files
	inifile_script=`mktemp`
	inifile_script_output=`mktemp`

	# Directory lists
	bench_list=`list_dirs $cluster_path 1 | sort`
	num_compute_units_list=`list_dirs $cluster_path 2 | sort -n`

	# Iterate through benchmarks
	bench_index=0
	bench_count=`echo $bench_list | wc -w`
	for bench in $bench_list
	do
		# Reset statistic lists
		gpu_compute_units_list=0
		gpu_cycles_list=0

		# Progress
		progress=`expr $bench_index \* 100 / $bench_count`
		echo -ne "\rPlotting ... ${progress}%"

		# Iterate through number of compute units
		for num_compute_units in $num_compute_units_list
		do
			# Job directory
			job_dir="$cluster_path/$bench/$num_compute_units"
			sim_err="$job_dir/sim.err"
			[ -e "$sim_err" ] || continue

			# Read results
			cp /dev/null $inifile_script
			echo "read Evergreen Cycles 0" >> $inifile_script
			$inifile_py $sim_err run $inifile_script > $inifile_script_output
			for i in 1
			do
				read gpu_cycles
			done < $inifile_script_output

			# Add to lists
			gpu_compute_units_list="$gpu_compute_units_list, $num_compute_units"
			gpu_cycles_list="$gpu_cycles_list, $gpu_cycles"
		done

		python -c "
import matplotlib.pyplot as plt
import numpy


#
# GPU Cycles
#

gpu_cycles_list = [ $gpu_cycles_list ]
gpu_cycles_list.pop(0)
gpu_cycles_list[:] = [ x / 1.0e3 for x in gpu_cycles_list ]

gpu_compute_units_list = [ $gpu_compute_units_list ]
gpu_compute_units_list.pop(0)

fig = plt.gcf()
fig.set_size_inches(4.0, 2.5)

plt.plot(gpu_cycles_list, 'bo-')
plt.title('GPU Execution Time')
plt.xlabel('Number of compute units')
plt.ylabel('Execution Time (1k cycles)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(numpy.arange(len(gpu_compute_units_list)), gpu_compute_units_list)
plt.savefig('$cluster_path/$bench/gpu-cycles.png', dpi=100, bbox_inches='tight')

" || exit 1

		# Next
		bench_index=`expr $bench_index + 1`

	done
	
	# Remove temporary files
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
		echo "<img src=\"$cluster_path/$bench/gpu-cycles.png\" width=300px/>" >> $html_file
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

