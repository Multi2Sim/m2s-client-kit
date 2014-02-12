#!/bin/bash

# Run test
cp $M2S_BUILD_PATH/samples/fermi/vectorAdd/vectorAdd .
cp $M2S_BUILD_PATH/samples/fermi/vectorAdd/vectorAdd.cubin .
$M2S vectorAdd
echo $?
rm -f vectorAdd vectorAdd.cubin

