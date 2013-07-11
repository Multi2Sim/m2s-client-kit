#!/bin/bash

# This test run command 'm2s' without any arguments. It is aimed at making sure
# that initialization and finalization routines work correctly when no action is
# requested from the simulator.
#
# The output should be formed of three lines of INI file comments dumped in
# stderr, containing information about the simulator version and last compilation
# time.

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2s"

# Run test
$M2S
echo $?

