#!/bin/bash

# Run test to check the capability of --esim-debug in m2s
cp $M2S_BUILD_PATH/samples/memory/example-3/net-config . || exit 1
cp $M2S_BUILD_PATH/samples/memory/example-3/x86-config . || exit 1
cp $M2S_BUILD_PATH/samples/memory/example-3/mem-config . || exit 1

gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed --x86-max-cycles 200 --trace trace.gz \
		--x86-config x86-config \
		--mem-config mem-config --net-config net-config \
		test-args \
		>/dev/null 2>&1
echo $?
zcat trace.gz
rm -f test-args trace.gz mem-config net-config x86-config
