#!/bin/bash

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_M2S_BIN_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-bin"
M2S_CLIENT_KIT_M2S_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"

prog_name=`echo $0 | awk -F/ '{ print $NF }'`
build_dir="$HOME/$M2S_CLIENT_KIT_M2S_BUILD_PATH"
m2s="$build_dir/bin/m2s"
temp_dir="$HOME/$M2S_CLIENT_KIT_TMP_PATH/test-manual"
files_dir="$HOME/$M2S_CLIENT_KIT_PATH/local-tests/test-manual/files"


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
A program linked dynamically with 'libm2s-opencl.so' loads a GPU device,
then tries to load a Southern Islands program binary using
clCreateProgramWithSource and environment variable M2S_OPENCL_BINARY.

	LD_LIBRARY_PATH=$build_dir/lib/.libs \
		M2S_OPENCL_BINARY=vector-add-si.bin \
		m2s vector-add-dyn-gpu

Expected output
---------------
The program should show a warning about 'libm2s-opencl.so' being redirected to a
library path relative to the 'm2s' executable. Another warning should be shown
when the program successfully loads 'vector-add-si.bin', suggesting to use
clCreateProgramWithBinary instead. The vector addition should happend
successfully on the Southern Islands emulator.
EOF
	exit

elif [ "$command" == "run" ]
then
	# Create temporary directory for execution
	mkdir -p $temp_dir || exit 1
	cd $temp_dir || exit 1
	rm -f $temp_dir/*

	# Copy executable
	cp $files_dir/vector-add-dyn-gpu . || exit 1
	cp $files_dir/vector-add-si.bin . || exit 1
	cp $files_dir/vector-add.cl . || exit 1

	# Run command
	LD_LIBRARY_PATH=$build_dir/lib/.libs \
		M2S_OPENCL_BINARY=vector-add-si.bin \
		$m2s vector-add-dyn-gpu

	# Remove created files and finish
	rm -f $temp_dir/*
	exit

fi

