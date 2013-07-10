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
Southern Islands timing simulator, based on the input given in the GPU
configuration file.

The test ranges between 1-64 compute units. It expects to find as many L1 caches
as compute units, 6 L2 cache banks, and 6 global memory banks, and one scalar
cache every 4 compute units.

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
	for cus in `seq 1 64`
	do
		# Create Evergreen configuration file
		cat > si-config << EOF
[ Device ]
NumComputeUnits = $cus
EOF

		# Run commands
		$m2s --si-sim detailed --si-config si-config \
			--mem-report mem-report 2>/dev/null
		num_l1s=`cat mem-report | grep "\[ si-vector-l1.* \]" | wc -l`
		num_sl1s=`cat mem-report | grep "\[ si-scalar-l1.* \]" | wc -l`
		num_l2s=`cat mem-report | grep "\[ si-l2.* \]" | wc -l`
		num_gms=`cat mem-report | grep "\[ si-gm.* \]" | wc -l`
		[ $num_l1s = $cus ] || failed=1
		[ $num_sl1s = `expr \( $cus + 3 \) / 4` ] || failed=1
		[ $num_l2s = 6 ] || failed=1
		[ $num_gms = 6 ] || failed=1
		[ $failed = 0 ] || break
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
	rm -f si-config
	exit $failed

fi

