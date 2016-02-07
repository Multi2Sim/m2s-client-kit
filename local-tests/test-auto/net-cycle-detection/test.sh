#!/bin/bash

# The test checks the stand alone network works without a problem. The
# test should produce a cycle-detection warning since the network contains
# a cycle 
$M2S --net-sim net0 --net-config net-config
echo $?

