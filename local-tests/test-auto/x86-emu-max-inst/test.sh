#!/bin/bash

# Run test
cp ../x86-asm/hello.s .
gcc hello.s -o hello -m32 -nostdlib || exit
$M2S --x86-max-inst 4 hello 2>&1 | grep "\<Instructions\>"
echo $?
rm hello hello.s

