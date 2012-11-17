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
bench_list_count=`echo "$bench_list" | wc -w`
bpred_kind_list="Perfect Taken NotTaken Bimodal TwoLevel Combined"
bpred_kind_list_count=`echo "$bench_kind_list" | wc -w`

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
				--sim-args "--x86-max-inst 10M" \
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

	# Initialization for python reports
	python_script="$cluster_path/report.py"
	mkdir -p $cluster_path/report-files || exit 1

	# Create an INI file with all results
	report_file="$cluster_path/report.ini"
	cp /dev/null $report_file || exit 1

	# Info
	echo -n "Collecting statistics"
	
	# Each section is named [ Benchmark.PredictorKind ]
	for bpred_kind in $bpred_kind_list
	do
		# Reset accumulated values
		x86_cycles_acc=0
		x86_committed_instructions_acc=0
		x86_committed_instructions_per_cycle_acc=0
		x86_committed_micro_instructions_acc=0
		x86_committed_micro_instructions_per_cycle_acc=0
		x86_branch_prediction_accuracy_acc=0
		x86_branches_acc=0
		x86_mispred_acc=0

		# All benchmarks
		for bench in $bench_list
		do
			# Results file
			sim_err="$cluster_path/$bench/$bpred_kind/sim.err"
			x86_report="$cluster_path/$bench/$bpred_kind/x86-report"
			[ -e $sim_err ] || exit 1
			[ -e $x86_report ] || exit 1

			# Read variables
			read \
				x86_cycles \
				x86_committed_instructions \
				x86_committed_instructions_per_cycle \
				x86_committed_micro_instructions \
				x86_committed_micro_instructions_per_cycle \
				x86_branch_prediction_accuracy \
				<<< `echo -e \
				"read x86 Cycles 0\n" \
				"read x86 CommittedInstructions 0\n" \
				"read x86 CommittedInstructionsPerCycle 0\n" \
				"read x86 CommittedMicroInstructions 0\n" \
				"read x86 CommittedMicroInstructionsPerCycle 0\n" \
				"read x86 BranchPredictionAccuracy 0\n" \
				| $inifile_py $sim_err run`
			read \
				x86_branches \
				x86_mispred \
				<<< `echo -e \
				"read Global Commit.Branches 0\n" \
				"read Global Commit.Mispred 0\n" \
				| $inifile_py $x86_report run`

			# Section in report file
			echo "[ ${bpred_kind}.${bench} ]" >> $report_file
			echo "Cycles = $x86_cycles" >> $report_file
			echo "CommittedInstructions = $x86_committed_instructions" >> $report_file
			echo "CommittedInstructionsPerCycle = $x86_committed_instructions_per_cycle" >> $report_file
			echo "CommittedMicroInstructions = $x86_committed_micro_instructions" >> $report_file
			echo "CommittedMicroInstructionsPerCycle = $x86_committed_micro_instructions_per_cycle" >> $report_file
			echo "BranchPredictionAccuracy = $x86_branch_prediction_accuracy" >> $report_file
			echo "Branches = $x86_branches" >> $report_file
			echo "Mispred = $x86_mispred" >> $report_file

			# Accumulate values
			x86_cycles_acc=`bc -l <<< "$x86_cycles_acc + $x86_cycles"`
			x86_committed_instructions_acc=`bc -l <<< "$x86_committed_instructions_acc + $x86_committed_instructions"`
			x86_committed_instructions_per_cycle_acc=`bc -l <<< "$x86_committed_instructions_per_cycle_acc + \
				$x86_committed_instructions_per_cycle"`
			x86_committed_micro_instructions_acc=`bc -l <<< "$x86_committed_micro_instructions_acc + $x86_committed_micro_instructions"`
			x86_committed_micro_instructions_per_cycle_acc=`bc -l <<< "$x86_committed_micro_instructions_per_cycle_acc + \
				$x86_committed_micro_instructions_per_cycle"`
			x86_branch_prediction_accuracy_acc=`bc -l <<< "$x86_branch_prediction_accuracy_acc + $x86_branch_prediction_accuracy"`
			x86_branches_acc=`bc -l <<< "$x86_branches_acc + $x86_branches"`
			x86_mispred_acc=`bc -l <<< "$x86_mispred_acc + $x86_mispred"`

			# Blank line
			echo >> $report_file
		done

		# Calculate averages
		x86_cycles=`bc -l <<< "$x86_cycles_acc / $bench_list_count"`
		x86_committed_instructions=`bc -l <<< "$x86_committed_instructions_acc / $bench_list_count"`
		x86_committed_instructions_per_cycle=`bc -l <<< "$x86_committed_instructions_per_cycle_acc / $bench_list_count"`
		x86_committed_micro_instructions=`bc -l <<< "$x86_committed_micro_instructions_acc / $bench_list_count"`
		x86_committed_micro_instructions_per_cycle=`bc -l <<< "$x86_committed_micro_instructions_per_cycle_acc / $bench_list_count"`
		x86_branch_prediction_accuracy=`bc -l <<< "$x86_branch_prediction_accuracy_acc / $bench_list_count"`
		x86_branches=`bc -l <<< "$x86_branches_acc / $bench_list_count"`
		x86_mispred=`bc -l <<< "$x86_mispred_acc / $bench_list_count"`
		
		# Print averages
		echo "[ ${bpred_kind}.Average ]" >> $report_file
		echo "Cycles = $x86_cycles" >> $report_file
		echo "CommittedInstructions = $x86_committed_instructions" >> $report_file
		echo "CommittedInstructionsPerCycle = $x86_committed_instructions_per_cycle" >> $report_file
		echo "CommittedMicroInstructions = $x86_committed_micro_instructions" >> $report_file
		echo "CommittedMicroInstructionsPerCycle = $x86_committed_micro_instructions_per_cycle" >> $report_file
		echo "BranchPredictionAccuracy = $x86_branch_prediction_accuracy" >> $report_file
		echo "Branches = $x86_branches" >> $report_file
		echo "Mispred = $x86_mispred" >> $report_file
	done

	# Info
	echo " - ok"



	#
	# PLOT 1 - Cycles
	#

	# Info
	echo -n "Plot 'Execution Time' in 'cycles.png'"

	# List of cycles
	x86_perfect_cycles_list=
	x86_taken_cycles_list=
	x86_nottaken_cycles_list=
	x86_bimodal_cycles_list=
	x86_twolevel_cycles_list=
	x86_combined_cycles_list=
	x86_tick_list=
	comma=
	for bench in $bench_list Average
	do
		# Read values for benchmark
		read \
			x86_perfect_cycles \
			x86_taken_cycles \
			x86_nottaken_cycles \
			x86_bimodal_cycles \
			x86_twolevel_cycles \
			x86_combined_cycles \
			<<< `echo -e \
			"read Perfect.${bench} Cycles 0\n" \
			"read Taken.${bench} Cycles 0\n" \
			"read NotTaken.${bench} Cycles 0\n" \
			"read Bimodal.${bench} Cycles 0\n" \
			"read TwoLevel.${bench} Cycles 0\n" \
			"read Combined.${bench} Cycles 0\n" \
			| $inifile_py $report_file run`

		# Update lists
		x86_perfect_cycles_list="${x86_perfect_cycles_list}${comma}${x86_perfect_cycles}"
		x86_taken_cycles_list="${x86_taken_cycles_list}${comma}${x86_taken_cycles}"
		x86_nottaken_cycles_list="${x86_nottaken_cycles_list}${comma}${x86_nottaken_cycles}"
		x86_bimodal_cycles_list="${x86_bimodal_cycles_list}${comma}${x86_bimodal_cycles}"
		x86_twolevel_cycles_list="${x86_twolevel_cycles_list}${comma}${x86_twolevel_cycles}"
		x86_combined_cycles_list="${x86_combined_cycles_list}${comma}${x86_combined_cycles}"
		x86_tick_list="${x86_tick_list}${comma}'${bench}'"

		# New comma
		comma=", "
	done

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

