#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
m2s_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/m2s-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

nthreads_list="1 2 4 8 16"

cluster_name="parsec-2.1-emu"
cluster_desc="
Run emulation of the PARSEC-2.1 benchmark suite. For each benchmark, the number of
threads is set to powers of 2 between 1 and 16. The default (Medium) input size
is used as the data set.

Cluster: $cluster_name
Secondary scripts: -
"



#
# Syntax
#

function syntax()
{
	echo $cluster_desc
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

	# Get benchmark list
	bench_list=`$m2s_cluster_sh list-bench $server_port parsec-2.1` || exit 1

	# Create cluster
	$m2s_cluster_sh create $cluster_name || exit 1

	# Add jobs
	for bench in $bench_list
	do
		for nthreads in $nthreads_list
		do
			$m2s_cluster_sh add $cluster_name $bench/$nthreads \
				-p $nthreads parsec-2.1/$bench || exit 1
		done
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

	# Check simulation output for each job
	available_count=0
	crashed_count=0
	unknown_count=0
	exit_code=0
	total=0
	for job in $job_list
	do
		sim_out="$cluster_path/$job/ctx-0/sim.out"
		sim_err="$cluster_path/$job/sim.err"
		total=`expr $total + 1`

		# Look for section [CPU] in error output
		section_exists=`$inifile_py $sim_err exists CPU`
		if [ "$section_exists" == 1 ]
		then
			available_count=`expr $available_count + 1`
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

	# Summary. Exit with error code 1 if any simulation is
	# not available or crashed
	echo -n "$total total, "
	echo -n "$available_count available, "
	echo -n "$crashed_count crashed, "
	echo "$unknown_count unknown"
	[ $total == $available_count ] || exit_code=1



	#
	# Generate plots
	#

	# Create temporary files
	inifile_script=`mktemp`
	inifile_script_output=`mktemp`

	# Iterate through benchmarks
	for bench in $bench_list
	do
		# Reset statistic files
		cpu_time_list=0
		cpu_inst_list=0

		# Iterate through number of threads
		for nthreads in $nthreads_list
		do
			# Read results
			job_dir="$cluster_path/$bench/$nthreads"
			sim_err="$job_dir/sim.err"
			cp /dev/null $inifile_script
			echo "read CPU Time 0" >> $inifile_script
			echo "read CPU Instructions 0" >> $inifile_script
			$inifile_py $sim_err run $inifile_script > $inifile_script_output
			for i in 1
			do
				read cpu_time
				read cpu_inst
			done < $inifile_script_output

			# Add to lists
			cpu_time_list="$cpu_time_list, $cpu_time"
			cpu_inst_list="$cpu_inst_list, $cpu_inst"
		done

		python -c "
import matplotlib.pyplot as plt


#
# CPU Emulation Time
#

cpu_time_list = [ $cpu_time_list ]
cpu_time_list.pop(0)

fig = plt.gcf()
fig.set_size_inches(4.0, 2.5)

plt.plot(cpu_time_list, 'bo-')
plt.title('Emulation Time')
plt.xlabel('Number of threads')
plt.ylabel('Time (s)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(range(len(cpu_time_list)), '$nthreads_list'.split())
plt.savefig('$cluster_path/$bench/cpu-time.png', dpi=100, bbox_inches='tight')


#
# CPU Instructions
#

cpu_inst_list = [ $cpu_inst_list ]
cpu_inst_list.pop(0)
cpu_inst_list[:] = [ x / 1.0e6 for x in cpu_inst_list ]

plt.clf()
plt.plot(cpu_inst_list, 'bo-')
plt.title('x86 Instructions')
plt.xlabel('Number of threads')
plt.ylabel('Instructions (x 1M)')
plt.margins(0.05, 0)
plt.grid(True)
plt.ylim(ymin = 0)
plt.xticks(range(len(cpu_time_list)), '$nthreads_list'.split())
plt.savefig('$cluster_path/$bench/cpu-inst.png', dpi=100, bbox_inches='tight')
" || exit 1
	done
	
	# Remove temporary file
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
	echo "<p>$cluster_desc</p>" >> $html_file

	# Benchmarks
	for bench in $bench_list
	do
		echo "<h2>$bench</h2>" >> $html_file
		echo "<img src=\"$cluster_path/$bench/cpu-time.png\" width=300px/>" >> $html_file
		echo "<img src=\"$cluster_path/$bench/cpu-inst.png\" width=300px/>" >> $html_file
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

