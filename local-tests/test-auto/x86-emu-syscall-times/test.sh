#!/bin/bash

# Run test
gcc times.c -o times -m32 || exit
$M2S times
echo $?
rm times

