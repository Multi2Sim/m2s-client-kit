#!/bin/bash

gcc list-devices.c -o list-devices -m32 \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_BUILD_PATH/lib/.libs ./list-devices
echo $?
rm -f list-devices

