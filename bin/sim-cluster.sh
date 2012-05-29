#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"

M2S_SERVER_KIT_PATH="m2s-server-kit"
M2S_SERVER_KIT_BIN_PATH="$M2S_SERVER_KIT_PATH/bin"
M2S_SERVER_KIT_RUN_PATH="$M2S_SERVER_KIT_PATH/run"
M2S_SERVER_KIT_TMP_PATH="$M2S_SERVER_KIT_PATH/tmp"

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
	temp=`getopt -o p: -l send:,sim-arg:,bench-arg: \
		-n 'sim-cluster.sh' -- "$@"`
	if [ $? != 0 ] ; then exit 1 ; fi
	eval set -- "$temp"
	send_files=
	sim_args=
	bench_args=
	num_threads=1
	while true
	do
		case "$1" in
		-p) num_threads=$2 ; shift $2 ;;
		--send) send_files="$send_files $2" ; shift 2 ;;
		--sim-arg) sim_args="$sim_args $2" ; shift 2 ;;
		--bench-arg) bench_args="$bench_args $2" ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# != 3 ]
	then
		syntax
	fi
	cluster_name=$1
	job_name=$2
	suite_bench_name=$3
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

	# Split suite/benchmark
	num_items=`echo $suite_bench_name | awk -F/ '{ print NF }'`
	if [ "$num_items" != 2 ]
	then
		error "invalid suite/benchmark argument"
	fi
	suite_name=`echo $suite_bench_name | awk -F/ '{ print $1 }'`
	bench_name=`echo $suite_bench_name | awk -F/ '{ print $2 }'`

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
	echo "write $job_section Suite $suite_name" >> $inifile_script
	echo "write $job_section Benchmark $bench_name" >> $inifile_script
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
	cd $HOME/$M2S_CLIENT_KIT_TMP_PATH && \
		tar -czf $server_package sim-cluster-file-* sim-cluster.ini \
		|| error "error creating package for server"
	scp -q -P $port $server_package $server:$M2S_SERVER_KIT_TMP_PATH \
		|| error "error sending package to server"
	rm -f $server_package

	# Actions in server
	ssh -p $port $server '

		# Unpack server package
		server_package="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/sim-cluster.tar.gz"
		tar -xvf $server_package || exit 1
		rm -f $HOME

	' || error "error in server"

	# Clear all sending files
	# rm -f $HOME/$M2S_CLIENT_KIT_TMP_PATH/sim-cluster-file-* #######

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

