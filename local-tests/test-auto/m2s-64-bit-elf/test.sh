#!/bin/bash

# This test run command 'm2s' without any arguments. It is aimed at making sure
# that initialization and finalization routines work correctly when no action is
# requested from the simulator.
#
# The output should be formed of three lines of INI file comments dumped in
# stderr, containing information about the simulator version and last compilation
# time.

# Run test
$M2S hello
echo $?

