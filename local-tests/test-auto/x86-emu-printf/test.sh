#!/bin/bash

# Run test
gcc printf.c -o printf -m32 2>/dev/null || exit
$M2S printf
echo $?
rm printf

