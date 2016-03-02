#!/bin/bash

# The test checks the stand alone network works without a problem. 
$M2S --net-sim net0 --net-config net-config --trace trace.gz
zcat trace.gz
echo $?
rm trace.gz
