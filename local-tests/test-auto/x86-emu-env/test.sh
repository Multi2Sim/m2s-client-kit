#!/bin/bash

# This test checks that the environment variables are passed correctly to the
# guest application, both when they are inherited from the parent program, and
# when they're passed through the --ctx-config option.

# Build program
gcc env.c -o env -m32 || exit

# Test inherited variable
M2S_TEST_VARIABLE="M2S_TEST_VALUE" $M2S env M2S_TEST_VARIABLE

# Test variable passed through --ctx-config
cat > ctx-config << EOF
[ Context 0 ]
Env = 'M2S_VAR1=M2S_VALUE1' 'M2S_VAR2=M2S_VALUE2'
Exe = env
Args = M2S_VAR1
EOF
$M2S --ctx-config ctx-config

cat > ctx-config << EOF
[ Context 0 ]
Env = 'M2S_VAR1=M2S_VALUE1' 'M2S_VAR2=M2S_VALUE2'
Exe = env
Args = M2S_VAR2
EOF
$M2S --ctx-config ctx-config

# Remove temporary files
rm -f env ctx-config

