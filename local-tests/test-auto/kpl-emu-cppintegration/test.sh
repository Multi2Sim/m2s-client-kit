#!/bin/bash

# Run test
$M2S --kpl-sim functional cppIntegration_m2s
echo $?
rm -f vec_con.o cppIntegration.cu.cubin
