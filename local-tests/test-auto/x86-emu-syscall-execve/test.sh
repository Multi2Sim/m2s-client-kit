#!/bin/bash

# Run test
gcc execve.c -o execve -m32 || exit
$M2S execve
echo $?
rm execve

