#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"

M2S_SERVER_KIT_PATH="m2s-server-kit"
M2S_SERVER_KIT_BIN_PATH="$M2S_SERVER_KIT_PATH/bin"
M2S_SERVER_KIT_RUN_PATH="$M2S_SERVER_KIT_PATH/run"
M2S_SERVER_KIT_TMP_PATH="$M2S_SERVER_KIT_PATH/tmp"
M2S_SERVER_KIT_BENCH_PATH="$M2S_SERVER_KIT_PATH/benchmarks"
M2S_SERVER_KIT_M2S_BIN_PATH="$M2S_SERVER_KIT_TMP_PATH/m2s-bin"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
inifile="$HOME/$M2S_CLIENT_KIT_TMP_PATH/sim-cluster.ini"


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
	prog=`echo $0 | awk -F/ '{print $NF}'`
	cat << EOF

Syntax:
    $prog <command> [<options>] <arguments>

EOF
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
command=$1
shift

# Create INI file if it does not exist
if [ ! -e $inifile ]
then
	touch $inifile || exit 1
fi

# Command = 'start'
if [ "$command" == "start" ]
then

	# Get cluster name
	if [ $# != 1 ]
	then
		syntax
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Info
	echo -n "starting cluster '$cluster_name'"

	# Check if cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_section`
	if [ "$cluster_exists" == 1 ]
	then
		error "cluster already started, commit or clear first."
	fi

	# Clear all sending files
	rm -f $HOME/$M2S_CLIENT_KIT_TMP_PATH/sim-cluster-file-*

	# Start cluster
	inifile_script=$(mktemp)
	echo "write $cluster_section NumJobs 0" >> $inifile_script
	echo "write $cluster_section NumSendFiles 0" >> $inifile_script
	$inifile_py $inifile run $inifile_script
	rm -f $inifile_script
	echo " - ok"

elif [ "$command" == "add" ]
then
	
	# Options
	temp=`getopt -o p: -l send:,sim-arg:,bench-arg:,data-set: \
		-n 'sim-cluster.sh' -- "$@"`
	if [ $? != 0 ] ; then exit 1 ; fi
	eval set -- "$temp"
	send_files=
	sim_args=
	bench_args=
	num_threads=1
	data_set="Default"
	while true
	do
		case "$1" in
		-p) num_threads=$2 ; shift $2 ;;
		--send) send_files="$send_files $2" ; shift 2 ;;
		--sim-arg) sim_args="$sim_args $2" ; shift 2 ;;
		--bench-arg) bench_args="$bench_args $2" ; shift 2 ;;
		--data-set) data_set="$2" ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# -lt 3 ]
	then
		syntax
	fi
	cluster_name=$1
	shift
	job_name=$1
	shift
	bench_list=$*
	cluster_section="Cluster.$cluster_name"
	job_section="Job.$cluster_name.$job_name"

	# Info
	echo -n "queuing job '$job_name' to cluster '$cluster_name'"

	# Check job ID
	job_id=`$inifile_py $inifile read $cluster_section NumJobs`
	if [ -z "$job_id" ]
	then
		error "cluster not started"
	fi

	# Check that job has unique name
	job_exists=`$inifile_py $inifile exists $job_section`
	if [ "$job_exists" == 1 ]
	then
		error "job with same name already exists"
	fi

	# Make a copy of extra files
	num_send_files=`$inifile_py $inifile read $cluster_section NumSendFiles`
	for send_file in $send_files
	do
		send_file_copy="$HOME/$M2S_CLIENT_KIT_TMP_PATH/sim-cluster-file-$num_send_files"
		num_send_files=`expr $num_send_files + 1`
		cp $send_file $send_file_copy 2>/dev/null \
			|| error "$send_file: file not found"
	done

	# Start job
	inifile_script=`mktemp`
	num_jobs=`expr $job_id + 1`
	echo "write $cluster_section NumSendFiles $num_send_files" >> $inifile_script
	echo "write $cluster_section NumJobs $num_jobs" >> $inifile_script
	echo "write $cluster_section Job[$job_id] $job_name" >> $inifile_script
	echo "write $job_section BenchmarkList \"$bench_list\"" >> $inifile_script
	echo "write $job_section DataSet $data_set" >> $inifile_script
	echo "write $job_section NumThreads $num_threads" >> $inifile_script
	echo "write $job_section SimulatorArguments \"$sim_args\"" >> $inifile_script
	echo "write $job_section BenchmarkArguments \"$bench_args\"" >> $inifile_script
	echo "write $job_section SendFiles \"$send_files\"" >> $inifile_script
	$inifile_py $inifile run $inifile_script \
		|| error "cannot queue job"
	rm -f $inifile_script
	echo -n " - job $job_id"

	# Done
	echo " - ok"

