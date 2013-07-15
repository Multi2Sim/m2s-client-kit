#!/bin/bash


# The purpose of this tests is checking option --si-report for the Southern
# Islands timing simulator. The program run is the same as for test
# 'si-timing-vector-add'.


M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S_CLIENT_KIT_TEST_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-auto"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

cp $M2S_CLIENT_KIT_TEST_PATH/si-asm-vector-add/vector-add.c .
cp $M2S_CLIENT_KIT_TEST_PATH/si-asm-vector-add/vector-add.cl .
cp $M2S_CLIENT_KIT_TEST_PATH/si-asm-vector-add/vector-add.bin .
gcc vector-add.c -o vector-add -m32 \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
	M2S_OPENCL_BINARY=vector-add.bin \
	$M2S --si-sim detailed \
	--si-report si-report \
	vector-add vector-add.cl \
	>/dev/null 2>/dev/null
echo $?
cat si-report
rm -f vector-add vector-add.c vector-add.cl vector-add.bin
rm -f si-report
