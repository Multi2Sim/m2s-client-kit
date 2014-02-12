#!/bin/bash

# The purpose of this test is checking the right behavior of the call-back
# (virtual) function associated with a timing simulator to create a default
# memory configuration based on the parameters for that architecture.

# Run test
for cores in `seq 1 8`
do
	for threads in 1 4
	do
		# Create configuration file
		rm -f x86-config
		echo "[ General ]" >> x86-config
		echo "Cores = $cores" >> x86-config
		echo "Threads = $threads" >> x86-config

		# Run command
		echo "*** Generating default memory configuration ***"
		echo "Cores = $cores"
		echo "Threads = $threads"
		$M2S --x86-sim detailed --x86-config x86-config \
				--mem-report mem-report \
				2>/dev/null
		echo "ErrorCode = $?"
		echo

		# List sections in mem-report
		echo "*** Sections in mem-report ***"
		grep "^\[" mem-report
		echo
	done
done

rm -f x86-config mem-report

