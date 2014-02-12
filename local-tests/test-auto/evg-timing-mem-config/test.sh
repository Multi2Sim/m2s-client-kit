#!/bin/bash

# The purpose of this test is checking the right behavior of the call-back
# (virtual) function associated with a timing simulator to create a default
# memory configuration based on the parameters for that architecture.

# Run test
for cus in 1 2 3 4 5 6 7 8 9 10 15 20 25 30 40 50 64
do
	# Create configuration file
	rm -f evg-config
	echo "[ Device ]" >> evg-config
	echo "NumComputeUnits = $cus" >> evg-config

	# Run command
	echo "*** Generating default memory configuration ***"
	echo "NumComputeUnits = $cus"
	$M2S --evg-sim detailed --evg-config evg-config \
			--mem-report mem-report \
			2>/dev/null
	echo "ErrorCode = $?"
	echo

	# List sections in mem-report
	echo "*** Sections in mem-report ***"
	grep "^\[" mem-report
	echo
done

rm -f evg-config mem-report

