#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S_CLIENT_KIT_TEST_AUTO_PATH="$M2S_CLIENT_KIT_PATH/local-tests/test-auto"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

cat > evg-config << EOF
[ Device ]
NumComputeUnits = 4
EOF

name="matrix-mul"
cp $M2S_CLIENT_KIT_TEST_AUTO_PATH/evg-emu-matrix-mul/$name.bin .
cp $M2S_CLIENT_KIT_TEST_AUTO_PATH/evg-emu-matrix-mul/$name.c .

gcc $name.c -o $name \
	-I$M2S_CLIENT_KIT_BUILD_PATH/runtime/include \
	-L$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
	-lm2s-opencl-old \
	-m32


LD_LIBRARY_PATH=$M2S_CLIENT_KIT_BUILD_PATH/lib/.libs \
$M2S \
	--evg-sim detailed \
	--evg-config evg-config \
	--evg-kernel-binary $name.bin \
	--trace trace.gz \
	$name 40 10

$M2S --visual trace.gz

# Remove created files and finish
rm -f $name $name.c $name.bin trace.gz evg-config

