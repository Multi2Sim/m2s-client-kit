#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

cat > x86-config << EOF
[ General ]
Cores = 4
EOF

cp $M2S_CLIENT_KIT_BUILD_PATH/samples/x86/test-threads .

$M2S \
	--x86-sim detailed \
	--trace trace.gz \
	--x86-config x86-config \
	test-threads 4

$M2S --visual trace.gz

# Remove created files and finish
rm -f test-threads
rm -f trace.gz 
rm -f x86-config

