#!/bin/bash


# The purpose of this tests is checking option M2S_OPENCL_DEBUG for the 
# native execution of an opencl application, using the m2s-opencl library.
# program run is the same as for the test 
# 'opencl-native-clCreateProgramWithSource'.

cp $M2S_TEST_PATH/cuda-debug/vectoradd_m2s .
LD_LIBRARY_PATH=$M2S_BUILD_PATH/lib/.libs\
	$M2S --ctx-config ctx-config --cuda-debug debug_file \
		1>/dev/null 2>&1
cat debug_file
rm -r vectoradd_m2s debug_file
