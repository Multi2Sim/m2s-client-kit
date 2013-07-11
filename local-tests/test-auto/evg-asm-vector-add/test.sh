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


M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

$M2S --evg-disasm vector-add.bin
echo $?

