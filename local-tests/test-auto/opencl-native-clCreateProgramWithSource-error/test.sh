#!/bin/bash


# Run natively a program dynamically linked with Multi2Sim's OpenCL runtime,
# passing the library path with LD_LIBRARY_PATH. The program attempts to load
# OpenCL source with 'clCreateProgramWithSource'. Environment variable
# M2S_OPENCL_BINARY is not set, so no valid kernel binary is provided.
# 
# First, the program should succeed to link itself dynamically with library
# 'libm2s-opencl.so'. Then the program should fail with an error message saying
# that runtime kernel compilation is not supported.


gcc vector-add.c -o vector-add -m32 \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_BUILD_PATH/lib/.libs ./vector-add vector-add.cl
echo $?
rm -f vector-add

