#!/bin/bash

# Run m2s 
cp $M2S_TEST_PATH/hsa-vector-copy/vector_copy .
cp $M2S_TEST_PATH/hsa-vector-copy/vector_copy.brig .
$M2S --hsa-debug-isa debug_isa vector_copy 1>/dev/null 2>&1
echo $?
cat debug_isa
rm -r debug_isa vector_copy*
