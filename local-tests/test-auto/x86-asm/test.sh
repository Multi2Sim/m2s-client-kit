#!/bin/bash

# Run test
gcc hello.s -o hello -m32 -nostdlib || exit
$M2S --x86-disasm hello
echo $?
rm hello

