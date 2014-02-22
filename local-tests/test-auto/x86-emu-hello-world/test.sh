#!/bin/bash

# Run test
cp ../x86-asm/hello.s .
gcc hello.s -o hello -m32 -nostdlib || exit
$M2S hello
echo $?
rm hello hello.s

