#!/bin/bash

# Run test
$M2S cppIntegration
echo $?
rm -f cppIntegration.cu.cubin
