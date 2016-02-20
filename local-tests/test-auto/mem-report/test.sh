#!/bin/bash

# Run test
gcc test-args.c -o test-args -m32 || exit
$M2S --x86-sim detailed --mem-report report test-args 1>/dev/null 2>&1
echo $?
cat report
rm -r test-args report
