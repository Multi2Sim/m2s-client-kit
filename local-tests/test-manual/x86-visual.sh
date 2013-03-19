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
Run a timing simulation of the x86 'test-threads' program, record a trace using
option '--trace trace.gz' and run the x86 visualization tool using 'm2s --visual
trace.gz'.

Expected output
---------------
The output should show the x86 panel in the visualization tool with 4 x86 cores.
When opening each panel, the timing diagrams for each x86 core should be shown.
EOF
	exit

elif [ "$command" == "run" ]
then
	# Create temporary directory for execution
	mkdir -p $temp_dir || exit 1
	cd $temp_dir || exit 1

	# Copy executable
	cp $build_dir/samples/x86/test-threads . || exit 1

	# Create x86 configuration file
	cat > x86-config << EOF
[ General ]
Cores = 4
EOF

	# Run commands
	$m2s --x86-sim detailed --trace trace.gz --x86-config x86-config test-threads 4
	$m2s --visual trace.gz

	# Remove created files and finish
	rm -f test-threads
	rm -f trace.gz 
	rm -f x86-config
	exit

fi

