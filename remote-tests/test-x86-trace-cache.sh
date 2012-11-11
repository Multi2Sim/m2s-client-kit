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
num_sets_list="32 64 128"
num_sets_list_count=`echo "$num_sets_list" | wc -w`
num_ways_list="4 8 16"
num_ways_list_count=`echo "$num_ways_list" | wc -w`

cluster_name="x86-trace-cache"
cluster_desc="
Run an architectural exploration with different sizes for the trace cache. The
sizes include:

- No trace cache.

- 32 sets, 4 ways
- 32 sets, 8 ways
- 32 sets, 16 ways

- 64 sets, 4 ways
- 64 sets, 8 ways
- 64 sets, 16 ways

- 128 sets, 4 ways
- 128 sets, 8 ways
- 128 sets, 16 ways

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
		# Common parameters
		x86_max_inst="10M"

		# Simulation without trace cache
		$m2s_cluster_sh add $cluster_name $bench/no-trace-cache \
			--sim-args "--x86-max-inst $x86_max_inst" \
			--sim-args "--x86-sim detailed" \
			--sim-args "--x86-report x86-report" \
			spec2006/$bench \
			|| exit 1

		# Add simulations with trace cache
		for num_sets in $num_sets_list
		do
			for num_ways in $num_ways_list
			do
				# Create x86 configuration file
				cp /dev/null $x86_config || exit 1
				echo "[ TraceCache ]" >> $x86_config
				echo "Present = True" >> $x86_config
				echo "Sets = $num_sets" >> $x86_config
				echo "Assoc = $num_ways" >> $x86_config
	
				# Add job
				$m2s_cluster_sh add $cluster_name $bench/$num_sets/$num_ways \
					--sim-args "--x86-max-inst $x86_max_inst" \
					--sim-args "--x86-sim detailed" \
					--sim-args "--x86-config x86-config" \
					--sim-args "--x86-report x86-report" \
					--send $x86_config \
					spec2006/$bench \
					|| exit 1
			done
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

	# Create directory list
	dir_list="no-trace-cache"
	for num_sets in $num_sets_list
	do
		for num_ways in $num_ways_list
		do
			dir_list="$dir_list $num_sets/$num_ways"
		done
	done
	dir_list_count=`wc -w <<< "$dir_list"`

	# Initialization for python reports
	python_script="$cluster_path/report.py"
	mkdir -p $cluster_path/report-files || exit 1

	# Create an INI file with all results
	report_file="$cluster_path/report.ini"

	# Reset report file
	cp /dev/null $report_file || exit 1

	# Info
	echo -n "Collecting statistics"

	# Each section is named [ Benchmark.<sets>/<ways> ] or [ Benchmark.no-trace-cache ]
	for dir in $dir_list
	do
		# Reset accumulated values
		x86_cycles_acc=0
		x86_committed_instructions_acc=0
		x86_committed_instructions_per_cycle_acc=0
		x86_committed_micro_instructions_acc=0
		x86_committed_micro_instructions_per_cycle_acc=0
		x86_dispatched_micro_instructions_acc=0
		x86_branch_prediction_accuracy_acc=0
		x86_trace_cache_accesses_acc=0
		x86_trace_cache_hits_acc=0
		x86_trace_cache_dispatched_acc=0
		x86_trace_cache_committed_acc=0
		x86_trace_cache_squashed_acc=0
		x86_trace_cache_trace_length_acc=0

		# All benchmarks
		for bench in $bench_list
		do
			# Results file
			sim_err="$cluster_path/$bench/$dir/sim.err"
			x86_report="$cluster_path/$bench/$dir/x86-report"
			[ -e $sim_err ] || error "$sim_err: report not found"
			[ -e $x86_report ] || error "$x86_report: report not found"

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
				x86_dispatched_micro_instructions \
				x86_trace_cache_accesses \
				x86_trace_cache_hits \
				x86_trace_cache_dispatched \
				x86_trace_cache_committed \
				x86_trace_cache_squashed \
				x86_trace_cache_trace_length \
				<<< `echo -e \
				"read c0t0 Dispatch.Total 0\n" \
				"read c0t0 TraceCache.Accesses 0\n" \
				"read c0t0 TraceCache.Hits 0\n" \
				"read c0t0 TraceCache.Dispatched 0\n" \
				"read c0t0 TraceCache.Committed 0\n" \
				"read c0t0 TraceCache.Squashed 0\n" \
				"read c0t0 TraceCache.TraceLength 0\n" \
				| $inifile_py $x86_report run`

			# Section in report file
			echo "[${dir}.${bench}]" >> $report_file
			echo "Cycles = $x86_cycles" >> $report_file
			echo "CommittedInstructions = $x86_committed_instructions" >> $report_file
			echo "CommittedInstructionsPerCycle = $x86_committed_instructions_per_cycle" >> $report_file
			echo "CommittedMicroInstructions = $x86_committed_micro_instructions" >> $report_file
			echo "CommittedMicroInstructionsPerCycle = $x86_committed_micro_instructions_per_cycle" >> $report_file
			echo "BranchPredictionAccuracy = $x86_branch_prediction_accuracy" >> $report_file
			echo "DispatchedMicroInstructions = $x86_dispatched_micro_instructions" >> $report_file
			echo "TraceCache.Accesses = $x86_trace_cache_accesses" >> $report_file
			echo "TraceCache.Hits = $x86_trace_cache_hits" >> $report_file
			echo "TraceCache.Dispatched = $x86_trace_cache_dispatched" >> $report_file
			echo "TraceCache.Committed = $x86_trace_cache_committed" >> $report_file
			echo "TraceCache.Squashed = $x86_trace_cache_squashed" >> $report_file
			echo "TraceCache.TraceLength = $x86_trace_cache_trace_length" >> $report_file

			# Accumulate values
			x86_cycles_acc=`bc -l <<< "$x86_cycles_acc + $x86_cycles"`
			x86_committed_instructions_acc=`bc -l <<< "$x86_committed_instructions_acc + $x86_committed_instructions"`
			x86_committed_instructions_per_cycle_acc=`bc -l <<< "$x86_committed_instructions_per_cycle_acc + \
				$x86_committed_instructions_per_cycle"`
			x86_committed_micro_instructions_acc=`bc -l <<< "$x86_committed_micro_instructions_acc + $x86_committed_micro_instructions"`
			x86_committed_micro_instructions_per_cycle_acc=`bc -l <<< "$x86_committed_micro_instructions_per_cycle_acc + \
				$x86_committed_micro_instructions_per_cycle"`
			x86_branch_prediction_accuracy_acc=`bc -l <<< "$x86_branch_prediction_accuracy_acc + $x86_branch_prediction_accuracy"`
			x86_dispatched_micro_instructions_acc=`bc -l <<< "$x86_dispatched_micro_instructions_acc + $x86_dispatched_micro_instructions"`
			x86_trace_cache_accesses_acc=`bc -l <<< "$x86_trace_cache_accesses_acc + $x86_trace_cache_accesses"`
			x86_trace_cache_hits_acc=`bc -l <<< "$x86_trace_cache_hits_acc + $x86_trace_cache_hits"`
			x86_trace_cache_dispatched_acc=`bc -l <<< "$x86_trace_cache_dispatched_acc + $x86_trace_cache_dispatched"`
			x86_trace_cache_committed_acc=`bc -l <<< "$x86_trace_cache_committed_acc + $x86_trace_cache_committed"`
			x86_trace_cache_squashed_acc=`bc -l <<< "$x86_trace_cache_squashed_acc + $x86_trace_cache_squashed"`
			x86_trace_cache_trace_length_acc=`bc -l <<< "$x86_trace_cache_trace_length_acc + $x86_trace_cache_trace_length"`

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
		x86_dispatched_micro_instructions=`bc -l <<< "$x86_dispatched_micro_instructions_acc / $bench_list_count"`
		x86_trace_cache_accesses=`bc -l <<< "$x86_trace_cache_accesses_acc / $bench_list_count"`
		x86_trace_cache_hits=`bc -l <<< "$x86_trace_cache_hits_acc / $bench_list_count"`
		x86_trace_cache_dispatched=`bc -l <<< "$x86_trace_cache_dispatched_acc / $bench_list_count"`
		x86_trace_cache_committed=`bc -l <<< "$x86_trace_cache_committed_acc / $bench_list_count"`
		x86_trace_cache_squashed=`bc -l <<< "$x86_trace_cache_squashed_acc / $bench_list_count"`
		x86_trace_cache_trace_length=`bc -l <<< "$x86_trace_cache_trace_length_acc / $bench_list_count"`
		
		# Print averages
		echo "[${dir}.Average]" >> $report_file
		echo "Cycles = $x86_cycles" >> $report_file
		echo "CommittedInstructions = $x86_committed_instructions" >> $report_file
		echo "CommittedInstructionsPerCycle = $x86_committed_instructions_per_cycle" >> $report_file
		echo "CommittedMicroInstructions = $x86_committed_micro_instructions" >> $report_file
		echo "CommittedMicroInstructionsPerCycle = $x86_committed_micro_instructions_per_cycle" >> $report_file
		echo "BranchPredictionAccuracy = $x86_branch_prediction_accuracy" >> $report_file
		echo "DispatchedMicroInstructions = $x86_dispatched_micro_instructions" >> $report_file
		echo "TraceCache.Accesses = $x86_trace_cache_accesses" >> $report_file
		echo "TraceCache.Hits = $x86_trace_cache_hits" >> $report_file
		echo "TraceCache.Dispatched = $x86_trace_cache_dispatched" >> $report_file
		echo "TraceCache.Committed = $x86_trace_cache_committed" >> $report_file
		echo "TraceCache.Squashed = $x86_trace_cache_squashed" >> $report_file
		echo "TraceCache.TraceLength = $x86_trace_cache_trace_length" >> $report_file
	done

	# Info
	echo " - ok"




	#
	# PLOT 1 - Cycles
	#

	# Info
	echo -n "Plot 'Execution Time' in 'cycles.png'"

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import ConfigParser

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

