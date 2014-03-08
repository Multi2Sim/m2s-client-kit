#!/bin/bash

# Run test
gcc cwd.c -o cwd -m32 || exit
sim_cwd=`$M2S cwd`
real_cwd=`pwd`
if [ "$sim_cwd" == "$real_cwd" ]
then
	echo "Paths match"
fi
rm -f cwd
