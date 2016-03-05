#!/bin/bash

# Run test
gcc sched.c -o sched -m32 || exit
$M2S --x86-sim detailed --x86-config x86-config --x86-report x86-report sched

# Dump all entries starting with "Commit.Total" in x86 report
grep "^Commit\.Total = " x86-report

# Dump return value
echo $?

# Remove temporary files
rm -f sched x86-report

