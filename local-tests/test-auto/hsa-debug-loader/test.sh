#!/bin/bash

# Run m2s 
cp $M2S_TEST_PATH/hsa-vector-copy/vector_copy .
cp $M2S_TEST_PATH/hsa-vector-copy/vector_copy.brig .
$M2S --hsa-debug-loader debug_loader vector_copy 1>/dev/null 2>&1
echo $?
cat debug_loader
rm -r debug_loader vector_copy*
