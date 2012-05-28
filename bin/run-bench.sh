#!/bin/bash

# print syntax
syntax() {
	prog=$(echo $0 | awk -F/ '{print $NF}')
	cat << EOF

Syntax:
  $prog [<options>] <targethost>[:<port>] <targetdir> <bench1> [<bench2> [...]]

Options:

  -p <nthreads>
      Number of threads

  -s <sim>
      Simulator executable

  -r
      Real execution of the benchmarks, instead of simulation.

  --sim-arg <arg>
      Arguments for the simulator. For example:
        --sim-arg "--cpu-sim detailed --cpu-config cpu_config.txt"

  --bench-arg <arg>
      Arguments for the first benchmark of the list. For example:
        --bench-arg "-x 8 -y 16 -z 8"

  --send <file>
      Send the file to the destination directory. The file will be in the same
      path where the simulator is copied. This argument can be specified multiple
      times in the command line.

Arguments:

  <targethost>
      Destination host

  <port>
      Port for ssh connections

  <targetdir>
      Destination directory

  <bench>
      Benchmark in format "suite/bench" (e.g. spec2000/164.gzip)

EOF
	exit 1
}

error() {
	echo -e "\nerror: $1\n" >&2
	exit 1
}




#
# Command-line options
#

nthreads=1
sim=""
nocondor=0
real=0
opt_cpu_sim=""
opt_gpu_sim=""
cpu_cache_config_file=""
cpu_config_file=""
gpu_cache_config_file=""
gpu_config_file=""

send_files=""
sim_args=""
bench_args=""

