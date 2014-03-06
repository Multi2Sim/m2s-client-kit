#!/bin/bash

# Run test
gcc math.c -o math -m32 -lm || exit
$M2S math
echo $?
rm math

