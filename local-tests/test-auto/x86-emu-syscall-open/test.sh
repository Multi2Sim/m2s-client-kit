#!/bin/bash

# Run test
gcc open.c -o open -m32 || exit
$M2S open
echo $?

# Remove temporary files
rm -f open

