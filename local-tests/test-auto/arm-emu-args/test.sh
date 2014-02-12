#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/arm/test-args .
$M2S test-args a b c
echo $?
rm test-args
