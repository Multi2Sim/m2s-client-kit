#!/bin/bash

# Run test
nvcc -arch sm_35 -m32 -I. -c vec_con.cu -Xcicc -O0 -Xptxas -O0 -o vec_con.o
g++ -o vec_con -m32 vec_con.o -L/usr/local/lib/ -lm2s-cuda
$M2S --kpl-sim functional vec_con
echo $?
rm -f vec_con.o vec_con

