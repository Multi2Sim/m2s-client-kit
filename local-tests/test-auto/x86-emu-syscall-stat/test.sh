#!/bin/bash

# Run test
gcc stat.c -o stat -m32 || exit
$M2S stat
echo $?
rm stat

