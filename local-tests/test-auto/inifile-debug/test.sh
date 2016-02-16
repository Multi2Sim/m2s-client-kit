#!/bin/bash

# Run test to check the capability of --esim-debug in m2s
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim functional --inifile-debug debug --ctx-config ctx-config.ini \
		1>/dev/null 2>&1
echo $?
cat debug
rm -r test-args debug
