#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/arm/test-args .
$M2S --arm-disasm test-args
echo $?
rm test-args

