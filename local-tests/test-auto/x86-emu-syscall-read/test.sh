#!/bin/bash

# Run test
gcc read.c -o read -m32 -pthread || exit
$M2S read
echo $?
rm -f read

