#!/bin/bash

# Run test
gcc nanosleep.c -o nanosleep -m32 || exit
$M2S nanosleep 2>stats
echo $?

# Check statistics
python << EOF
import ConfigParser
config = ConfigParser.SafeConfigParser()
config.read('stats')

time = config.get(' General ', 'RealTime')
time = float(time.split()[0])
if time >= 2:
	print 'Time is >= 2 seconds'
EOF

# Remove temporary files
rm -f nanosleep stats

