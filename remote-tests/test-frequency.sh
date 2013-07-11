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
bench_list="403.gcc 410.bwaves 434.zeusmp"
bench_list_count=`echo "$bench_list" | wc -w`
domain_list="cpu memory network"
domain_list_count=`wc -w <<< "$domain_list"`
freq_list=`seq 400 200 2000`
freq_list_count=`wc -w <<< "$freq_list"`

cluster_name="frequency"
cluster_desc="
Run an architectural exploration changing the frequency in three different
domains, one at a time: the x86 CPU, the memory system, and the interconnection
networks.

The test is run using three different benchmarks with low (gcc), medium
(zeusmp), and high (bwaves) ILP.

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

	# Temporary x86 configuration files
	x86_config="$HOME/$M2S_CLIENT_KIT_TMP_PATH/x86-config"
	mem_config="$HOME/$M2S_CLIENT_KIT_TMP_PATH/mem-config"
	net_config="$HOME/$M2S_CLIENT_KIT_TMP_PATH/net-config"

	# Maximum number of instructions
	x86_max_inst="10M"

	# Baseline configuration files
	base_x86_config=`mktemp`
	base_net_config=`mktemp`
	base_mem_config=`mktemp`
	cat > $base_mem_config << EOF
[ CacheGeometry x86-geo-l1 ]
Sets = 16
Assoc = 2
BlockSize = 16
Latency = 1
Policy = LRU

[ CacheGeometry x86-geo-l2 ]
Sets = 64
Assoc = 4
BlockSize = 64
Latency = 10
Policy = LRU

[ Module x86-l1-0 ]
Type = Cache
Geometry = x86-geo-l1
LowNetwork = x86-net-l1-l2
LowModules = x86-l2

[ Entry x86-core-0-thread-0 ]
Arch = x86
Core = 0
Thread = 0
Module = x86-l1-0

[ Module x86-l2 ]
Type = Cache
Geometry = x86-geo-l2
HighNetwork = x86-net-l1-l2
LowNetwork = x86-net-l2-mm
LowModules = x86-mm

[ Module x86-mm ]
Type = MainMemory
HighNetwork = x86-net-l2-mm
BlockSize = 64
Latency = 100

[ Network x86-net-l1-l2 ]
DefaultInputBufferSize = 144
DefaultOutputBuffersize = 144
DefaultBandwidth = 72

[ Network x86-net-l2-mm ]
DefaultInputBufferSize = 528
DefaultOutputBufferSize = 528
DefaultBandwidth = 264

