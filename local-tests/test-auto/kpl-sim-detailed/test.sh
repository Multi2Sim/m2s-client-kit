#!/bin/bash

# Run test
cp $M2S_TEST_PATH/kpl-emu-vectoradd/vectoradd_m2s .
$M2S --kpl-sim detailed vectoradd_m2s
rm -r vectoradd_m2s 
