#!/bin/bash

# The test checks the stand alone network works without a problem. 
$M2S --net-sim net0 --net-config net-config
echo $?

