#!/bin/bash


# The purpose of this tests is checking option M2S_OPENCL_DEBUG for the 
# native execution of an opencl application, using the m2s-opencl library.
# program run is the same as for the test 
# 'opencl-native-clCreateProgramWithSource'.


cp $M2S_TEST_PATH/opencl-native-clCreateProgramWithSource/vector-add.c .
cp $M2S_TEST_PATH/opencl-native-clCreateProgramWithSource/vector-add.cl .
cp $M2S_TEST_PATH/opencl-native-clCreateProgramWithSource/vector-add-x86.bin .
gcc vector-add.c -o vector-add -m32 \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs -lm2s-opencl
LD_LIBRARY_PATH=$M2S_BUILD_PATH/lib/.libs \
	M2S_OPENCL_BINARY=vector-add-x86.bin \
	M2S_OPENCL_DEBUG=debug_file \
	./vector-add vector-add.cl >/dev/null 2>/dev/null
cat debug_file
rm -f vector-add* debug_file
