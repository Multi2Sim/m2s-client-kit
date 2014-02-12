#!/bin/bash


name="matrix-mul"

gcc $name.c -o $name \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs \
	-lm2s-opencl \
	-m32

M2S_OPENCL_BINARY=$name.bin \
	$M2S $name 50 10

rm -f $name
