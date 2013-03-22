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
Run natively a program dynamically linked with Multi2Sim's OpenCL runtime,
passing the library path with LD_LIBRARY_PATH. The program attemps to load
OpenCL source with 'clCreateProgramWithSource'. A valid x86 kernel binary is
passed with environment variable M2S_OPENCL_BINARY.
The following command line is executed:

	LD_LIBRARY_PATH=$build_dir/lib/.libs \
		M2S_OPENCL_BINARY=vector-add-x86.bin \
		./vector-add-dyn-cpu

Expected output
---------------
First, the program should succeed to link itself dynamically with library
'libm2s-opencl.so'. The program should also succeed to load the x86 binary and
the runtime should run it natively, providing the correct output for a
10-element vector addition.
EOF
	exit

elif [ "$command" == "run" ]
then
	# Create temporary directory for execution
	mkdir -p $temp_dir || exit 1
	cd $temp_dir || exit 1
	rm -f $temp_dir/*

	# Copy executable
	cp $files_dir/vector-add-dyn-cpu . || exit 1
	cp $files_dir/vector-add-x86.bin . || exit 1
	cp $files_dir/vector-add.cl . || exit 1

	# Run command
	LD_LIBRARY_PATH=$build_dir/lib/.libs \
		M2S_OPENCL_BINARY=vector-add-x86.bin \
		./vector-add-dyn-cpu

	# Remove created files and finish
	rm -f $temp_dir/*
	exit

fi

