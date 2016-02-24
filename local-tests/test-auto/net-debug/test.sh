#!/bin/bash

# The test checks the stand alone network works without a problem.
$M2S --net-sim net0 --net-config net-config --net-debug debug \
		--net-injection-rate 10 \
		--net-max-cycles 1000 \
		 1>/dev/null 2>&1
echo $?
cat debug
rm -f debug