# Read arrays
bench_list = '"$bench_list"'.split()
bench_list.append('Average')
bench_count = len(bench_list)
dir_list = '"$dir_list"'.split()
dir_count = len(dir_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_matrix = []
for dir in dir_list:
	data_line = []
	for bench in bench_list:
		section_name = dir + '.' + bench
		option_name = 'Cycles'
		value = config.getfloat(section_name, option_name)
		data_line.append(value)
	data_matrix.append(data_line)


ind = np.arange(bench_count)
width = 1.0 / (dir_count + 1)

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Cycles')
ax.set_title('Execution Time for Different Trace Cache Geometries', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(bench_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, bench_count)
ax.grid(True, axis = 'y', color = 'gray')

# Bars
rects_list = []
for dir_index in range(dir_count):
	rects = ax.bar(ind + width * dir_index, data_matrix[dir_index], width, color = color_array[dir_index])
	rects_list.append(rects[0])

# Legend elements
legend_elem_list = []
for dir in dir_list:
	if dir == 'no-trace-cache':
		legend_elem_list.append('No trace cache')
	else:
		sets_ways = dir.split('/')
		legend_elem_list.append(sets_ways[0] + ' sets, ' + \
			sets_ways[1] + ' ways')

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(rects_list, \
	legend_elem_list, \
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
	# PLOT 2 - Speedup
	#

	# Info
	echo -n "Plot 'Speedup of Trace Cache' in 'speedup.png'"

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import ConfigParser

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

# Read arrays
bench_list = '"$bench_list"'.split()
bench_list.append('Average')
bench_count = len(bench_list)
dir_list = '"$dir_list"'.split()
baseline_dir = dir_list.pop(0)
dir_count = len(dir_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_matrix = []
for dir in dir_list:
	data_line = []
	for bench in bench_list:
		baseline_section_name = baseline_dir + '.' + bench
		section_name = dir + '.' + bench
		option_name = 'Cycles'
		baseline_value = config.getfloat(baseline_section_name, option_name)
		value = config.getfloat(section_name, option_name)
		speedup = baseline_value / value;
		data_line.append(speedup)
	data_matrix.append(data_line)


ind = np.arange(bench_count)
width = 1.0 / (dir_count + 1)

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Speedup')
ax.set_title('Speedup of a Trace Cache over a Baseline Design without Trace Cache', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(bench_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, bench_count)
ax.grid(True, axis = 'y', color = 'gray')

# Bars
rects_list = []
for dir_index in range(dir_count):
	rects = ax.bar(ind + width * dir_index, data_matrix[dir_index], width, color = color_array[dir_index])
	rects_list.append(rects[0])

# Legend elements
legend_elem_list = []
for dir in dir_list:
	sets_ways = dir.split('/')
	legend_elem_list.append(sets_ways[0] + ' sets, ' + \
		sets_ways[1] + ' ways')

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(rects_list, \
	legend_elem_list, \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/speedup.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"




	#
	# PLOT 3 - Accesses and Hits
	#

	# Info
	echo -n "Plot 'Accesses and Hits' in 'hits.png'"

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import ConfigParser

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

# Read arrays
bench_list = '"$bench_list"'.split()
bench_list.append('Average')
bench_count = len(bench_list)
dir_list = '"$dir_list"'.split()
baseline_dir = dir_list.pop(0)
dir_count = len(dir_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_hits_matrix = []
data_accesses_matrix = []
for dir in dir_list:
	data_hits_line = []
	data_accesses_line = []
	for bench in bench_list:
		section_name = dir + '.' + bench
		value_hits = config.getfloat(section_name, 'TraceCache.Hits')
		value_accesses = config.getfloat(section_name, 'TraceCache.Accesses')
		data_hits_line.append(value_hits)
		data_accesses_line.append(value_accesses)
	data_hits_matrix.append(data_hits_line)
	data_accesses_matrix.append(data_accesses_line)


ind = np.arange(bench_count)
width = 1.0 / (dir_count + 1)

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Accesses')
ax.set_title('Number of Trace Cache Hits for different Trace Cache Geometries', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(bench_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, bench_count)
ax.grid(True, axis = 'y', color = 'gray')

# Bars for Accesses
for dir_index in range(dir_count):
	accesses_rects = ax.bar(ind + width * dir_index, data_accesses_matrix[dir_index], width, color = '#cccccc')

# Bars for Hits
rects_list = []
for dir_index in range(dir_count):
	rects = ax.bar(ind + width * dir_index, data_hits_matrix[dir_index], width, color = color_array[dir_index])
	rects_list.append(rects[0])

# Legend elements
legend_elem_list = []
for dir in dir_list:
	sets_ways = dir.split('/')
	legend_elem_list.append(sets_ways[0] + ' sets, ' + \
		sets_ways[1] + ' ways')

# Add element for Accesses
rects_list.append(accesses_rects[0])
legend_elem_list.append('Total Accesses')

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(rects_list, \
	legend_elem_list, \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/hits.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"


	
	
	#
	# PLOT 4 - Squashed Micro-Instructions
	#

	# Info
	echo -n "Plot 'Squashed Micro-Instructions' in 'squashed.png'"

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import ConfigParser

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

# Read arrays
bench_list = '"$bench_list"'.split()
bench_list.append('Average')
bench_count = len(bench_list)
dir_list = '"$dir_list"'.split()
dir_list.pop(0)
dir_count = len(dir_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_squashed_matrix = []
data_dispatched_matrix = []
for dir in dir_list:
	data_squashed_line = []
	data_dispatched_line = []
	for bench in bench_list:
		section_name = dir + '.' + bench
		value_squashed = config.getfloat(section_name, 'TraceCache.Squashed')
		value_dispatched = config.getfloat(section_name, 'TraceCache.Dispatched')
		data_squashed_line.append(value_squashed)
		data_dispatched_line.append(value_dispatched)
	data_squashed_matrix.append(data_squashed_line)
	data_dispatched_matrix.append(data_dispatched_line)


ind = np.arange(bench_count)
width = 1.0 / (dir_count + 1)

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Micro-Instructions')
ax.set_title('Number of Squashed Micro-Instructions Coming from Mispredicted Traces', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(bench_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, bench_count)
ax.grid(True, axis = 'y', color = 'gray')

# Bars for Dispatched
for dir_index in range(dir_count):
	rects_dispatched = ax.bar(ind + width * dir_index, data_dispatched_matrix[dir_index], width, color = '#cccccc')

# Bars for Squashed
rects_list = []
for dir_index in range(dir_count):
	rects = ax.bar(ind + width * dir_index, data_squashed_matrix[dir_index], width, color = color_array[dir_index])
	rects_list.append(rects[0])

# Legend elements
legend_elem_list = []
for dir in dir_list:
	sets_ways = dir.split('/')
	legend_elem_list.append(sets_ways[0] + ' sets, ' + \
		sets_ways[1] + ' ways')

# Add legend element for Dispatched
rects_list.append(rects_dispatched[0])
legend_elem_list.append('Dispatched from TC')

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(rects_list, \
	legend_elem_list, \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/squashed.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"


	
	
	#
	# PLOT 5 - Dispatched Micro-Instructions
	#

	# Info
	echo -n "Plot 'Dispatched Micro-Instructions' in 'dispatched.png'"

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import ConfigParser

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

# Read arrays
bench_list = '"$bench_list"'.split()
bench_list.append('Average')
bench_count = len(bench_list)
dir_list = '"$dir_list"'.split()
dir_list.pop(0)
dir_count = len(dir_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_tc_matrix = []
data_total_matrix = []
for dir in dir_list:
	data_tc_line = []
	data_total_line = []
	for bench in bench_list:
		section_name = dir + '.' + bench
		value_tc = config.getfloat(section_name, 'TraceCache.Squashed')
		value_total = config.getfloat(section_name, 'DispatchedMicroInstructions')
		data_tc_line.append(value_tc)
		data_total_line.append(value_total)
	data_tc_matrix.append(data_tc_line)
	data_total_matrix.append(data_total_line)


ind = np.arange(bench_count)
width = 1.0 / (dir_count + 1)

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Micro-Instructions')
ax.set_title('Dispatched Micro-Instructions Coming from the Trace Cache', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(bench_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, bench_count)
ax.grid(True, axis = 'y', color = 'gray')

# Bars for Total
for dir_index in range(dir_count):
	rects_total = ax.bar(ind + width * dir_index, data_total_matrix[dir_index], width, color = '#cccccc')

# Bars for Trace Cache
rects_list = []
for dir_index in range(dir_count):
	rects = ax.bar(ind + width * dir_index, data_tc_matrix[dir_index], width, color = color_array[dir_index])
	rects_list.append(rects[0])

# Legend elements
legend_elem_list = []
for dir in dir_list:
	sets_ways = dir.split('/')
	legend_elem_list.append(sets_ways[0] + ' sets, ' + \
		sets_ways[1] + ' ways')

# Add legend element for Dispatched
rects_list.append(rects_total[0])
legend_elem_list.append('Total Dispatched')

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(rects_list, \
	legend_elem_list, \
	prop = prop_small_font, \
	loc = 'upper left', \
	bbox_to_anchor=(1, 1)
	)

plt.savefig('$cluster_path/report-files/dispatched.png', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"


	
	
	#
	# PLOT 6 - Branch Prediction Accuracy
	#

	# Info
	echo -n "Plot 'Branch Prediction Accuracy' in 'accuracy.png'"

	# Python script to plot results
	echo "
#!/usr/bin/env python
import numpy as np
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import ConfigParser

color_array = [ '#004586', '#ff420e', '#ffd320', '#579d1c', \
	'#7e0021', '#83caff', '#314004', '#aecf00', \
	'#4e1f6f', '#ff950e', '#c5000b', '#0084d1' ]

# Read arrays
bench_list = '"$bench_list"'.split()
bench_list.append('Average')
bench_count = len(bench_list)
dir_list = '"$dir_list"'.split()
dir_count = len(dir_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_matrix = []
for dir in dir_list:
	data_line = []
	for bench in bench_list:
		section_name = dir + '.' + bench
		value = config.getfloat(section_name, 'BranchPredictionAccuracy')
		data_line.append(value)
	data_matrix.append(data_line)


ind = np.arange(bench_count)
width = 1.0 / (dir_count + 1)

fig = plt.figure()
fig.set_size_inches(10, 2.5)
ax = fig.add_subplot(111)

# add some
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Fraction of Branches')
ax.set_title('Branch Prediction Accuracy (Fraction of Well Predicted Committed Branches)', fontproperties = prop_title_font)
ax.set_xticks(ind + width)
ax.set_xticklabels(bench_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-width, bench_count)
ax.grid(True, axis = 'y', color = 'gray')

# Bars
rects_list = []
for dir_index in range(dir_count):
	rects = ax.bar(ind + width * dir_index, data_matrix[dir_index], width, color = color_array[dir_index])
	rects_list.append(rects[0])

# Legend elements
legend_elem_list = []
for dir in dir_list:
	if dir == 'no-trace-cache':
		legend_elem_list.append('No trace cache')
	else:
		sets_ways = dir.split('/')
		legend_elem_list.append(sets_ways[0] + ' sets, ' + \
			sets_ways[1] + ' ways')

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(rects_list, \
	legend_elem_list, \
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
	echo "<img src=\"report-files/speedup.png\"><br>" >> $html_file
	echo "<img src=\"report-files/hits.png\"><br>" >> $html_file
	echo "<img src=\"report-files/squashed.png\"><br>" >> $html_file
	echo "<img src=\"report-files/dispatched.png\"><br>" >> $html_file
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

