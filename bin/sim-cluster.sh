#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"

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
	shift

	# Info
	echo -n "starting cluster '$cluster_name'"

	# Check if cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_name`
	if [ "$cluster_exists" == 1 ]
	then
		error "cluster already started, commit or clear first."
	fi

	# Start cluster
	$inifile_py $inifile write $cluster_name NumJobs 0
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

	# Info
	echo -n "queuing job '$job_name' to cluster '$cluster_name'"

	# Check job ID
	job_id=`$inifile_py $inifile read $cluster_name NumJobs`
	if [ -z "$job_id" ]
	then
		error "cluster not started"
	fi

	# Split suite/benchmark
	num_items=`echo $suite_bench_name | awk -F/ '{ print NF }'`
	if [ "$num_items" != 2 ]
	then
		error "invalid suite/benchmark argument"
	fi
	suite_name=`echo $suite_bench_name | awk -F/ '{ print $1 }'`
	bench_name=`echo $suite_bench_name | awk -F/ '{ print $2 }'`

	# Start job
	inifile_script=`mktemp`
	num_jobs=`expr $job_id + 1`
	echo "write $cluster_name NumJobs $num_jobs" >> $inifile_script
	echo "write $cluster_name Job[$job_id].Name $job_name" >> $inifile_script
	echo "write $cluster_name Job[$job_id].Suite $suite_name" >> $inifile_script
	echo "write $cluster_name Job[$job_id].Benchmark $bench_name" >> $inifile_script
	echo "write $cluster_name Job[$job_id].NumThreads $num_threads" >> $inifile_script
	echo "write $cluster_name Job[$job_id].SimulatorArguments \"$sim_args\"" >> $inifile_script
	echo "write $cluster_name Job[$job_id].BenchmarkArguments \"$bench_args\"" >> $inifile_script
	echo "write $cluster_name Job[$job_id].SendFiles \"$send_files\"" >> $inifile_script
	$inifile_py $inifile run $inifile_script \
		|| error "cannot queue job"
	rm -f $inifile_script
	echo -n " - job $job_id"

	# Done
	echo " - ok"

elif [ "$command" == "commit" ]
then

	echo "Commit"

elif [ "$command" == "clear" ]
then

	# Get arguments
	if [ $# != 1 ]
	then
		syntax
	fi
	cluster_name=$1

	# Info
	echo -n "clearing cluster '$cluster_name'"

	# Check if cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_name`
	if [ "$cluster_exists" == 0 ]
	then
		error "cluster does not exist"
	fi

	# Delete cluster
	$inifile_py $inifile remove $cluster_name
	echo " - ok"

else
	
	error "$command: invalid command"

fi

