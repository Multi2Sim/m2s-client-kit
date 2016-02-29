#!/bin/bash

# Run test
gcc hello.s -o hello -m32 -nostdlib || exit
$M2S --x86-debug-isa debug hello
echo $?
cat debug
rm hello debug

