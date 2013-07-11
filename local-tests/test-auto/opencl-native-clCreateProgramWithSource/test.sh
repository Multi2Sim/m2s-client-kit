#!/bin/bash


# Run natively a program dynamically linked with Multi2Sim's OpenCL runtime,
# passing the library path with LD_LIBRARY_PATH. The program attemps to load
# OpenCL source with 'clCreateProgramWithSource'. A valid x86 kernel binary is
# passed with environment variable M2S_OPENCL_BINARY.
# 
# First, the program should succeed to link itself dynamically with library
# 'libm2s-opencl.so'. The program should also succeed to load the x86 binary and
# the runtime should run it natively, providing the correct output for a
# 10-element vector addition.


M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

gcc vector-add.c -o vector-add -m32 \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
	M2S_OPENCL_BINARY=vector-add-x86.bin \
	./vector-add vector-add.cl
rm -f vector-add tmp_*
echo $?

