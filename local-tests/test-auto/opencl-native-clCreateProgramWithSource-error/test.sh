#!/bin/bash


# Run natively a program dynamically linked with Multi2Sim's OpenCL runtime,
# passing the library path with LD_LIBRARY_PATH. The program attemps to load
# OpenCL source with 'clCreateProgramWithSource'. Environment variable
# M2S_OPENCL_BINARY is not set, so no valid kernel binary is provided.
# The following command line is executed:
# 
# 	LD_LIBRARY_PATH=$build_dir/lib/.libs ./vector-add-dyn-cpu
# 
# First, the program should succeed to link itself dynamically with library
# 'libm2s-opencl.so'. Then the program should fail with an error message saying
# that runtime kernel compilation is not supported.


M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

gcc vector-add.c -o vector-add -m32 \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs ./vector-add vector-add.cl
rm -f vector-add
echo $?

