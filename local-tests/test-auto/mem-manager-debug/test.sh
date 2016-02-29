#!/bin/bash

# Run m2s 
$M2S --mem-manager-debug debug hist -v 1>/dev/null 2>&1
echo $?
cat debug
rm debug


