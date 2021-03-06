#!/bin/bash

# Configuration
cat > x86-config << EOF
[ General ]
Threads = 4

[ Queues ]
LsqKind = Private
EOF

# Run
cp $M2S_BUILD_PATH/samples/x86/example-4/test-threads . || exit 1
$M2S \
	--x86-sim detailed \
	--x86-config x86-config \
	test-threads 10
echo $?
rm test-threads x86-config

