#!/bin/bash

# Run test
$M2S --kpl-sim functional vectoradd_m2s
echo $?
rm -f vectorAdd.cu.cubin
