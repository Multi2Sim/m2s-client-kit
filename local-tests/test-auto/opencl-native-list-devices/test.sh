#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

gcc list-devices.c -o list-devices -m32 \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs ./list-devices
echo $?
rm -f list-devices

