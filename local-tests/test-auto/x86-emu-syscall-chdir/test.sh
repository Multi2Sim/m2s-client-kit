#!/bin/bash

# Run test
gcc chdir.c -o chdir -m32 || exit
mkdir subdir
sim_chdir=`$M2S chdir`
real_chdir=`pwd && cd subdir && pwd && cd .. && pwd`
if [ "$sim_chdir" == "$real_chdir" ]
then
	echo "Output matches"
fi
rmdir subdir
rm -f chdir
