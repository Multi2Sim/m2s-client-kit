#!/bin/bash

# The test checks the stand alone network works without a problem.
# it produces a report that should follow a certain format. It also
# tests options --net-max-cycles and --net-msg-size 
net_name=net0
$M2S --net-sim $net_name --net-config net-config \
	--net-visual visual
echo $?
cat $net_name\_visual
rm $net_name\_visual
