#!/bin/bash

# Run test
cp ../kpl-emu-if-else/vec_con .
$M2S --kpl-sim functional vec_con
$M2S --kpl-disasm vec_con.cu.cubin
echo $?
rm -f vec_con.cu.cubin vec_con
