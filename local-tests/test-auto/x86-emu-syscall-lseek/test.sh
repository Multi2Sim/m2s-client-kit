#!/bin/bash

# Run test
gcc lseek.c -o lseek -m32 || exit
$M2S lseek
echo $?
rm lseek

