#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2C="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2c"

# Run test
name="for"

gcc $name.c \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-lm2s-opencl -m32 -o $name \
	|| exit 1

$M2C $name.cl
echo $?

m2s $name $name.bin
echo $?

rm -f $name $name.clp $name.llvm $name.s $name.bin

