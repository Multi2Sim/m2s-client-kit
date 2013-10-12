#!/bin/bash

M2S_CLIENT_KIT_PATH="$HOME/m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2C="$M2S_CLIENT_KIT_BUILD_PATH/bin/m2c"

$M2C --tree-config tree-config --tree-debug stdout
echo $?

