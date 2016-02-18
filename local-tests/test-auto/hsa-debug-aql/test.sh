#!/bin/bash

# Run m2s 
cp $M2S_TEST_PATH/hsa-vector-copy/vector_copy .
cp $M2S_TEST_PATH/hsa-vector-copy/vector_copy.brig .
$M2S --hsa-debug-aql aql vector_copy 1>/dev/null 2>&1
echo $?
cat aql
rm -r aql vector_copy*
