#!/bin/bash

# Run test
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed --mem-debug debug test-args 1>/dev/null 2>&1
echo $?
cat debug
rm -r test-args debug
