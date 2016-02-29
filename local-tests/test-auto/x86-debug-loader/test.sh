#!/bin/bash

# Run test
gcc hello.s -o hello -m32 -nostdlib || exit
$M2S --x86-debug-loader debug hello
echo $?
cat debug
rm hello debug

