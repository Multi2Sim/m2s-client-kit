#!/bin/bash


# A program linked dynamically with 'libm2s-opencl.so' loads a GPU device,
# then tries to load a Southern Islands program binary using
# clCreateProgramWithSource and environment variable M2S_OPENCL_BINARY.
# 
# The program should show a warning about 'libm2s-opencl.so' being redirected to a
# library path relative to the 'm2s' executable. Another warning should be shown
# when the program successfully loads 'vector-add-si.bin', suggesting to use
# clCreateProgramWithBinary instead. The vector addition should happen
# successfully on the Southern Islands emulator.


$M2S --si-disasm vector-add.bin
echo $?

