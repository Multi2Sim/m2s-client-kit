#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"

M2S_SERVER_KIT_PATH="m2s-server-kit"
M2S_SERVER_KIT_BIN_PATH="$M2S_SERVER_KIT_PATH/bin"
M2S_SERVER_KIT_RUN_PATH="$M2S_SERVER_KIT_PATH/run"
M2S_SERVER_KIT_TMP_PATH="$M2S_SERVER_KIT_PATH/tmp"
M2S_SERVER_KIT_BENCH_PATH="$M2S_SERVER_KIT_PATH/benchmarks"
M2S_SERVER_KIT_M2S_BIN_PATH="$M2S_SERVER_KIT_TMP_PATH/m2s-bin"

m2s_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/m2s-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

inifile="$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-cluster.ini"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`


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
	cat << EOF

Syntax:
    $prog_name <command> <arguments> [<options>]

Run simulations on a server with condor and a shared file system, where the
Multi2Sim server kit is installed in the home folder of the same user. Possible
commands are:

  create <cluster>
      Create a new cluster (set of jobs). To run simulations, a cluster must be
      first started. Then new jobs are added to it, and finally it is submitted
      to the server.
      The folder in the server where the cluster will reside is

          SERVER:~/m2s-server-kit/run/<cluster_name>

  add <cluster> <job_name> <benchmarks> [<options>]
      Add a new job to the cluster, where <job_name> is the identifier of the
      new job. This identifier can contain '/' characters. The folder in the
      server where the job will reside is

          SERVER:~/m2s-server-kit/run/<cluster_name>/<job_name>
      
      Argument <benchmarks> is a list of applications to run as different
      contexts on the same simulation, passed as different sections of the
      context configuration file of Multi2Sim. Each benchmark should be given
      as <suite>/<benchmark>. For example 'splash2/fft'. Suites and benchmarks
      should be given as they appear in folder

          SERVER:~/m2s-server-kit/benchmarks

      The following optional arguments can be used for the 'add' command:

      -p <num_threads>
          Number of child threads for the benchmark to spawn, in case this value
	  is part of the benchmark command line (i.e., SPLASH-2 benchmarks).

      --send <file>
          Send an additional file to be included in the working directory of the
	  simulation execution. This option is useful to send configuration
	  files for Multi2Sim. To send multiple files, use double quotes (e.g.,
	  --send "mem-config gpu-config").

      --sim-args <args>
          Additional arguments for the simulator. This is useful to make it
	  consume the configuration files sent with option '--send'. Use double
	  quotes for more than one argument (e.g.,
	  --sim-args "--mem-config my-mem-config-file").
	  When using this option to add output report files, it is recommended
	  to use files with the '-report' suffix (e.g.,
	  --sim-args "--x86-report my-x86-report"). Files with
	  this suffix in the simulation working directory will be automatically
	  imported with command 'import'.

      --bench-args <args>
          Additional arguments for the benchmark. A benchmark has a specific set
	  of arguments given by the data set specified. These arguments will be
	  added to the benchmark command line (e.g., --bench-args "-x 16 -y 16").

      --data-set <set>
          For those benchmarks providing several data sets, this argument
	  specifies the name. It is set to 'Default' if no value is given.

  submit <cluster> [<user>@]<server> [<options>]
      Submit the cluster to the server and start its execution using condor. A
      cluster must be in state 'Created', 'Completed', or 'Killed' for it to be
      (re-)submitted. The cluster will transition to state 'Submitted'.

      -r <revision>
          Multi2Sim SVN revision to use for the cluster execution. If this
	  option is omitted, the latest SVN update will be fetched automatically
	  from the Multi2Sim server.

      --tag <tag>
          If this option is omitted, the development trunk is used. If the
	  option is specified, subdirectory <tag> in the 'tags' directory of the
	  Multi2Sim repository is used, representing a stable Multi2Sim release.

      --configure-args <args>
          Arguments to be passed to the './configure' script when building the
	  Multi2Sim distribution package used for simulation. The arguments
	  should be listed within double quotes. For simulations aiming
	  simulator verification, it is recommend to always used at least:
	      --configure-args "--enable-debug"

      --exe <file>
          Multi2Sim executable file to be used for simulations. This option
	  overrides the default behavior of fetching a Multi2Sim version for the
	  SVN repository. Instead, it allows the user to specify a custom
	  version of the simulator. Options '-r', '--tag', and
	  '--configure-args' are ignored if option '--exe' is used.
	  The user should make sure that the executable can run correctly on the
	  server environment. Preferably, the executable should be created
	  through a compilation on the server.

      --exe-dir <dir>
          Directory in the local machine containing the Multi2Sim source code to
	  be used for simulations, instead of a version of the official SVN
	  repository. Before launching the cluster, this code is sent to the
	  server and compiled.
	  A copy of the binary created in the server is also imported and cached
	  in the client machine. To avoid the remote compilation overhead, a
	  future cluster can reuse this binary by means of option '--exe'
	  instead.

  state <cluster> [-v]
      Return the current state of a cluster. Additional information about the
      cluster will be printed if optional flag '-v' is specified. The following
      states are possible:

      Invalid
          The cluster does not exist.

      Created
          The cluster has been created, but not submitted to the server yet.

      Submitted
          The cluster has been submitted to the server. This state is reported
	  with further information from the server.

      Completed
          All jobs associated with the cluster have completed execution in the
	  server.

      Killed
          The cluster has been killed before completing execution.

  wait <cluster1> [<cluster2> [...]]
      Wait for a list of clusters to finish execution. The command finishes once
      all clusters are in state 'Created', 'Completed', 'Killed', or 'Invalid'.
      The server is queried periodically to update the state of all clusters.

  kill <cluster>
      Kill all jobs associated with the cluster in the server. The cluster must
      be in state 'Submitted' for this operation to be valid. After this
      operation, the cluster transitions to state 'Killed'.
      
  import <cluster> [-a]
      Copy simulation output and report files into a similar directory hierarchy
      from the server into the client. The source and destination paths are,
      respectively:

          SERVER:~/m2s-server-kit/run/<cluster_name>
          CLIENT:~/m2s-client-kit/result/<cluster_name>

      This command is useful for post-processing of statistics generated in the
      server, without the burden of importing unnecessary simulation files, such
      as simulator executable, benchmark binaries, or data files. The imported
      files are, as found in any subdirectory of the running path:
          sim.out    Benchmark output
	  sim.ref    Benchmark reference output
	  sim.err    Simulator output
	  *-report   Any report file with the '-report' suffix.
	  *-config   Any configuration file with the '-config' suffix.
      If optional flag '-a' is specified, all files in the running directory
      will be imported, including benchmark executable and data files.
      The cluster must be in state 'Submitted', 'Completed', or 'Killed' for
      this command to be valid.

  remove <cluster>
      Remove all information about the cluster and its jobs. The entire directory
      hierarchy associated with the cluster both in the server and client will
      be deleted at the following locations:

          SERVER:~/m2s-server-kit/run/<cluster_name>
          CLIENT:~/m2s-server-kit/result/<cluster_name>

      A cluster must be in state 'Created', 'Completed', or 'Killed' for this
      command to be valid. Querying the state of a cluster after it has been
      removed will return state 'Invalid'.

  list [<cluster>]
      If no value for <cluster> is provided, list all existing clusters. If a
      value is given, list all jobs added to <cluster>. A summary of the listed
      clusters is provided in the standard error output.

  list-bench [<user>@]<server> [<suite>]
      If no optional argument is given, this command lists the benchmark suites
      available in the server. If a benchmark suite is given, the command lists
      the benchmarks available in the server belonging to that suite.

  server <cluster>
      Print the server where a cluster is or has been running. The syntax of the
      output string is [<user>@]<server>[:<port>], where the port is only
      specified if other than 22. The cluster must be in state 'Submitted',
      'Completed', or 'Killed'.

EOF
	exit 1
}



# Create a temporary INI file with a list of all Condor jobs present in the
# server, associated with a cluster name.
# The name of the temporary file is dumped in stdout.
# Each section of the INI file is as follows:
#
#	[ 17.0 ]
#	Cmd = /home/ubal/m2s-server-kit/run/my-cluster/m2s
#	Args = --ctx-config /home/ubal/m2s-server-kit/run/my-cluster/my-job-0/ctx-config
#	--gpu-sim detailed
#	ClusterID = 17
#	ProcID = 0
#	Owner = ubal
#	JobStatus = 2
#
# Values for JobStatus are
#	0	Unexpanded
#	1 	Idle
#	2 	Running
#	3 	Removed
#	4 	Completed
#	5 	Held
# Syntax: get_condor_jobs <cluster> <server> <port>
function get_condor_jobs()
{
	local temp
	local job_list
	local job

	local cmd

	# Arguments
	local cluster_name=$1 ; shift
	local server=$1 ; shift
	local port=$1 ; shift

	# Connect to server
	temp=`mktemp`
	ssh $server -p $port '
		condor_q -format "[ %d." ClusterID \
			-format "%d ]\n" ProcID \
			-format "Cmd = %s\n" Cmd \
			-format "Args = %s\n" Args \
			-format "ClusterID = %d\n" ClusterID \
			-format "ProcID = %d\n" ProcID \
			-format "Owner = %s\n" Owner \
			-format "JobStatus = %d\n\n" JobStatus \
			|| exit 1
	' > $temp || error "cannot query state in server"

	# Filter all jobs that don't belong to cluster.
	# Do this by checking the full path of the command (m2s)
	job_list=`$inifile_py $temp list`
	for job in $job_list
	do
		cmd=`$inifile_py $temp read $job Cmd`
		owner=`$inifile_py $temp read $job Owner`
		[[ "$cmd" =~ "/m2s-server-kit/run/$cluster_name/" \
			&& "$owner" == "$USER" ]] \
			|| $inifile_py $temp remove $job
	done

	# Dump name of INI file created
	echo $temp
}


# Build Multi2Sim remotely
function remote_make()
{
	local server_port=$1
	local exe_dir=$2
	local exe_file=$3

	# Split server and port
	local server=`echo $server_port | awk -F: '{ print $1 }'`
	local port=`echo $server_port | awk -F: '{ print $2 }'`
	if [ -z "$port" ]
	then
		port=22
	fi

	# Check input arguments
	[ -d "$exe_dir" ] || error "$exe_dir: invalid directory"
	[ -f "$exe_dir/configure" ] || error "$exe_dir: script 'configure' not found"
	[ -f "$exe_dir/Makefile" ] || error "$exe_dir: file 'Makefile' not found - please compile local copy first"
	[ -f "$exe_dir/src/m2s.c" ] || error "$exe_dir: file 'src/m2s.c' not found"
	touch "$exe_file" 2>/dev/null || error "$exe_file: invalid destination file"

	# Save working directory
	local current_dir=`pwd`

	# Create package
	cd $exe_dir 2>/dev/null || error "$exe_dir: cannot access directory"
	local log_file=`mktemp`
	make dist >> $log_file 2>&1
	if [ $? != 0 ]
	then
		echo " - local 'make dist' failed"
		cat $log_file
		rm $log_file
		exit 1
	fi
	rm $log_file
	local tarball=`ls "$exe_dir"/*.tar.gz`
	local tarball_count=`echo $tarball | wc -w`
	[ $tarball_count == 1 ] || error "$exe_dir: more than one tarball found - confused"
	local tarball_file_name=`echo $tarball | awk -F/ '{ print $NF }'`
	local tarball_dir_name="${tarball_file_name::-7}"

	# Send to server
	scp -q -P $port $tarball $server:$M2S_SERVER_KIT_TMP_PATH \
		|| error "cannot connect to server"

	# Compile in server
	ssh -p $port $server '

		# Variables
		tarball_file_name='$tarball_file_name'
		tarball_dir_name='$tarball_dir_name'

		# Unpack tarball
		cd '$M2S_SERVER_KIT_TMP_PATH' || exit 1
		rm -rf remote-make || exit 1
		mkdir -p remote-make || exit 1
		mv $tarball_file_name remote-make/ || exit 1
		cd remote-make || exit 1
		tar -xmzf $tarball_file_name || exit 1
		cd $tarball_dir_name || exit 1

		# Temporary file for report
		report=`mktemp`

		# Configure and make
		./configure >> $report 2>&1 && \
			make >> $report 2>&1
		if [ $? != 0 ]
		then
			echo " - FAILED"
			cat $report
			rm -f report
			exit 1
		fi

		# Delete report
		rm -f $report
	' || exit 1

	# Copy executable
	scp -q -P $port $server:$M2S_SERVER_KIT_TMP_PATH/remote-make/$tarball_dir_name/bin/m2s \
		$exe_file || exit 1
	echo -n " [ cached in '$exe_file' ]"

	# Go back to working directory
	cd $current_dir
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

# Commands
if [ "$command" == "create" ]
then

	# Get cluster name
	if [ $# != 1 ]
	then
		echo >&2 "syntax: create <cluster>"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Info
	echo -n "creating cluster '$cluster_name'"

	# Check valid cluster name
	num_fields=`echo $cluster_name | awk -F/ '{ print NF }'`
	[ "$num_fields" == 1 ] || error "cluster name cannot contain '/'"

	# Check if cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_section`
	if [ "$cluster_exists" == 1 ]
	then
		error "cluster already exists."
	fi

	# Clear all sending files
	rm -f $HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-cluster-file-*

	# Start cluster
	inifile_script=$(mktemp)
	echo "write $cluster_section NumJobs 0" >> $inifile_script
	echo "write $cluster_section NumSendFiles 0" >> $inifile_script
	echo "write $cluster_section State Created" >> $inifile_script
	$inifile_py $inifile run $inifile_script
	rm -f $inifile_script
	echo " - ok"

elif [ "$command" == "add" ]
then
	
	# Options
	temp=`getopt -o p: -l send:,sim-args:,bench-args:,data-set: \
		-n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	send_files=
	sim_args=
	bench_args=
	num_threads=1
	data_set="Default"
	while true
	do
		case "$1" in
		-p) num_threads=$2 ; shift 2 ;;
		--send) send_files="$send_files $2" ; shift 2 ;;
		--sim-args) sim_args="$sim_args $2" ; shift 2 ;;
		--bench-args) bench_args="$bench_args $2" ; shift 2 ;;
		--data-set) data_set="$2" ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# -lt 2 ]
	then
		echo -n >&2 "syntax: add <cluster_name> <job_name>"
		echo >&2 " [<benchmarks>] [<options>]"
		exit 1
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
		error "cluster does not exist"
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
		send_file_copy="$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-cluster-file-$num_send_files"
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

elif [ "$command" == "submit" ]
then

	# Options
	temp=`getopt -o r: -l configure-args:,tag:,exe:,exe-dir: -n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	rev=
	tag=
	configure_args=
	exe=
	exe_dir=
	while true
	do
		case "$1" in
		-r) rev=$2 ; shift 2 ;;
		--tag) tag=$2 ; shift 2 ;;
		--configure-args) configure_args=$2 ; shift 2 ;;
		--exe) exe=$2 ; shift 2 ;;
		--exe-dir) exe_dir=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# != 2 ]
	then
		echo >&2 "syntax: submit <cluster> <server> [<options>]"
		exit 1
	fi
	cluster_name=$1
	server_port=$2
	cluster_section="Cluster.$cluster_name"

	# Check compatibility of option "--exe"
	if [ -n "$exe" ]
	then
		[ -z "$rev" ] || error "option --exe incompatible with --rev"
		[ -z "$tag" ] || error "option --exe incompatible with --tag"
		[ -z "$exe_dir" ] || error "option --exe incompatible with --exe-dir"
	fi

	# Check compatibility of option "--exe-dir"
	if [ -n "$exe_dir" ]
	then
		[ -z "$rev" ] || error "option --exe-dir incompatible with --rev"
		[ -z "$tag" ] || error "option --exe-dir incompatible with --tag"
		[ -z "$exe" ] || error "option --exe-dir incompatible with --exe"
	fi

	# Split server and port
	server=`echo $server_port | awk -F: '{ print $1 }'`
	port=`echo $server_port | awk -F: '{ print $2 }'`
	if [ -z "$port" ]
	then
		port=22
	fi

	# Read cluster properties
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists $cluster_section" >> $inifile_script
	echo "read $cluster_section State" >> $inifile_script
	echo "read $cluster_section NumJobs" >> $inifile_script
	$inifile_py $inifile run $inifile_script > $temp
	for i in 1
	do
		read cluster_exists
		read cluster_state
		read num_jobs
	done < $temp
	rm -f $inifile_script $temp

	# Check cluster state
	[ "$cluster_exists" == 1 ] || error "cluster does not exist"
	[ "$cluster_state" != "Submitted" ] \
		|| error "cluster must be in state 'Created', 'Completed', or 'Killed'"

	# Prepare Multi2Sim revision in server. Only if options --exe or
	# --exe-dir were not specified.
	if [ -z "$exe" -a -z "$exe_dir" ]
	then
		rev_arg=
		tag_arg=
		[ -z "$rev" ] || rev_arg="-r $rev"
		[ -z "$tag" ] || tag_arg="--tag $tag"
		$HOME/$M2S_CLIENT_KIT_BIN_PATH/build-m2s-remote.sh \
			$rev_arg $tag_arg --configure-args "$configure_args" $server_port \
			|| exit 1
	fi

	# Info
	echo -n "submitting cluster '$cluster_name'"

	# Check if 'm2s-client-kit' is up to date
	cd $HOME/$M2S_CLIENT_KIT_PATH || error "cannot cd to client kit path"
	temp=$(mktemp)
	svn info > $temp || error "failed running 'svn info'"
	rev_current=$(sed -n "s,^Revision: ,,gp" $temp)
	svn info -r HEAD > $temp || error "failed running 'svn info'"
	rev_latest=$(sed -n "s,^Revision: ,,gp" $temp)
	rm -f $temp
	[ "$rev_current" == "$rev_latest" ] || \
		echo -n " - [WARNING: m2s-client-kit out of date]"

	# If an executable file was specified with option '--exe', make a copy
	# of it in the temporary directory, named 'm2s-exe'.
	if [ -n "$exe" ]
	then
		[ -f "$exe" ] || error "$exe: invalid executable"
		cp $exe $HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-exe || \
			error "cannot copy executable to temp path"
	fi

	# If option --exe-dir was specified, build Multi2Sim remotely.
	if [ -n "$exe_dir" ]
	then
		[ -d "$exe_dir" ] || error "$exe_dir: invalid directory"
		echo -n " - building"
		remote_make $server_port $exe_dir \
			$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-remote-exe
		cp $HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-remote-exe \
			$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-exe || \
			error "cannot copy executable to temp path"
	fi

	# Send configuration to server
	echo -n " - sending files"
	server_package="$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-cluster.tar.gz"
	cd $HOME/$M2S_CLIENT_KIT_TMP_PATH || error "cannot cd to temp path"
	file_list=`ls m2s-cluster-file-* m2s-cluster.ini m2s-exe 2>/dev/null`
	tar -czf $server_package $file_list || error "error creating package for server"
	scp -q -P $port $server_package $server:$M2S_SERVER_KIT_TMP_PATH \
		|| error "error sending package to server"
	rm -f $server_package

	# Actions in server
	echo -n " - preparing benchmarks"
	ssh -p $port $server '

		function error()
		{
			echo -e "\nerror: $1\n" >&2
			exit 1
		}

		# Check if m2s-server-kit is up to date
		cd $HOME/'$M2S_SERVER_KIT_PATH' || exit 1
		temp=$(mktemp)
		svn info > $temp || error "failed running \"svn info\""
		rev_current=$(sed -n "s,^Revision: ,,gp" $temp)
		svn info -r HEAD > $temp || error "failed running \"svn info\""
		rev_latest=$(sed -n "s,^Revision: ,,gp" $temp)
		rm -f $temp
		[ "$rev_current" == "$rev_latest" ] || \
			echo -n " - [WARNING: m2s-sever-kit out of date]"

		# Unpack server package
		server_package="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/m2s-cluster.tar.gz"
		cd $HOME/'$M2S_SERVER_KIT_TMP_PATH' && \
			tar -xzmf $server_package > /dev/null 2>&1 || exit 1
		rm -f $server_package

		# Initialize
		inifile_py="$HOME/'$M2S_SERVER_KIT_BIN_PATH'/inifile.py"
		inifile="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/m2s-cluster.ini"
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

		# Copy Multi2Sim binary
		# If the binary has been created automatically from the SVN
		# repository, get it from "tmp/m2s-bin/m2s". Otherwise, the user
		# specified option --exe or --exe-dir in the command line, and the
		# executable should be found in "tmp/m2s-exe".
		cluster_path="$HOME/'$M2S_SERVER_KIT_RUN_PATH'/$cluster_name"
		mkdir -p $cluster_path || exit 1
		exe="'$exe'"
		exe_dir="'$exe_dir'"
		if [ -z "$exe" -a -z "$exe_dir" ]
		then
			cp $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH'/m2s \
				$cluster_path || exit 1
		else
			cp $HOME/'$M2S_SERVER_KIT_TMP_PATH'/m2s-exe \
				$cluster_path/m2s || exit 1
		fi

		# Create condor submit file
		condor_submit_path=`mktemp`
		echo "Universe = vanilla" >> $condor_submit_path
		echo "Notification = Never" >> $condor_submit_path
		echo "Executable = $cluster_path/m2s" >> $condor_submit_path

		# Keep track of benchmark suites used in cluster
		suite_list=""

		# For each job
		send_file_id=0
		for job_name in $job_list
		do
			# Create directory
			job_path="$HOME/'$M2S_SERVER_KIT_RUN_PATH'/$cluster_name/$job_name"
			mkdir -p $job_path || exit 1

			# Read job configuration
			job_section="Job.$cluster_name.$job_name"
			inifile_script=`mktemp`
			temp=`mktemp`
			echo "read $job_section BenchmarkList" >> $inifile_script
			echo "read $job_section SendFiles" >> $inifile_script
			echo "read $job_section SimulatorArguments" >> $inifile_script
			echo "read $job_section BenchmarkArguments" >> $inifile_script
			echo "read $job_section DataSet" >> $inifile_script
			echo "read $job_section NumThreads" >> $inifile_script
			$inifile_py $inifile run $inifile_script > $temp
			for i in 1
			do
				read bench_list
				read send_files
				read sim_args
				read bench_args
				read data_set
				read num_threads
			done < $temp
			rm -f $inifile_script $temp

			# Copy files
			for send_file in $send_files
			do
				source="$HOME/'$M2S_SERVER_KIT_TMP_PATH'/m2s-cluster-file-$send_file_id"
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
				suite_path="$HOME/m2s-bench-${suite_name}"
				bench_path="$suite_path/$bench_name"
				[ -d $suite_path ] || error "$suite_name: invalid benchmark suite"
				[ -d $bench_path ] || error "$bench_name: invalid benchmark"

				# Keep a list of benchmark suites used in the cluster, to check
				# later whether they are at their latest versions.
				echo $suite_list | grep -q "\<$suite_name\>"
				[ $? == 0 ] || suite_list="$suite_list $suite_name"

				# Check dataset
				bench_ini="$bench_path/benchmark.ini"
				[ -e $bench_ini ] || error "$bench_ini: file not found"
				data_set_exists=`$inifile_py $bench_ini exists $data_set`
				[ "$data_set_exists" == 1 ] || \
					error "$suite_bench: $data_set: invalid data set"

				# Parse benchmark.ini file, replacing NTHREADS variable
				bench_ini_parsed=`mktemp`
				sed "s/\$NTHREADS\>/$num_threads/g" $bench_ini > $bench_ini_parsed

				# Read benchmark properties
				inifile_script=`mktemp`
				temp=`mktemp`
				echo "read $data_set Exe" >> $inifile_script
				echo "read $data_set Args" >> $inifile_script
				echo "read $data_set Stdin" >> $inifile_script
				echo "read $data_set Data" >> $inifile_script
				$inifile_py $bench_ini_parsed run $inifile_script > $temp
				for i in 1
				do
					read exe
					read args
					read stdin
					read data
				done < $temp
				rm -f $inifile_script $temp
				rm -f $bench_ini_parsed

				# If this is the first context, add arguments in "bench_args"
				if [ $context_id == 0 ]
				then
					args="$args $bench_args"
				fi

				# Create context_path
				context_path="$job_path/ctx-$context_id"
				mkdir -p $context_path || error "cannot create context directory"

				# Copy files in the benchmark directory, non-recursively
				# Option "-C" in "rsync" automatically discards ".svn" directories.
				# Option "-a" is equal to "-rlptgoD", so the "-r" is omitted.
				rsync -lptgoDC $bench_path/* $context_path/ \
					> /dev/null || error "cannot copy benchmark"

				# Copy files in the data directory associated with the specified
				# data set. This is done recursively
				if [ -n "$data" -a -d "$bench_path/$data" ]
				then
					rsync -aC $bench_path/$data/ $context_path/ \
						|| error "cannot copy benchmark data"
				fi
					
				# Add entry to context configuration file
				echo "[ Context $context_id ]" >> $ctx_config_path
				echo "Cwd = $context_path" >> $ctx_config_path
				echo "Exe = $exe" >> $ctx_config_path
				echo "Args = $args" >> $ctx_config_path
				echo "StdIn = $stdin" >> $ctx_config_path
				echo "StdOut = sim.out" >> $ctx_config_path
				echo >> $ctx_config_path

				# Next context
				context_id=`expr $context_id + 1`
			done

			# Queue job
			echo "Input = /dev/null" >> $condor_submit_path
			echo "Output = $job_path/sim.out" >> $condor_submit_path
			echo "Error = $job_path/sim.err" >> $condor_submit_path
			echo "InitialDir = $job_path" >> $condor_submit_path
			echo "Log = $job_path/sim.log" >> $condor_submit_path
			echo "Arguments = --ctx-config $ctx_config_path $sim_args" >> $condor_submit_path
			echo "Requirements = Memory > 100" >> $condor_submit_path
			echo "Rank = -LoadAvg" >> $condor_submit_path
			echo "+GPBatchJob = True" >> $condor_submit_path
			echo "+LongRunningJob = True" >> $condor_submit_path
			echo "Queue" >> $condor_submit_path
		done

		# Now that the list of benchmark suites used in the cluster is
		# complete, check that each of them is up to date
		for suite_name in $suite_list
		do
			cd $HOME/m2s-bench-$suite_name || exit 1
			# temp=$(mktemp)
			# svn info > $temp || error "failed running \"svn info\""
			# rev_current=$(sed -n "s,^Revision: ,,gp" $temp)
			# svn info -r HEAD > $temp || error "failed running \"svn info\""
			# rev_latest=$(sed -n "s,^Revision: ,,gp" $temp)
			# rm -f $temp
			# [ "$rev_current" == "$rev_latest" ] || \
			#	echo -n " - [WARNING: m2s-bench-$suite_name out of date]"
		done

		# Submit condor cluster
		echo -n " - launching condor"
		condor_submit_log=`mktemp`
		condor_submit -verbose $condor_submit_path > $condor_submit_log \
			|| error "error submitting jobs with condor"
		rm -f $condor_submit_path

		# Get condor job IDs
		# Filter lines like "** Proc 11.0:" from submission output.
		condor_job_ids=`sed -n "s/^\*\* Proc \(.*\):$/\1/gp" $condor_submit_log`
		num_condor_job_ids=`echo $condor_job_ids | wc -w`
		[ $num_condor_job_ids == $num_jobs ] || \
			error "unexpected condor_submit output format"
		rm -f $condor_submit_log

		# Get condor cluster ID
		# Get the first number on the left of the "." from job IDs
		condor_cluster_id=`echo $condor_job_ids | awk -F. "{ print \\$1 }"`
		echo -n " - condor id $condor_cluster_id"
	
	' || exit 1

	# Change cluster state
	inifile_script=`mktemp`
	echo "write $cluster_section State Submitted" >> $inifile_script
	echo "write $cluster_section Server $server" >> $inifile_script
	echo "write $cluster_section Port $port" >> $inifile_script
	$inifile_py $inifile run $inifile_script
	rm -f $inifile_script

	# Done
	echo " - $num_jobs jobs submitted - ok"
	
elif [ "$command" == "remove" ]
then

	# Get arguments
	if [ $# != 1 ]
	then
		echo >&2 "syntax: remove <cluster>"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Info
	echo -n "removing cluster '$cluster_name'"

	# Read cluster properties
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists $cluster_section" >> $inifile_script
	echo "read $cluster_section State" >> $inifile_script
	echo "read $cluster_section NumJobs" >> $inifile_script
	echo "read $cluster_section Server" >> $inifile_script
	echo "read $cluster_section Port" >> $inifile_script
	$inifile_py $inifile run $inifile_script > $temp
	for i in 1
	do
		read cluster_exists
		read cluster_state
		read num_jobs
		read server
		read port
	done < $temp
	rm -f $inifile_script $temp

	# Check cluster state
	# If it shows up as 'Submitted', refresh it in case simulations finished
	[ "$cluster_exists" == 1 ] || error "cluster does not exist"
	[ "$cluster_state" != "Submitted" ] || \
		cluster_state=`$m2s_cluster_sh state $cluster_name`
	[ "$cluster_state" != "Submitted" ] \
		|| error "cluster must be in state 'Created', 'Completed', or 'Killed'"

	# Remove all sending files
	rm -f $HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-cluster-file-*

	# Get cluster jobs
	num_jobs=`$inifile_py $inifile read $cluster_section NumJobs`
	inifile_script=`mktemp`
	for ((job_id=0; job_id<$num_jobs; job_id++))
	do
		echo "read $cluster_section Job[$job_id]" >> $inifile_script
	done
	job_list=`$inifile_py $inifile run $inifile_script`
	rm -f $inifile_script

	# Delete cluster and job sections
	inifile_script=`mktemp`
	echo "remove $cluster_section" >> $inifile_script
	for job_name in $job_list
	do
		job_section="Job.$cluster_name.$job_name"
		echo "remove $job_section" >> $inifile_script
	done
	$inifile_py $inifile run $inifile_script
	rm -f $inifile_script

	# If cluster has ever been submitted, delete the directory where it ran
	# in the server. This clears a lot of space used for benchmark copies.
	# Also delete the report package that might have been created when
	# importing the cluster output data.
	if [ -n "$server" ]
	then
		echo -n " - removing cluster in server"
		ssh $server -p $port '
			rm -f $HOME/'$M2S_SERVER_KIT_TMP_PATH/$cluster_name'-report.tar.gz
			rm -rf $HOME/'$M2S_SERVER_KIT_RUN_PATH/$cluster_name'
		' || error "failed deleting directories in server"
	fi

	# If cluster has been imported, delete the directory
	rm -rf $HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name

	# Done
	echo " - ok"

elif [ "$command" == "state" ]
then
	
	# Options
	temp=`getopt -o v -n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	verbose=0
	while true
	do
		case "$1" in
		-v) verbose=1 ; shift 1 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# != 1 ]
	then
		echo >&2 "syntax: state <cluster>"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Read cluster properties
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists $cluster_section" >> $inifile_script
	echo "read $cluster_section State" >> $inifile_script
	echo "read $cluster_section Server" >> $inifile_script
	echo "read $cluster_section Port" >> $inifile_script
	$inifile_py $inifile run $inifile_script > $temp
	for i in 1
	do
		read section_exists
		read state
		read server
		read port
	done < $temp
	rm -f $inifile_script $temp

	# Cluster does not exist
	if [ "$section_exists" == 0 ]
	then
		echo "Invalid"
		exit
	fi

	# Submitted
	if [ "$state" == "Submitted" ]
	then
		# Get INI file with condor info
		temp=`get_condor_jobs $cluster_name $server $port`
		[ -n "$temp" ] || exit 1

		# If no more jobs left, change state to Completed
		job_list=`$inifile_py $temp list`
		if [ -z "$job_list" ]
		then
			$inifile_py $inifile write $cluster_section State Completed
			echo "Completed"
			exit
		fi

		# Print state and quit if no verbose
		echo "Submitted"
		if [ "$verbose" == 0 ]
		then
			rm -f $temp
			exit
		fi

		# Get list of job states
		inifile_script=`mktemp`
		for job in $job_list
		do
			echo "read $job JobStatus" >> $inifile_script
		done
		job_state_list=`$inifile_py $temp run $inifile_script`
		rm -f $inifile_script

		# Count running and idle jobs
		job_running_count=0
		job_idle_count=0
		for job_state in $job_state_list
		do
			if [ "$job_state" == 2 ]
			then
				job_running_count=`expr $job_running_count + 1`
			else
				job_idle_count=`expr $job_idle_count + 1`
			fi
		done

		# Info
		echo "cluster running on server '$server'"
		echo "$job_running_count job(s) running, $job_idle_count job(s) idle."
		rm -f $temp
		exit
	fi

	# Other state
	echo $state

elif [ "$command" == "kill" ]
then
	# Get arguments
	if [ $# != 1 ]
	then
		echo >&2 "syntax: kill <cluster>"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Read cluster properties
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists $cluster_section" >> $inifile_script
	echo "read $cluster_section State" >> $inifile_script
	echo "read $cluster_section Server" >> $inifile_script
	echo "read $cluster_section Port" >> $inifile_script
	$inifile_py $inifile run $inifile_script > $temp
	for i in 1
	do
		read section_exists
		read state
		read server
		read port
	done < $temp
	rm -f $inifile_script $temp

	# Check valid state of cluster
	echo -n "killing cluster"
	[ "$section_exists" == 1 ] || error "cluster does not exist"
	[ "$state" == "Submitted" ] || error "cluster must be in state 'Submitted'"

	# Get list of condor jobs
	echo -n " - get job list"
	temp=`get_condor_jobs $cluster_name $server $port`
	job_list=`$inifile_py $temp list`
	num_jobs=`echo $job_list | wc -w`
	rm -f $temp
	if [ -z "$job_list" ]
	then
		echo " - no job to kill"
		exit
	fi

	# Kill jobs
	ssh $server -p $port '
		condor_rm '$job_list' > /dev/null
	' || error "failed to kill condor jobs"

	# Update cluster state
	$inifile_py $inifile write $cluster_section State Killed

	# Done
	echo " - $num_jobs jobs killed - ok"

elif [ "$command" == "import" ]
then
	
	# Options
	temp=`getopt -o a -n $prog_name -- "$@"`
	[ $? == 0 ] || exit 1
	eval set -- "$temp"
	import_all=0
	while true
	do
		case "$1" in
		-a) import_all=1 ; shift 1 ;;
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done

	# Get arguments
	if [ $# != 1 ]
	then
		echo >&2 "syntax: import <cluster> [-a]"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Read cluster properties
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists $cluster_section" >> $inifile_script
	echo "read $cluster_section State" >> $inifile_script
	echo "read $cluster_section Server" >> $inifile_script
	echo "read $cluster_section Port" >> $inifile_script
	$inifile_py $inifile run $inifile_script > $temp
	for i in 1
	do
		read section_exists
		read state
		read server
		read port
	done < $temp
	rm -f $inifile_script $temp

	# Check valid state of cluster
	echo -n "importing cluster output"
	[ "$section_exists" == 1 ] || error "cluster does not exist"
	[ "$state" != "Created" ] || error "cluster must be in state 'Submitted', 'Completed', or 'Killed'"

	# Connect to server and create package
	echo -n " - create package"
	ssh $server -p $port '
		import_all="'"$import_all"'"
		package=$HOME/'$M2S_SERVER_KIT_TMP_PATH/$cluster_name'-report.tar.gz
		cd $HOME/'$M2S_SERVER_KIT_RUN_PATH/$cluster_name' || exit 1
		if [ "$import_all" == 0 ]
		then
			tar -czf $package `find -regex \
				"\(.*/sim.err$\)\|\(.*/report-[^/]*$\)\|\(.*/sim.out$\)\|\(.*/sim.ref\)\|\(.*-config$\)\|\(.*-report$\)"` \
				> /dev/null 2>&1 || exit 1
		else
			tar -czf $package `find -not -regex "\(.*\/\..*\)"` \
				> /dev/null 2>&1 || exit 1
		fi
	' || error "could not create package in server"

	# Create directory locally
	rm -rf $HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name
	mkdir $HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name \
		> /dev/null 2>&1 || error "cannot create local copy"
	cd $HOME/$M2S_CLIENT_KIT_RESULT_PATH/$cluster_name || exit 1

	# Import the package
	echo -n " - import"
	scp -P $port -q $server:$M2S_SERVER_KIT_TMP_PATH/${cluster_name}-report.tar.gz . \
		>/dev/null 2>&1 || error "could not import package"

	# Unpack in client
	tar -xzmvf ${cluster_name}-report.tar.gz \
		>/dev/null 2>&1 || error "could not unpack"
	rm -f ${cluster_name}-report.tar.gz

	# Done
	echo " - ok"

