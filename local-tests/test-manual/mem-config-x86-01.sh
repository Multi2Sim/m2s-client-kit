#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_M2S_BIN_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-bin"
M2S_CLIENT_KIT_M2S_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
build_dir="$HOME/$M2S_CLIENT_KIT_M2S_BUILD_PATH"
m2s="$build_dir/bin/m2s"
temp_dir="$HOME/$M2S_CLIENT_KIT_TMP_PATH/test-manual"


function syntax()
{
	cat test-manual.txt 
	exit 1
}


# Check syntax
if [ $# != 1 ]
then
	syntax
fi

# Check 'm2s'
if [ ! -e "$m2s" ]
then
	echo "path '$m2s' not found" >&2
	exit 1
fi

# Read command
command=$1
shift

# Process command
if [ "$command" == "info" ]
then
	
	cat << EOF
Information
-----------
Check that the default memory configuration files are created correctly for the
x86 timing simulator, depending on the x86 memory configuration file passed
(number of threads and number of cores). The test will run 32 simulations,
combining 1-8 cores and 1-4 threads per core.

Expected output
---------------
Outputs will be processed automatically to count the number of caches in the
memory statistics file. If all goes right, we should see PASSED. If anything
goes wrong, the output will be FAILED.
EOF
	exit

elif [ "$command" == "run" ]
then
	# Create temporary directory for execution
	mkdir -p $temp_dir || exit 1
	cd $temp_dir || exit 1

	# Copy executable
	cp $build_dir/samples/x86/test-threads . || exit 1

	# Combinations
	failed=0
	for cores in `seq 1 8`
	do
		for threads in `seq 1 4`
		do

			# Create x86 configuration file
			cat > x86-config << EOF
[ General ]
Cores = $cores
Threads = $threads
EOF

			# Run commands
			$m2s --x86-sim detailed --x86-config x86-config \
				--mem-report mem-report 2>/dev/null
			num_l1s=`cat mem-report | grep "\[ x86-l1.* \]" | wc -l`
			num_l2s=`cat mem-report | grep "\[ x86-l2.* \]" | wc -l`
			num_mms=`cat mem-report | grep "\[ x86-mm.* \]" | wc -l`
			[ $num_l1s = $cores ] || failed=1
			[ $num_l2s = 1 ] || failed=1
			[ $num_mms = 1 ] || failed=1
		done
	done

	# Message
	if [ $failed = 0 ]
	then
		echo "Passed!"
	else
		echo "FAILED"
	fi

	# Remove created files and finish
	rm -f mem-report
	rm -f x86-config
	exit $failed

fi

