#!/bin/bash

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIRECTORY=$(dirname "$SCRIPT_PATH")

M2S_CLIENT_KIT_PATH=$(readlink -f "$SCRIPT_DIRECTORY/../../..")
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S_CLIENT_KIT_TEST_AUTO_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-auto"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

cat > si-config << EOF
[ Device ]
NumComputeUnits = 4
EOF

name="matrix-mul"
cp $M2S_CLIENT_KIT_TEST_AUTO_PATH/si-emu-matrix-mul/$name.bin .
cp $M2S_CLIENT_KIT_TEST_AUTO_PATH/si-emu-matrix-mul/$name.c .

gcc $name.c -o $name \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
	-lm2s-opencl \
	-m32


LD_LIBRARY_PATH=$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
	M2S_OPENCL_BINARY=$name.bin \
	$M2S \
	--si-sim detailed \
	--si-config si-config \
	--trace trace.gz \
	$name 40 10

$M2S --visual trace.gz

# Remove created files and finish
rm -f $name $name.c $name.bin trace.gz si-config

