#!/bin/bash

# Run test to check the capability of --esim-debug in m2s
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed --x86-max-cycles 200 --trace trace.gz \
		--ctx-config ctx-config 1>/dev/null 2>&1
echo $?
gzip -d trace.gz
cat trace
rm -r test-args trace*
