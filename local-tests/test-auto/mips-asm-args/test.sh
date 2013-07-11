#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

# Run test
cp $M2S_CLIENT_KIT_BUILD_PATH/samples/mips/test-args .
$M2S --mips-disasm test-args
echo $?
rm -f test-args
