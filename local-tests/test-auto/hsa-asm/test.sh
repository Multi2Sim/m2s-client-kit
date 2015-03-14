#!/bin/bash

#First run the official disassembler provided by HSA foundation
# ./hsailasm -assemble target_source.hsail
# mv target_source.brig target.brig
# ./hsailasm --disassemble target.brig

# Second, run m2s to disassemble the brig file
$M2S --hsa-disasm target.brig > result.hsail

# At last, compare the difference between the result and the target
diff target.hsail result.hsail
