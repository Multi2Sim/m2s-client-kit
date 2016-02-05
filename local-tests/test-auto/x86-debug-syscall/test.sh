#!/bin/bash

# Run test
gcc hello.c -o hello -m32 -static || exit
$M2S --x86-debug-syscall stdout hello
echo $?
rm hello
