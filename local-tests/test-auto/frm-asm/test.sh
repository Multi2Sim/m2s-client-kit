#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/fermi/vectorAdd/vectorAdd.cubin .
$M2S --frm-disasm vectorAdd.cubin
echo $?
rm -f vectorAdd.cubin

