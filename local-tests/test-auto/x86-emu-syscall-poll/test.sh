#!/bin/bash

# Run test
gcc poll.c -o poll -m32 -pthread || exit
$M2S poll
echo $?
rm -f poll

