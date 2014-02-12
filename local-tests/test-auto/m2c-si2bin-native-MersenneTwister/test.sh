#!/bin/bash

# Run test
NAME="MersenneTwister"
DEVICE="pitcairn"

$M2C --si-asm -m $DEVICE $NAME.s
echo $?
./$NAME --load $NAME.bin -e -q
echo $?
rm $NAME.bin

