#!/bin/bash

# Run test
NAME="URNG"
DEVICE="pitcairn"

$M2C --si-asm -m $DEVICE $NAME.s
echo $?
./$NAME --load $NAME.bin -e -q
echo $?
rm $NAME.bin
rm out[0-9].bmp

