#!/bin/bash

# Run test
NAME="code"

llvm-as-3.1 $NAME.ll -o $NAME.llvm
$M2C --llvm2si $NAME.llvm
cat $NAME.s
echo $?
rm $NAME.llvm
rm $NAME.s

