#!/bin/bash

# Run test to check the capability of --esim-debug in m2s
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed --esim-debug esim test-args \
		1>/dev/null 2>&1
echo $?
cat esim
rm -r test-args esim 
