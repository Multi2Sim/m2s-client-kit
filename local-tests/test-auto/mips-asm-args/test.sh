#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/mips/test-args .
$M2S --mips-disasm test-args
echo $?
rm -f test-args
