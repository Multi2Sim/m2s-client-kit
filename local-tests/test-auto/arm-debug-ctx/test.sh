#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/arm/test-args .
$M2S --arm-debug-ctx debug --ctx-config ctx-config \
	1>/dev/null 2>&1 
echo $?
cat debug
rm test-args debug