TEMP=`getopt -o p:s:nr --long send:,sim-arg:,bench-arg: \
	-n 'run-bench.sh' -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi

eval set -- "$TEMP"
while true ; do
	case "$1" in
	-p) nthreads=$2 ; shift 2 ;;
	-s) sim=$2 ; shift 2 ;;
	-n) nocondor=1 ; shift ;;
	-r) real=1 ; shift ;;
	--send) send_files="$send_files $2" ; shift 2 ;;
	--sim-arg) sim_args="$sim_args $2" ; shift 2 ;;
	--bench-arg) bench_args="$bench_args $2" ; shift 2 ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done


# Arguments
if [ $# -lt 3 ]; then syntax; fi
targethost=$(echo $1 | awk -F: '{print $1}')
port=$(echo $1 | awk -F: '{print $2}')
if [ "$port" == "" ]; then port=22; fi
shift
targetdir=$1; shift
benchlist=$*

# Check that simulator exists
if [ $real == 0 ]; then
	test -n "$sim" || error "a simulator must be specified (-s option)"
	test -f "$sim" || error "$sim: path not found"
else
	count=$(echo $benchlist | wc -w)
	test "$count" -eq 1 || error "only one benchmark allowed for real execution"
fi

# Files to be sent - check they exist
for file in $send_files; do
	test -f $file || error "$file: file not found"
done

# Create context directories
echo -n "sending to $targethost:$targetdir "
ssh -p $port $targethost '
	targetdir=$HOME/'$targetdir'
	mkdir -p $targetdir || exit 1
	cd $targetdir || exit 1

	# Find inifile script
	inifile="$HOME/bin/inifile"
	which $inifile >/dev/null 2>&1 || exit 4
	
	# Create context file
	ctxconfig="ctxconfig"
	rm -f $ctxconfig
	ctx=0
	for suitebench in '$benchlist'; do
		
		# Extract suite and benchmark
		awk "BEGIN{ if (\"$suitebench\" !~ /^[^\/]+\/[^\/]+$/) exit 1 }" || exit 2
		suite=$(echo $suitebench | awk -F/ "{ print \$1 }")
		bench=$(echo $suitebench | awk -F/ "{ print \$2 }")
		suitedir=$HOME/benchmarks/$suite
	
		# Copy bench
		benchdir=$suitedir/$bench
		if [ ! -d "$benchdir" ]; then exit 3; fi
		echo -n "$bench "
		rm -rf ctx$ctx
		mkdir -p ctx$ctx
		cp -r $suitedir/$bench/* ctx$ctx/
		
		# Entry in ctxconfig file
		section="Context $ctx"
		echo "[$section]" >> $ctxconfig
		echo "cwd = $targetdir/ctx$ctx" >> $ctxconfig
		echo "stdout = runspec.out" >> $ctxconfig
		cat $benchdir/runspec | sed "
			s,\(\$NTHREADS\>\)\|\(\${NTHREADS}\),'$nthreads',g;
			s,\(\$CWD\>\)\|\(\${CWD}\),$targetdir/ctx$ctx,g;
			">> $ctxconfig
		echo >> $ctxconfig

		# Add additional arguments to benchmark
		def_args=$($inifile $ctxconfig read "$section" Args)
		$inifile $ctxconfig write "$section" Args "$def_args '"$bench_args"'"
		
		# Next context
		ctx=$(($ctx+1))
	done
	
'

# Interpret return value
case $? in
	0) ;;
	1) error "cannot create $targetdir in remote host" ;;
	2) error "format of listed benchmarks must be 'suite/bench'" ;;
	3) error "cannot find some of the benchmarks in the list" ;;
	4) error "script 'inifile.py' not found in ~/bin directory of remote host" ;;
	*) error "error in remote host" ;;
esac


# Send simulator
if [ -n "$sim" ]; then
	echo -n "sim "
	scp -q -P $port $sim $targethost:$targetdir/sim || exit 1
fi


# Send files
for file in $send_files; do
	dest_file=$(basename $file)
	echo -n "$dest_file "
	scp -q -P $port $file $targethost:$targetdir/$dest_file || exit 1
done


# Send command
echo -n "command "
if [ "$nocondor" == 1 ]; then
	ssh -p $port $targethost '
		export PATH="$PATH:$HOME/bin"
		name='$targetdir'
		targetdir=$HOME/'$targetdir'
		ctxconfig="$targetdir/ctxconfig"

		# Exe, Cwd, Stdin, Stdout, Stderr, Args depending on real or simulated execution
		if [ '$real' == 1 ]; then
			exe=$(sed -n "s,exe *= *\(.*$\),\1,gp" $ctxconfig)
			exe="$targetdir/ctx0/$exe"
			cwd="$targetdir/ctx0"
			stdin=$(sed -n "s,stdin *= *\(.*$\),\1,gp" $ctxconfig)
			if [ -z "$stdin" ]; then stdin="/dev/null"; else stdin="$targetdir/ctx0/$stdin"; fi
			stdout="$targetdir/ctx0/runspec.out"
			stderr="$targetdir/ctx0/runspec.out"
			args=$(sed -n "s,args *= *\(.*$\),\1,gp" $ctxconfig)
		else
			exe="$targetdir/sim"
			cwd=$targetdir
			stdin="/dev/null"
			stdout="$targetdir/runspec.out"
			stderr="$targetdir/runspec.err"
			args="--ctx-config $targetdir/ctxconfig '"$sim_args"'"
		fi

		# Command
		run.cluster add $name $exe $cwd $stdin $stdout $stderr $args
	' || error "error with remote command"
else
	
	#
	# FIXME: not tested after changes
	#

	ssh -p $port $targethost '

		name='$targetdir'
		targetdir=$HOME/'$targetdir'
		ctxconfig="$targetdir/ctxconfig"

		# Exe, Cwd, Stdin, Stdout, Stderr, Args depending on real or simulated execution
		if [ '$real' == 1 ]; then
			exe=$(sed -n "s,exe *= *\(.*$\),\1,gp" $ctxconfig)
			exe="$targetdir/ctx0/$exe"
			cwd="$targetdir/ctx0"
			stdin=$(sed -n "s,stdin *= *\(.*$\),\1,gp" $ctxconfig)
			if [ -z "$stdin" ]; then stdin="/dev/null"; else stdin="$targetdir/ctx0/$stdin"; fi
			stdout="$targetdir/ctx0/runspec.out"
			stderr="$targetdir/ctx0/runspec.out"
			args=$(sed -n "s,args *= *\(.*$\),\1,gp" $ctxconfig)
		else
			exe="$targetdir/sim"
			cwd=$targetdir
			stdin="/dev/null"
			stdout="$targetdir/runspec.out"
			stderr="$targetdir/runspec.err"
			args="--ctx-config $targetdir/ctxconfig '"$sim_args"'"
		fi
		
		# Create condor submit file
		submit="submit"
		rm -f $submit
		echo "Executable = $exe" >> $submit
		echo "Universe = vanilla" >> $submit
		echo "Requirements = Memory > 100" >> $submit
		echo "Rank = -LoadAvg" >> $submit
		echo "+GPBatchJob = True" >> $submit
		echo "+LongRunningJob = True" >> $submit
		echo "Input = $stdin" >> $submit
		echo "Output = $stdout" >> $submit
		echo "Error = $stderr" >> $submit
		echo "InitialDir = $cwd" >> $submit
		echo "Log = $targetdir/runspec.log" >> $submit
		echo "Arguments = $args" >> $submit
		echo "Queue" >> $submit

		temp=$(mktemp)
		export CONDOR_CONFIG=/usr/local/condor/etc/condor_config
		/usr/local/bin/condor_submit -verbose $targetdir/submit > $temp
		rm -f $temp
	' || error "error executing remote command"
fi
echo "... ok"

# remove temporary files
rm -f $submit
