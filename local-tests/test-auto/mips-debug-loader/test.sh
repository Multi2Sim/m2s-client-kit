#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/mips/test-args .
$M2S --mips-debug-loader debug_file test-args a b c 1>/dev/null 2>&1
echo $?
cat debug_file
rm test-args debug_file
