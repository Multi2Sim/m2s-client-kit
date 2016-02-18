#!/bin/bash

# Run test
cp $M2S_TEST_PATH/kpl-emu-vectoradd/vectoradd_m2s .
$M2S --kpl-debug-isa debug vectoradd_m2s 1>/dev/null 2>&2
echo $?
cat debug
rm -r vectoradd_m2s debug
