#!/bin/bash


# A program linked dynamically with 'libm2s-opencl.so' loads a CPU device, but
# then tries to load a Southern Islands program binary using
# clCreateProgramWithSource and environment variable M2S_OPENCL_BINARY.
# 
# The program should link successfully with 'libm2s-opencl.so', but then should
# fail saying that the binary attempted to load is invalid.


gcc vector-add.c -o vector-add -m32 \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_BUILD_PATH/lib/.libs \
	M2S_OPENCL_BINARY=vector-add-si.bin \
	./vector-add vector-add.cl
echo $?
rm -f vector-add tmp_*

