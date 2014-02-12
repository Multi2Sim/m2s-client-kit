#!/bin/bash

# Run test
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed test-args
echo $?
rm test-args

