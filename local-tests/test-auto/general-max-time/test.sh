#!/bin/bash

# Run test to check the capability of --esim-debug in m2s
cp $M2S_BUILD_PATH/samples/x86/example-4/test-threads . || exit 1
$M2S --x86-sim detailed --max-time 2 \
		test-threads 100 
rm -r test-threads
