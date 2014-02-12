#!/bin/bash

# Run test
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed \
	--x86-report x86-report \
	test-args \
	>/dev/null 2>/dev/null
echo $?
cat x86-report
rm test-args
rm x86-report

