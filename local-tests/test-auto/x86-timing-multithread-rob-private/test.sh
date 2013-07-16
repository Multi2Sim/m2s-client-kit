#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

# Configuration
cat > x86-config << EOF
[ General ]
Threads = 4

[ Queues ]
RobKind = Private
EOF

# Run
cp $M2S_CLIENT_KIT_BUILD_PATH/samples/x86/test-threads . || exit 1
$M2S \
	--x86-sim detailed \
	--x86-config x86-config \
	test-threads 10
echo $?
rm test-threads x86-config