EOF

	# Add jobs
	for domain in $domain_list
	do
		# Reset configuration files
		cp $base_x86_config $x86_config || exit 1
		cp $base_mem_config $mem_config || exit 1
		cp $base_net_config $net_config || exit 1

		# Get configuration file associated with current domain
		if [ "$domain" = "cpu" ]
		then
			config="$x86_config"
			base_config="$base_x86_config"
		elif [ "$domain" = "memory" ]
		then
			config="$mem_config"
			base_config="$base_mem_config"
		elif [ "$domain" = "network" ]
		then
			config="$net_config"
			base_config="$base_net_config"
		else
			error "$domain: invalid domain"
		fi

		# Frequencies
		for freq in $freq_list
		do
			# Add frequency to selected configuration file
			cp $base_config $config
			echo "[ General ]" >> $config
			echo "Frequency = $freq" >> $config

			# Benchmarks
			for bench in $bench_list
			do
				# Simulation without trace cache
				$m2s_cluster_sh add $cluster_name \
					$domain/$freq/$bench \
					--sim-args "--x86-config x86-config" \
					--sim-args "--mem-config mem-config" \
					--sim-args "--net-config net-config" \
					--sim-args "--x86-max-inst $x86_max_inst" \
					--sim-args "--x86-sim detailed" \
					--sim-args "--x86-report x86-report" \
					--sim-args "--mem-report mem-report" \
					--sim-args "--net-report net-report" \
					--send $x86_config \
					--send $mem_config \
					--send $net_config \
					spec2006/$bench \
					|| exit 1
			done
		done
	done

	# Remove temporary configuration files
	rm -f $base_x86_config
	rm -f $base_mem_config
	rm -f $base_net_config
	rm -f $x86_config
	rm -f $mem_config
	rm -f $net_config
	
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

	# Info
	echo -n "Collecting statistics"

	# Each section is named [ <domain>.<freq>.<bench> ]
	cp /dev/null $report_file || exit 1
	for domain in $domain_list
	do
		for freq in $freq_list
		do
			for bench in $bench_list
			do
				# Results file
				sim_err="$cluster_path/$domain/$freq/$bench/sim.err"
				[ -f $sim_err ] || error "$sim_err: report not found"

				# Read variables
				read \
					sim_time \
					<<< `echo -e \
					"read x86 SimTime 0\n" \
					| $inifile_py $sim_err run`

				# Write to report file
				echo "[$domain.$freq.$bench]" >> $report_file
				echo "SimTime = $sim_time" >> $report_file
				echo >> $report_file
			done
		done
	done

	# Info
	echo " - ok"




	#
	# PLOT 1 - CPU Domain
	#

	# Info
	png_file="cpu.png"
	echo -n "Plot for CPU domain in '$png_file'"

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
domain_list = '"$domain_list"'.split()
domain_count = len(domain_list)
freq_list = '"$freq_list"'.split()
freq_count = len(freq_list)
bench_list = '"$bench_list"'.split()
bench_count = len(bench_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_matrix = []
for bench in bench_list:
	data_line = []
	for freq in freq_list:
		section_name = 'cpu' + '.' + freq + '.' + bench
		option_name = 'SimTime'
		value_str = config.get(section_name, option_name).split()[0]
		value = float(value_str) / 1e6
		data_line.append(value)
	data_matrix.append(data_line)

fig = plt.figure()
fig.set_size_inches(7, 3)
ax = fig.add_subplot(111)

# Plot properties
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Time (ms)', fontproperties = prop_small_font)
ax.set_xlabel('Frequency (MHz)', fontproperties = prop_small_font)
ax.set_title('Execution Time for Different CPU Frequencies', fontproperties = prop_title_font)
ax.set_xticklabels(freq_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-0.5, freq_count - 0.5)
ax.grid(True, axis = 'y', color = 'gray')

# Lines
marker_list = [ 'go-', 'bv-', 'r*-' ]
for i in range(bench_count):
	ax.plot(data_matrix[i], marker_list[i], label = bench_list[i])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(prop = prop_small_font, loc = 'upper left', bbox_to_anchor=(1, 1))

plt.savefig('$cluster_path/report-files/$png_file', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"



	#
	# PLOT 2 - Memory domain
	#

	# Info
	png_file="memory.png"
	echo -n "Plot for memory domain in '$png_file'"

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
domain_list = '"$domain_list"'.split()
domain_count = len(domain_list)
freq_list = '"$freq_list"'.split()
freq_count = len(freq_list)
bench_list = '"$bench_list"'.split()
bench_count = len(bench_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_matrix = []
for bench in bench_list:
	data_line = []
	for freq in freq_list:
		section_name = 'memory' + '.' + freq + '.' + bench
		option_name = 'SimTime'
		value_str = config.get(section_name, option_name).split()[0]
		value = float(value_str) / 1e6
		data_line.append(value)
	data_matrix.append(data_line)

fig = plt.figure()
fig.set_size_inches(7, 3)
ax = fig.add_subplot(111)

# Plot properties
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Time (ms)', fontproperties = prop_small_font)
ax.set_xlabel('Frequency (MHz)', fontproperties = prop_small_font)
ax.set_title('Execution Time for Different CPU Frequencies', fontproperties = prop_title_font)
ax.set_xticklabels(freq_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-0.5, freq_count - 0.5)
ax.grid(True, axis = 'y', color = 'gray')

# Lines
marker_list = [ 'go-', 'bv-', 'r*-' ]
for i in range(bench_count):
	ax.plot(data_matrix[i], marker_list[i], label = bench_list[i])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(prop = prop_small_font, loc = 'upper left', bbox_to_anchor=(1, 1))

plt.savefig('$cluster_path/report-files/$png_file', dpi=100, bbox_inches='tight')
" > $python_script

	# Plot
	python $python_script || exit 1
	echo " - ok"



	#
	# PLOT 3 - Network domain
	#

	# Info
	png_file="network.png"
	echo -n "Plot for network domain in '$png_file'"

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
domain_list = '"$domain_list"'.split()
domain_count = len(domain_list)
freq_list = '"$freq_list"'.split()
freq_count = len(freq_list)
bench_list = '"$bench_list"'.split()
bench_count = len(bench_list)

# Parse file
config = ConfigParser.ConfigParser()
config.read('$report_file')

# Prepare data
data_matrix = []
for bench in bench_list:
	data_line = []
	for freq in freq_list:
		section_name = 'network' + '.' + freq + '.' + bench
		option_name = 'SimTime'
		value_str = config.get(section_name, option_name).split()[0]
		value = float(value_str) / 1e6
		data_line.append(value)
	data_matrix.append(data_line)

fig = plt.figure()
fig.set_size_inches(7, 3)
ax = fig.add_subplot(111)

# Plot properties
prop_small_font = fm.FontProperties(size = 10)
prop_title_font = fm.FontProperties(size = 10, weight = 'bold')
ax.set_ylabel('Time (ms)', fontproperties = prop_small_font)
ax.set_xlabel('Frequency (MHz)', fontproperties = prop_small_font)
ax.set_title('Execution Time for Different CPU Frequencies', fontproperties = prop_title_font)
ax.set_xticklabels(freq_list, rotation = 30)
ax.tick_params(labelsize = 10, top = False, bottom = False)
ax.set_xlim(-0.5, freq_count - 0.5)
ax.grid(True, axis = 'y', color = 'gray')

# Lines
marker_list = [ 'go-', 'bv-', 'r*-' ]
for i in range(bench_count):
	ax.plot(data_matrix[i], marker_list[i], label = bench_list[i])

# Legend
box = ax.get_position()
ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
ax.legend(prop = prop_small_font, loc = 'upper left', bbox_to_anchor=(1, 1))

plt.savefig('$cluster_path/report-files/$png_file', dpi=100, bbox_inches='tight')
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
	echo "<img src=\"report-files/cpu.png\"><br>" >> $html_file
	echo "<img src=\"report-files/memory.png\"><br>" >> $html_file
	echo "<img src=\"report-files/network.png\"><br>" >> $html_file

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

