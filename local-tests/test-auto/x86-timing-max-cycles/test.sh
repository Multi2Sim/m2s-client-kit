#!/bin/bash

# Run test
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed \
	--x86-max-cycles 100 \
	test-args 
rm test-args
