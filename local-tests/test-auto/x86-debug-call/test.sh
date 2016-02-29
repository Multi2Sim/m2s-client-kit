#!/bin/bash

# Run test to check whether multi2sim creates the debug output for the
# system calls used in the application
gcc hello.c -o hello -m32 || exit
$M2S --x86-debug-call stdout hello
echo $?
rm hello
