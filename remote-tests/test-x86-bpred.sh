#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"
M2S_CLIENT_KIT_DOC_PATH="$M2S_CLIENT_KIT_PATH/doc"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
m2s_cluster_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/m2s-cluster.sh"
inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"

# List of the first 5 integer + the first 5 floating-point benchmarks
bench_list="400.perlbench 401.bzip2 403.gcc 410.bwaves 416.gamess 429.mcf 433.milc 434.zeusmp 435.gromacs 445.gobmk"
bpred_kind_list="Perfect Taken NotTaken Bimodal TwoLevel Combined"

cluster_name="x86-bpred"
cluster_desc="
Run an architectural exploration with different types of branch predictor using
10 SPEC2006 benchmarks (5 integer and 5 floating-point). The benchmarks used
are:

Integer: 400.perlbench, 401.bzip2, 403.gcc, 429.mcf, 445.gobmk
Floating-point: 410.bwaves, 416.gamess, 433.milc, 434.zeusmp, 435.gromacs

The following is the list of branch predictors used in the experiment, together
with the arguments used in the x86 pipeline configuration file:

- Perfect branch predictor (Kind = Perfect)
- Taken branch predictor (Kind = Taken)
- Not-taken branch predictor (Kind = NotTaken)
- Bimodal, 1024-entry table of counters (Kind = Bimodal)
- Two-level, L1.size=1, L2.size=1024, HistorySize=8 (Kind = TwoLevel)
- Combined, Choice.size=1024 (Kind = Combined)


Cluster: $cluster_name
Secondary scripts: -
Additional info: $HOME/$M2S_CLIENT_KIT_DOC_PATH/verification-script-interface.txt
"



#
# Syntax
#

function syntax()
{
	echo "$cluster_desc"
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
	temp=`getopt -o r: -l configure-args:,tag: -n $prog_name -- "$@"`
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
		--) shift ; break ;;
		*) error "$1: invalid option" ;;
		esac
	done
	[ -z "$revision" ] || revision_arg="-r $revision"
	[ -z "$tag" ] || tag_arg="--tag $tag"
	[ -z "$configure_args" ] || configure_args_arg="--configure-args \"$configure_arg\""

	# Get argument
	[ $# == 1 ] || error "syntax: submit <server>[:<port>] [<options>]"
	server_port=$1

	# Create cluster
	$m2s_cluster_sh create $cluster_name || exit 1

	# Reset temporary x86 configuration file
	x86_config="$HOME/$M2S_CLIENT_KIT_TMP_PATH/x86-config"

	# Add jobs
	for bench in $bench_list
	do
		for bpred_kind in $bpred_kind_list
		do
			# Create x86 configuration file
			cp /dev/null $x86_config || exit 1
			echo "[ BranchPredictor ]" >> $x86_config
			echo "Kind = $bpred_kind" >> $x86_config

			# Add job
			$m2s_cluster_sh add $cluster_name $bench/$bpred_kind \
				--sim-args "--x86-max-inst 1000000" \
				--sim-args "--x86-sim detailed" \
				--sim-args "--x86-config x86-config" \
				--sim-args "--x86-report x86-report" \
				--send $x86_config \
				spec2006/$bench \
				|| exit 1
		done
	done

	# Remove temporary x86 configuration file
	rm -f $x86_config
	
	# Submit cluster
	$m2s_cluster_sh submit $cluster_name $server_port \
		$revision_arg $tag_arg $configure_args_arg \
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

	# Create an INI file with all results
	report_file="$cluster_path/report.ini"
	cp /dev/null $report_file || exit 1
	
	# Each section is named [ Benchmark.PredictorKind ]
	for bench in $bench_list
	do
		for bpred_kind in $bpred_kind_list
		do
			# Results file
			sim_err="$cluster_path/$bench/$bpred_kind/sim.err"
			[ -e $sim_err ] || exit 1

			# Read variables
			read \
				x86_cycles \
				x86_committed_instructions \
				x86_committed_instructions_per_cycle \
				x86_committed_micro_instructions \
				x86_committed_micro_instructions_per_cycle \
				x86_branch_prediction_accuracy \
				<<< `echo -e \
				"read x86 Cycles\n" \
				"read x86 CommittedInstructions\n" \
				"read x86 CommittedInstructionsPerCycle\n" \
				"read x86 CommittedMicroInstructions\n" \
				"read x86 CommittedMicroInstructionsPerCycle\n" \
				"read x86 BranchPredictionAccuracy\n" \
				| $inifile_py $sim_err run`

			# Section in report file
			echo "[ ${bench}.${bpred_kind} ]" >> $report_file
			echo "Cycles = $x86_cycles" >> $report_file
			echo "CommittedInstructions = $x86_committed_instructions" >> $report_file
			echo "CommittedInstructionsPerCycle = $x86_committed_instructions_per_cycle" >> $report_file
			echo "CommittedMicroInstructions = $x86_committed_micro_instructions" >> $report_file
			echo "CommittedMicroInstructionsPerCycle = $x86_committed_micro_instructions_per_cycle" >> $report_file
			echo "BranchPredictionAccuracy = $x86_branch_prediction_accuracy" >> $report_file

			# Blank line
			echo >> $report_file
		done
	done

	exit #######



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

		# Iterate through data sets
		for data_set in $data_set_list
		do
			# Read results
			job_dir="$cluster_path/$bench/$data_set"
			sim_err="$job_dir/sim.err"
			cp /dev/null $inifile_script
			echo "read x86 Time 0" >> $inifile_script
			echo "read x86 Instructions 0" >> $inifile_script
			$inifile_py $sim_err run $inifile_script > $inifile_script_output
			for i in 1
			do
				read cpu_time
				read cpu_inst
			done < $inifile_script_output

			# Add to lists
			cpu_time_list="$cpu_time_list, $cpu_time"
			cpu_inst_list="$cpu_inst_list, $cpu_inst"

			echo "$bench: Time=$cpu_time, Instructions=$cpu_inst"
		done

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

