#!/bin/bash

# Run test
gcc kill.c -o kill -m32 -pthread || exit
$M2S kill
echo $?
rm kill

