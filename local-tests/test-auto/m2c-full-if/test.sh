#!/bin/bash

# Run test
name="if"

rm -f $name $name.bin

gcc $name.c \
	-L$M2S_BUILD_PATH/lib/.libs \
	-I$M2S_BUILD_PATH/runtime/include \
	-lm2s-opencl -m32 -o $name \
	|| exit 1

$M2C $name.cl
echo $?

m2s $name $name.bin
echo $?

rm -f $name $name.bin

