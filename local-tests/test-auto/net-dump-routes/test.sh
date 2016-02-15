#!/bin/bash

# The test checks the stand alone network works without a problem.
network=net0
$M2S --net-sim $network --net-config net-config --net-dump-routes routes
echo $?
cat $network\_routes
rm $network\_routes

