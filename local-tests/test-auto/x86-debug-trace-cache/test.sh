#!/bin/bash

# Run test
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed \
	--x86-config x86-config \
	--x86-debug-trace-cache debug \
	test-args \
	>/dev/null 2>&1
echo $?
cat debug
rm debug test-args