elif [ "$command" == "commit" ]
then

	# Options
	temp=`getopt -o r: \
		-n 'sim-cluster.sh' -- "$@"`
	if [ $? != 0 ] ; then exit 1 ; fi
	eval set -- "$temp"
	rev=
	while true
	do
		case "$1" in
		-r) rev=$2 ; shift $2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# != 2 ]
	then
		syntax
	fi
	cluster_name=$1
	server_port=$2
	cluster_section="Cluster.$cluster_name"

	# Split server and port
	server=`echo $server_port | awk -F: '{ print $1 }'`
	port=`echo $server_port | awk -F: '{ print $2 }'`
	if [ -z "$port" ]
	then
		port=22
	fi

	# Prepare Multi2Sim revision in server
	rev_arg=
	if [ -n "$rev" ]
	then
		rev_arg="-r $rev"
	fi
	$HOME/$M2S_CLIENT_KIT_BIN_PATH/gen-m2s-bin.sh \
		$rev_arg $server_port

	# Info
	echo -n "committing cluster '$cluster_name'"

	# Check if cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_section`
	if [ "$cluster_exists" == 0 ]
	then
		error "cluster does not exist"
	fi

	# Send configuration to server
	echo -n " - sending files"
	server_package="$HOME/$M2S_CLIENT_KIT_TMP_PATH/sim-cluster.tar.gz"
	cd $HOME/$M2S_CLIENT_KIT_TMP_PATH || error "cannot cd to temp path"
	file_list=`ls sim-cluster-file-* sim-cluster.ini 2>/dev/null`
	tar -czf $server_package $file_list || error "error creating package for server"
	scp -q -P $port $server_package $server:$M2S_SERVER_KIT_TMP_PATH \
		|| error "error sending package to server"
	rm -f $server_package

	# Actions in server
	ssh -p $port $server '

		function error()
		{
			echo -e "\nerror: $1\n" >&2
			exit 1
		}

		# Unpack server package
		server_package="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/sim-cluster.tar.gz"
		cd $HOME/'$M2S_SERVER_KIT_TMP_PATH' && \
			tar -xzf $server_package || exit 1
		rm -f $server_package

		# Initialize
		inifile_py="$HOME/'$M2S_SERVER_KIT_BIN_PATH'/inifile.py"
		inifile="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/sim-cluster.ini"
		cluster_name='$cluster_name'
		cluster_section='$cluster_section'

		# Read number of jobs and sent files
		inifile_script=`mktemp`
		temp=`mktemp`
		echo "read $cluster_section NumJobs" >> $inifile_script
		echo "read $cluster_section NumSendFiles" >> $inifile_script
		$inifile_py $inifile run $inifile_script > $temp
		for i in 1
		do
			read num_jobs
			read num_send_files
		done < $temp
		rm -f $inifile_script $temp

		# Read job list
		inifile_script=`mktemp`
		temp=`mktemp`
		job_list=
		for ((job_id=0; job_id<$num_jobs; job_id++))
		do
			echo "read $cluster_section Job[$job_id]" >> $inifile_script
		done
		$inifile_py $inifile run $inifile_script > $temp
		for ((job_id=0; job_id<$num_jobs; job_id++))
		do
			read job_name
			job_list="$job_list $job_name"
		done < $temp
		rm -f $inifile_script $temp

		# Create condor submit file
		condor_submit_path=`mktemp`

		# For each job
		send_file_id=0
		for job_name in $job_list
		do
			# Create directory
			job_path="$HOME/'$M2S_SERVER_KIT_RUN_PATH'/$cluster_name/$job_name"
			mkdir -p $job_path || exit 1

			# Copy Multi2Sim binary
			cp $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH'/m2s $job_path || exit 1

			# Read job configuration
			job_section="Job.$cluster_name.$job_name"
			inifile_script=`mktemp`
			temp=`mktemp`
			echo "read $job_section BenchmarkList" >> $inifile_script
			echo "read $job_section SendFiles" >> $inifile_script
			echo "read $job_section SimulatorArguments" >> $inifile_script
			echo "read $job_section BenchmarkArguments" >> $inifile_script
			echo "read $job_section DataSet" >> $inifile_script
			$inifile_py $inifile run $inifile_script > $temp
			for i in 1
			do
				read bench_list
				read send_files
				read sim_args
				read bench_args
				read data_set
			done < $temp
			rm -f $inifile_script $temp

			# Copy files
			for send_file in $send_files
			do
				source="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/sim-cluster-file-$send_file_id"
				dest="$job_path/`echo $send_file | awk -F/ "{ print \\$NF }"`"
				cp $source $dest || exit 1
				send_file_id=`expr $send_file_id + 1`
			done

			# Create context configuration file
			ctx_config_path="$job_path/ctx-config"
			cp /dev/null $ctx_config_path || exit 1

			# Copy benchmarks
			context_id=0
			for suite_bench in $bench_list
			do
				
				# Get benchmark
				tokens=`echo $suite_bench | awk -F/ "{ print NF }"`
				[ "$tokens" == 2 ] || error "$suite_bench: invalid format for suite/benchmark"
				suite_name=`echo $suite_bench | awk -F/ "{ print \\$1 }"`
				bench_name=`echo $suite_bench | awk -F/ "{ print \\$2 }"`
				suite_path="$HOME/'$M2S_SERVER_KIT_BENCH_PATH'/$suite_name"
				bench_path="$HOME/'$M2S_SERVER_KIT_BENCH_PATH'/$suite_name/$bench_name"
				[ -d $suite_path ] || error "$suite_name: invalid benchmark suite"
				[ -d $bench_path ] || error "$bench_name: invalid benchmark"

				# Check dataset
				bench_ini="$bench_path/benchmark.ini"
				[ -e $bench_ini ] || error "$bench_ini: file not found"
				data_set_exists=`$inifile_py $bench_ini exists $data_set`
				[ "$data_set_exists" == 1 ] || error "$data_set: invalid data set"

				# Read benchmark properties
				inifile_script=`mktemp`
				temp=`mktemp`
				echo "read $data_set Exe" >> $inifile_script
				echo "read $data_set Args" >> $inifile_script
				echo "read $data_set Stdin" >> $inifile_script
				echo "read $data_set Data" >> $inifile_script
				$inifile_py $bench_ini run $inifile_script > $temp
				for i in 1
				do
					read exe
					read args
					read stdin
					read data
				done < $temp
				rm -f $inifile_script $temp

				# If this is the first context, add arguments in "bench_args"
				if [ $context_id == 0 ]
				then
					args="$args $bench_args"
				fi

				# Create context_path
				context_path="$job_path/ctx-$context_id"
				mkdir -p $context_path || exit 1

				# Copy data and executable
				cp -r $bench_path/$data/* $context_path && \
					cp $bench_path/$exe $context_path \
					|| error "cannot copy benchmark"

				# Add entry to context configuration file
				echo "[ Context $context_id ]" >> $ctx_config_path
				echo "Cwd = $context_path" >> $ctx_config_path
				echo "Exe = $exe" >> $ctx_config_path
				echo "Args = $args" >> $ctx_config_path
				echo "StdIn = $stdin" >> $ctx_config_path
				echo >> $ctx_config_path

				# Next context
				context_id=`expr $context_id + 1`
			done

			# Queue job
			echo "Universe = vanilla" >> $condor_submit_path
			echo "Notification = Never" >> $condor_submit_path
			echo "Executable = $job_path/m2s" >> $condor_submit_path
			echo "Input = /dev/null" >> $condor_submit_path
			echo "Output = $job_path/sim.out" >> $condor_submit_path
			echo "Error = $job_path/sim.err" >> $condor_submit_path
			echo "InitialDir = $job_path" >> $condor_submit_path
			echo "Log = $job_path/sim.log" >> $condor_submit_path
			echo "Arguments = --ctx-config $ctx_config_path $sim_args" >> $condor_submit_path
			echo "Queue" >> $condor_submit_path
		done

		# Submit condor cluster
		echo ~~~~~~~~~~~~~~~~~
		cat $condor_submit_path
		echo ~~~~~~~~~~~~~~~~~
		condor_submit $condor_submit_path
		rm -f $condor_submit_path

	' || exit 1

	# Done
	echo " - ok"

elif [ "$command" == "clear" ]
then

	# Get arguments
	if [ $# != 1 ]
	then
		syntax
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Info
	echo -n "clearing cluster '$cluster_name'"

	# Check if cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_section`
	if [ "$cluster_exists" == 0 ]
	then
		error "cluster does not exist"
	fi

	# Clear all sending files
	rm -f $HOME/$M2S_CLIENT_KIT_TMP_PATH/sim-cluster-file-*

	# Get cluster jobs
	num_jobs=`$inifile_py $inifile read $cluster_section NumJobs`
	inifile_script=`mktemp`
	for ((job_id=0; job_id<$num_jobs; job_id++))
	do
		echo "read $cluster_section Job[$job_id]" >> $inifile_script
	done
	job_list=`$inifile_py $inifile run $inifile_script`
	rm -f $inifile_script

	# Delete all jobs
	inifile_script=`mktemp`
	for job_name in $job_list
	do
		job_section="Job.$cluster_name.$job_name"
		echo "remove $job_section" >> $inifile_script
	done
	$inifile_py $inifile run $inifile_script
	rm -f $inifile_script

	# Delete cluster
	$inifile_py $inifile remove $cluster_section
	echo " - ok"

else
	
	error "$command: invalid command"

fi

