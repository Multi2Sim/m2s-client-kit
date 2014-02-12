#!/bin/bash


# The purpose of this test is checking option --evg-report <file> for the
# Evergreen timing simulator. The commands are the same as test
# evg-timing-vector-add, but adding the extra option.


cp $M2S_TEST_PATH/evg-asm-vector-add/vector-add.c .
cp $M2S_TEST_PATH/evg-asm-vector-add/vector-add.cl .
cp $M2S_TEST_PATH/evg-asm-vector-add/vector-add.bin .
gcc vector-add.c -o vector-add -m32 \
	-I$M2S_BUILD_PATH/runtime/include \
	-L$M2S_BUILD_PATH/lib/.libs -lm2s-opencl-old
LD_LIBRARY_PATH=$M2S_BUILD_PATH/lib/.libs \
	$M2S --evg-kernel-binary vector-add.bin \
		--evg-sim detailed \
		--evg-report evg-report \
	vector-add vector-add.cl > /dev/null 2>/dev/null
echo $?
cat evg-report
rm -f vector-add vector-add.c vector-add.cl vector-add.bin
rm -f evg-report
