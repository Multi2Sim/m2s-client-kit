#!/bin/bash

# Run m2s to disassemble the brig file
$M2S --hsa-disasm target.brig > result.hsail

# At last, compare the difference between the result and the target
diff target.hsail result.hsail
