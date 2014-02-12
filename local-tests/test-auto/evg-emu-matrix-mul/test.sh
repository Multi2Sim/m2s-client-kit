#!/bin/bash


name="matrix-mul"

gcc $name.c -o $name \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs \
	-lm2s-opencl-old \
	-m32

$M2S \
	--evg-kernel-binary $name.bin \
	$name 50 10

rm -f $name
