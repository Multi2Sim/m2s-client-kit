#!/bin/bash

gcc list-devices.c -o list-devices -m32 \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs -lm2s-opencl
$M2S list-devices
echo $?
rm -f list-devices

