#!/bin/bash


# A program linked dynamically with 'libm2s-opencl.so' loads a GPU device,
# then tries to load a Southern Islands program binary using
# clCreateProgramWithSource and environment variable M2S_OPENCL_BINARY.
# 
# The program should show a warning about 'libm2s-opencl.so' being redirected to a
# library path relative to the 'm2s' executable. Another warning should be shown
# when the program successfully loads 'vector-add-si.bin', suggesting to use
# clCreateProgramWithBinary instead. The vector addition should happen
# successfully on the Southern Islands emulator.


cp $M2S_TEST_PATH/si-asm-vector-add/vector-add.c .
cp $M2S_TEST_PATH/si-asm-vector-add/vector-add.cl .
cp $M2S_TEST_PATH/si-asm-vector-add/vector-add.bin .

gcc vector-add.c -o vector-add \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs \
	-lm2s-opencl \
	-m32

M2S_OPENCL_BINARY=vector-add.bin \
	$M2S --si-sim functional --si-debug-isa isa_trace vector-add vector-add.bin \
	> /dev/null 2>/dev/null
echo $?
cat isa_trace
rm isa_trace vector-add*