N = $bench_list_count + 1
x86_perfect_cycles_list = ( $x86_perfect_cycles_list )
x86_taken_cycles_list = ( $x86_taken_cycles_list )
x86_nottaken_cycles_list = ( $x86_nottaken_cycles_list )
x86_bimodal_cycles_list = ( $x86_bimodal_cycles_list )
x86_twolevel_cycles_list = ( $x86_twolevel_cycles_list )
x86_combined_cycles_list = ( $x86_combined_cycles_list )

ind = np.arange(N)  # the x locations for the groups
width = 1.0 / 7       # the width of the bars

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Cycles')
ax.set_title('Execution Time for Branch Predictors', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(($x86_tick_list), rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, N)
ax.grid(True, axis = 'y', color = 'gray')

# Bars
rects_perfect_cycles = ax.bar(ind + width * 0, x86_perfect_cycles_list, width, color = color_array[0])
rects_taken_cycles = ax.bar(ind + width * 1, x86_taken_cycles_list, width, color = color_array[1])
rects_nottaken_cycles = ax.bar(ind + width * 2, x86_nottaken_cycles_list, width, color = color_array[2])
rects_bimodal_cycles = ax.bar(ind + width * 3, x86_bimodal_cycles_list, width, color = color_array[3])
rects_twolevel_cycles = ax.bar(ind + width * 4, x86_twolevel_cycles_list, width, color = color_array[4])
rects_combined_cycles = ax.bar(ind + width * 5, x86_combined_cycles_list, width, color = color_array[5])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend( \
	( \
		rects_perfect_cycles[0], \
		rects_taken_cycles[0], \
		rects_nottaken_cycles[0], \
		rects_bimodal_cycles[0], \
		rects_twolevel_cycles[0], \
		rects_combined_cycles[0]
	), ( \
		'Perfect', \
		'Taken', \
		'Not-Taken', \
		'Bimodal', \
		'Two-Level', \
		'Combined'
	), \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/cycles.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"




	#
	# PLOT 2 - Micro-Instructions Per Cycle
	#

	# Info
	echo -n "Plot 'Micro-Instructions Per Cycle' in 'ipc.png'"

	# List of values
	x86_perfect_ipc_list=
	x86_taken_ipc_list=
	x86_nottaken_ipc_list=
	x86_bimodal_ipc_list=
	x86_twolevel_ipc_list=
	x86_combined_ipc_list=
	x86_tick_list=
	comma=
	for bench in $bench_list Average
	do
		# Read values for benchmark
		read \
			x86_perfect_ipc \
			x86_taken_ipc \
			x86_nottaken_ipc \
			x86_bimodal_ipc \
			x86_twolevel_ipc \
			x86_combined_ipc \
			<<< `echo -e \
			"read Perfect.${bench} CommittedMicroInstructionsPerCycle 0\n" \
			"read Taken.${bench} CommittedMicroInstructionsPerCycle 0\n" \
			"read NotTaken.${bench} CommittedMicroInstructionsPerCycle 0\n" \
			"read Bimodal.${bench} CommittedMicroInstructionsPerCycle 0\n" \
			"read TwoLevel.${bench} CommittedMicroInstructionsPerCycle 0\n" \
			"read Combined.${bench} CommittedMicroInstructionsPerCycle 0\n" \
			| $inifile_py $report_file run`

		# Update lists
		x86_perfect_ipc_list="${x86_perfect_ipc_list}${comma}${x86_perfect_ipc}"
		x86_taken_ipc_list="${x86_taken_ipc_list}${comma}${x86_taken_ipc}"
		x86_nottaken_ipc_list="${x86_nottaken_ipc_list}${comma}${x86_nottaken_ipc}"
		x86_bimodal_ipc_list="${x86_bimodal_ipc_list}${comma}${x86_bimodal_ipc}"
		x86_twolevel_ipc_list="${x86_twolevel_ipc_list}${comma}${x86_twolevel_ipc}"
		x86_combined_ipc_list="${x86_combined_ipc_list}${comma}${x86_combined_ipc}"
		x86_tick_list="${x86_tick_list}${comma}'${bench}'"

		# New comma
		comma=", "
	done
		
	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

N = $bench_list_count + 1
x86_perfect_ipc_list = ( $x86_perfect_ipc_list )
x86_taken_ipc_list = ( $x86_taken_ipc_list )
x86_nottaken_ipc_list = ( $x86_nottaken_ipc_list )
x86_bimodal_ipc_list = ( $x86_bimodal_ipc_list )
x86_twolevel_ipc_list = ( $x86_twolevel_ipc_list )
x86_combined_ipc_list = ( $x86_combined_ipc_list )
	
ind = np.arange(N)  # the x locations for the groups
width = 1.0 / 7       # the width of the bars

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('\$\mu\$IPC')
ax.set_title('Micro-Instructions Committed per Cycle for Different Branch Predictors', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(($x86_tick_list), rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, N)
ax.grid(True, axis = 'y', color = 'gray')

# Bars
rects_perfect_ipc = ax.bar(ind + width * 0, x86_perfect_ipc_list, width, color = color_array[0])
rects_taken_ipc = ax.bar(ind + width * 1, x86_taken_ipc_list, width, color = color_array[1])
rects_nottaken_ipc = ax.bar(ind + width * 2, x86_nottaken_ipc_list, width, color = color_array[2])
rects_bimodal_ipc = ax.bar(ind + width * 3, x86_bimodal_ipc_list, width, color = color_array[3])
rects_twolevel_ipc = ax.bar(ind + width * 4, x86_twolevel_ipc_list, width, color = color_array[4])
rects_combined_ipc = ax.bar(ind + width * 5, x86_combined_ipc_list, width, color = color_array[5])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend( \
	( \
		rects_perfect_ipc[0], \
		rects_taken_ipc[0], \
		rects_nottaken_ipc[0], \
		rects_bimodal_ipc[0], \
		rects_twolevel_ipc[0], \
		rects_combined_ipc[0]
	), ( \
		'Perfect', \
		'Taken', \
		'Not-Taken', \
		'Bimodal', \
		'Two-Level', \
		'Combined'
	), \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/ipc.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"


	
	
	#
	# PLOT 3 - Number of Branches
	#

	# Info
	echo -n "Plot 'Number of Branches' in 'branches.png'"

	# List of values
	x86_perfect_branches_list=
	x86_perfect_mispred_list=
	x86_taken_branches_list=
	x86_taken_mispred_list=
	x86_nottaken_branches_list=
	x86_nottaken_mispred_list=
	x86_bimodal_branches_list=
	x86_bimodal_mispred_list=
	x86_twolevel_branches_list=
	x86_twolevel_mispred_list=
	x86_combined_branches_list=
	x86_combined_mispred_list=
	x86_tick_list=
	comma=
	for bench in $bench_list Average
	do
		# Read values for benchmark
		read \
			x86_perfect_branches \
			x86_perfect_mispred \
			x86_taken_branches \
			x86_taken_mispred \
			x86_nottaken_branches \
			x86_nottaken_mispred \
			x86_bimodal_branches \
			x86_bimodal_mispred \
			x86_twolevel_branches \
			x86_twolevel_mispred \
			x86_combined_branches \
			x86_combined_mispred \
			<<< `echo -e \
			"read Perfect.${bench} Branches 0\n" \
			"read Perfect.${bench} Mispred 0\n" \
			"read Taken.${bench} Branches 0\n" \
			"read Taken.${bench} Mispred 0\n" \
			"read NotTaken.${bench} Branches 0\n" \
			"read NotTaken.${bench} Mispred 0\n" \
			"read Bimodal.${bench} Branches 0\n" \
			"read Bimodal.${bench} Mispred 0\n" \
			"read TwoLevel.${bench} Branches 0\n" \
			"read TwoLevel.${bench} Mispred 0\n" \
			"read Combined.${bench} Branches 0\n" \
			"read Combined.${bench} Mispred 0\n" \
			| $inifile_py $report_file run`

		# Update lists
		x86_perfect_branches_list="${x86_perfect_branches_list}${comma}${x86_perfect_branches}"
		x86_perfect_mispred_list="${x86_perfect_mispred_list}${comma}${x86_perfect_mispred}"
		x86_taken_branches_list="${x86_taken_branches_list}${comma}${x86_taken_branches}"
		x86_taken_mispred_list="${x86_taken_mispred_list}${comma}${x86_taken_mispred}"
		x86_nottaken_branches_list="${x86_nottaken_branches_list}${comma}${x86_nottaken_branches}"
		x86_nottaken_mispred_list="${x86_nottaken_mispred_list}${comma}${x86_nottaken_mispred}"
		x86_bimodal_branches_list="${x86_bimodal_branches_list}${comma}${x86_bimodal_branches}"
		x86_bimodal_mispred_list="${x86_bimodal_mispred_list}${comma}${x86_bimodal_mispred}"
		x86_twolevel_branches_list="${x86_twolevel_branches_list}${comma}${x86_twolevel_branches}"
		x86_twolevel_mispred_list="${x86_twolevel_mispred_list}${comma}${x86_twolevel_mispred}"
		x86_combined_branches_list="${x86_combined_branches_list}${comma}${x86_combined_branches}"
		x86_combined_mispred_list="${x86_combined_mispred_list}${comma}${x86_combined_mispred}"
		x86_tick_list="${x86_tick_list}${comma}'${bench}'"

		# New comma
		comma=", "
	done
		
	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

N = $bench_list_count + 1
x86_perfect_branches_list = ( $x86_perfect_branches_list )
x86_perfect_mispred_list = ( $x86_perfect_mispred_list )
x86_taken_branches_list = ( $x86_taken_branches_list )
x86_taken_mispred_list = ( $x86_taken_mispred_list )
x86_nottaken_branches_list = ( $x86_nottaken_branches_list )
x86_nottaken_mispred_list = ( $x86_nottaken_mispred_list )
x86_bimodal_branches_list = ( $x86_bimodal_branches_list )
x86_bimodal_mispred_list = ( $x86_bimodal_mispred_list )
x86_twolevel_branches_list = ( $x86_twolevel_branches_list )
x86_twolevel_mispred_list = ( $x86_twolevel_mispred_list )
x86_combined_branches_list = ( $x86_combined_branches_list )
x86_combined_mispred_list = ( $x86_combined_mispred_list )
	
ind = np.arange(N)  # the x locations for the groups
width = 1.0 / 7       # the width of the bars

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Branches')
ax.set_title('Number of Correctly Predicted (and Total) Committed Branches', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(($x86_tick_list), rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, N)
ax.grid(True, axis = 'y', color = 'gray')

# Obtain 'pred' lists
x86_perfect_pred_list = [ x - y for (x, y) in zip(x86_perfect_branches_list, x86_perfect_mispred_list) ]
x86_taken_pred_list = [ x - y for (x, y) in zip(x86_taken_branches_list, x86_taken_mispred_list) ]
x86_nottaken_pred_list = [ x - y for (x, y) in zip(x86_nottaken_branches_list, x86_nottaken_mispred_list) ]
x86_bimodal_pred_list = [ x - y for (x, y) in zip(x86_bimodal_branches_list, x86_bimodal_mispred_list) ]
x86_twolevel_pred_list = [ x - y for (x, y) in zip(x86_twolevel_branches_list, x86_twolevel_mispred_list) ]
x86_combined_pred_list = [ x - y for (x, y) in zip(x86_combined_branches_list, x86_combined_mispred_list) ]

# Bars
rects_branches = ax.bar(ind + width * 0, x86_perfect_branches_list, width, color = '#cccccc')
ax.bar(ind + width * 1, x86_taken_branches_list, width, color = '#cccccc')
ax.bar(ind + width * 2, x86_nottaken_branches_list, width, color = '#cccccc')
ax.bar(ind + width * 3, x86_bimodal_branches_list, width, color = '#cccccc')
ax.bar(ind + width * 4, x86_twolevel_branches_list, width, color = '#cccccc')
ax.bar(ind + width * 5, x86_combined_branches_list, width, color = '#cccccc')
rects_perfect_pred = ax.bar(ind + width * 0, x86_perfect_pred_list, width, color = color_array[0])
rects_taken_pred = ax.bar(ind + width * 1, x86_taken_pred_list, width, color = color_array[1])
rects_nottaken_pred = ax.bar(ind + width * 2, x86_nottaken_pred_list, width, color = color_array[2])
rects_bimodal_pred = ax.bar(ind + width * 3, x86_bimodal_pred_list, width, color = color_array[3])
rects_twolevel_pred = ax.bar(ind + width * 4, x86_twolevel_pred_list, width, color = color_array[4])
rects_combined_pred = ax.bar(ind + width * 5, x86_combined_pred_list, width, color = color_array[5])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend( \
	( \
		rects_perfect_pred[0], \
		rects_taken_pred[0], \
		rects_nottaken_pred[0], \
		rects_bimodal_pred[0], \
		rects_twolevel_pred[0], \
		rects_combined_pred[0], \
		rects_branches[0]
	), ( \
		'Perfect', \
		'Taken', \
		'Not-Taken', \
		'Bimodal', \
		'Two-Level', \
		'Combined', \
		'Committed Branches' \
	), \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/branches.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"


	
	
	#
	# PLOT 4 - Branch Prediction Accuracy
	#

	# Info
	echo -n "Plot 'Branch Prediction Accuracy' in 'accuracy.png'"

	# List of values
	x86_perfect_accuracy_list=
	x86_taken_accuracy_list=
	x86_nottaken_accuracy_list=
	x86_bimodal_accuracy_list=
	x86_twolevel_accuracy_list=
	x86_combined_accuracy_list=
	x86_tick_list=
	comma=
	for bench in $bench_list Average
	do
		# Read values for benchmark
		read \
			x86_perfect_accuracy \
			x86_taken_accuracy \
			x86_nottaken_accuracy \
			x86_bimodal_accuracy \
			x86_twolevel_accuracy \
			x86_combined_accuracy \
			<<< `echo -e \
			"read Perfect.${bench} BranchPredictionAccuracy 0\n" \
			"read Taken.${bench} BranchPredictionAccuracy 0\n" \
			"read NotTaken.${bench} BranchPredictionAccuracy 0\n" \
			"read Bimodal.${bench} BranchPredictionAccuracy 0\n" \
			"read TwoLevel.${bench} BranchPredictionAccuracy 0\n" \
			"read Combined.${bench} BranchPredictionAccuracy 0\n" \
			| $inifile_py $report_file run`

		# Update lists
		x86_perfect_accuracy_list="${x86_perfect_accuracy_list}${comma}${x86_perfect_accuracy}"
		x86_taken_accuracy_list="${x86_taken_accuracy_list}${comma}${x86_taken_accuracy}"
		x86_nottaken_accuracy_list="${x86_nottaken_accuracy_list}${comma}${x86_nottaken_accuracy}"
		x86_bimodal_accuracy_list="${x86_bimodal_accuracy_list}${comma}${x86_bimodal_accuracy}"
		x86_twolevel_accuracy_list="${x86_twolevel_accuracy_list}${comma}${x86_twolevel_accuracy}"
		x86_combined_accuracy_list="${x86_combined_accuracy_list}${comma}${x86_combined_accuracy}"
		x86_tick_list="${x86_tick_list}${comma}'${bench}'"

		# New comma
		comma=", "
	done
		
	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

N = $bench_list_count + 1
x86_perfect_accuracy_list = ( $x86_perfect_accuracy_list )
x86_taken_accuracy_list = ( $x86_taken_accuracy_list )
x86_nottaken_accuracy_list = ( $x86_nottaken_accuracy_list )
x86_bimodal_accuracy_list = ( $x86_bimodal_accuracy_list )
x86_twolevel_accuracy_list = ( $x86_twolevel_accuracy_list )
x86_combined_accuracy_list = ( $x86_combined_accuracy_list )
	
ind = np.arange(N)  # the x locations for the groups
width = 1.0 / 7       # the width of the bars

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Accuracy')
ax.set_title('Branch Predictor Accuracy for Different Prediction Models', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(($x86_tick_list), rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, N)
ax.grid(True, axis = 'y', color = 'gray')

# Bars
rects_perfect_accuracy = ax.bar(ind + width * 0, x86_perfect_accuracy_list, width, color = color_array[0])
rects_taken_accuracy = ax.bar(ind + width * 1, x86_taken_accuracy_list, width, color = color_array[1])
rects_nottaken_accuracy = ax.bar(ind + width * 2, x86_nottaken_accuracy_list, width, color = color_array[2])
rects_bimodal_accuracy = ax.bar(ind + width * 3, x86_bimodal_accuracy_list, width, color = color_array[3])
rects_twolevel_accuracy = ax.bar(ind + width * 4, x86_twolevel_accuracy_list, width, color = color_array[4])
rects_combined_accuracy = ax.bar(ind + width * 5, x86_combined_accuracy_list, width, color = color_array[5])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend( \
	( \
		rects_perfect_accuracy[0], \
		rects_taken_accuracy[0], \
		rects_nottaken_accuracy[0], \
		rects_bimodal_accuracy[0], \
		rects_twolevel_accuracy[0], \
		rects_combined_accuracy[0]
	), ( \
		'Perfect', \
		'Taken', \
		'Not-Taken', \
		'Bimodal', \
		'Two-Level', \
		'Combined'
	), \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/accuracy.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"


	
	
	#
	# Create HTML report
	#

	# Header
	html_file="$cluster_path/report.html"
	cp /dev/null $html_file
	echo "<html><body>" >> $html_file
	echo "<h1>Report for '$cluster_name'</h1>" >> $html_file
	echo "<pre>$cluster_desc</pre>" >> $html_file

	# Benchmarks
	echo "<img src=\"report-files/cycles.png\"><br>" >> $html_file
	echo "<img src=\"report-files/ipc.png\"><br>" >> $html_file
	echo "<img src=\"report-files/branches.png\"><br>" >> $html_file
	echo "<img src=\"report-files/accuracy.png\"><br>" >> $html_file

	# End
	echo "</body></html>" >> $html_file
	echo "Full report generated in '$html_file'"


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

