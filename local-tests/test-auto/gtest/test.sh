#!/bin/bash

# Run test
cd $M2S_BUILD_PATH
make check > /dev/null 2>&1
echo $?
