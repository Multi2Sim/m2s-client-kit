#!/bin/bash

# Run test
gcc sigprocmask.c -o sigprocmask -m32 -pthread || exit
$M2S sigprocmask
echo $?
rm sigprocmask

