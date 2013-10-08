#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2C="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2c"

# Run test
NAME="code"

llvm-as-3.1 $NAME.ll -o $NAME.llvm
$M2C --llvm2si $NAME.llvm
cat $NAME.s
echo $?
rm $NAME.llvm
rm $NAME.s