elif [ "$command" == "list" ]
then
	# Get arguments
	if [ $# -gt 1 ]
	then
		echo >&2 "syntax: list [<cluster>]"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# List clusters
	if [ -z "$cluster_name" ]
	then
		section_list=`$inifile_py $inifile list`
		num_clusters=0
		for section in $section_list
		do
			if [[ $section =~ ^Cluster\. ]]
			then
				echo ${section:8}
				num_clusters=`expr $num_clusters + 1`
			fi
		done
		echo >&2 "$num_clusters cluster(s) created"
		exit
	fi

	# Check that cluster exists
	cluster_exists=`$inifile_py $inifile exists $cluster_section`
	[ "$cluster_exists" == 1 ] || error "cluster does not exist"

	# List jobs
	section_list=`$inifile_py $inifile list`
	job_section_prefix="Job.$cluster_name."
	job_section_prefix_length=${#job_section_prefix}
	num_jobs=0
	for section in $section_list
	do
		if [[ $section =~ ^Job\.$cluster_name\. ]]
		then
			echo ${section:$job_section_prefix_length}
			num_jobs=`expr $num_jobs + 1`
		fi
	done
	echo >&2 "$num_jobs job(s) in cluster '$cluster_name'"

elif [ "$command" == "wait" ]
then

	# Get arguments
	if [ $# -lt 1 ]
	then
		echo >&2 "syntax: wait <cluster1> [<cluster2> [...]]"
		exit 1
	fi
	cluster_list=$*

	# Loop querying cluster state
	while true
	do
		# Query all clusters
		invalid_count=0
		created_count=0
		submitted_count=0
		completed_count=0
		killed_count=0
		total=`echo "$cluster_list" | wc -w`
		for cluster in $cluster_list
		do
			state=`$m2s_cluster_sh state $cluster` || exit 1
			if [ "$state" == "Created" ]
			then
				created_count=`expr $created_count + 1`
			elif [ "$state" == "Submitted" ]
			then
				submitted_count=`expr $submitted_count + 1`
			elif [ "$state" == "Completed" ]
			then
				completed_count=`expr $completed_count + 1`
			elif [ "$state" == "Killed" ]
			then
				killed_count=`expr $killed_count + 1`
			else
				invalid_count=`expr $invalid_count + 1`
			fi
		done

		# Output
		date=`date +%I:%M%P`
		echo -ne "\033[2K\r"
		echo -n "$total total, "
		echo -n "$created_count created, "
		echo -n "$submitted_count submitted, "
		echo -n "$completed_count completed, "
		echo -n "$killed_count killed, "
		echo -n "$invalid_count invalid "
		echo -n "(as of $date)"

		# End if no cluster is running (state='Submitted')
		if [ "$submitted_count" == 0 ]
		then
			echo
			exit
		fi

		# Delay
		sleep 10
	done

elif [ "$command" == "list-bench" ]
then

	# Get arguments
	if [ $# != 1 -a $# != 2 ]
	then
		echo >&2 "syntax: list-bench <server> [<suite>]"
		exit 1
	fi
	server_port=$1
	suite=$2

	# Split server and port
	server=`echo $server_port | awk -F: '{ print $1 }'`
	port=`echo $server_port | awk -F: '{ print $2 }'`
	[ -n "$port" ] || port=22

	# Connect to server and list benchmarks
	ssh -p $port $server '
		function error()
		{
			echo -e "\nerror: $1\n" >&2
			exit 1
		}

		# List a specific benchmark suite
		suite="'"$suite"'"
		if [ -n "$suite" ]
		then
			suite_dir="m2s-bench-$suite"
			cd $suite_dir 2>/dev/null \
				|| error "$suite: invalid benchmark suite"
			dir_list=`find -maxdepth 1 -type d -regex "\./[^\.].*"`
			for dir in $dir_list
			do
				echo ${dir:2}
			done
			exit
		fi

		# List all benchmark suites
		dir_list=`find -maxdepth 1 -regex "\./m2s-bench-.*" -type d`
		for dir in $dir_list
		do
			echo ${dir:12}
		done
	' || exit 1

elif [ "$command" == "server" ]
then

	# Get arguments
	if [ $# != 1 ]
	then
		echo >&2 "syntax: server <cluster>"
		exit 1
	fi
	cluster_name=$1
	cluster_section="Cluster.$cluster_name"

	# Read cluster properties
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists $cluster_section" >> $inifile_script
	echo "read $cluster_section State" >> $inifile_script
	echo "read $cluster_section Server" >> $inifile_script
	echo "read $cluster_section Port" >> $inifile_script
	$inifile_py $inifile run $inifile_script > $temp
	for i in 1
	do
		read section_exists
		read state
		read server
		read port
	done < $temp
	rm -f $inifile_script $temp

	# Check valid state of cluster
	[ "$section_exists" == 1 ] || error "cluster does not exist"
	[ "$state" != "Created" ] || error "cluster must be in state 'Submitted', 'Completed', or 'Killed'"

	# Print server and port
	[ -n "$server" ] || error "invalid server stored for cluster"
	echo -n $server
	[ "$port" == 22 ] || echo -n ":$port"
	echo

else
	
	error "$command: invalid command"

fi

