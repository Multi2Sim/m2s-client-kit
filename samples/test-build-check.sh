#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TAGS_URL="http://multi2sim.org/svn/multi2sim/tags"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
prog_name=$(echo $0 | awk -F/ '{ print $NF }')


#
# Syntax
#

function error()
{
	echo -e "\nerror: $1 (see log in $log_file)\n" >&2
	exit 1
}


function syntax()
{
	cat << EOF

Syntax:
    $prog_name [<options>] <server>[:<port>]

Build Multi2Sim on several target machines with the following options:

  * Build of development version using autotools (aclocal, autoconf, automake,
    configure, make).
  * Build of distribution package (tar, configure, make).

Both for the development version and the distribution package, the following
configuration scenarios are tested:

  * Default scenario, no flags for ./configure script.
  * Flag '--enable-debug' in ./configure script.

Possible options are:

  -r <rev>
  	Multi2Sim revision to fetch and build. If none is specified, the latest
	available SVN revision on the server is fetched.

  --tag <tag>
  	Fetch subdirectory <tag> in the 'tags' directory on the Multi2Sim
	repository. If none is specified, the 'trunk' directory is fetched
	instead.

EOF
	exit 1
}




#
# Main Script
#

# Log file
log_file="$HOME/$M2S_CLIENT_KIT_TMP_PATH/test-build.log"
result_path="$HOME/$M2S_CLIENT_KIT_RESULT_PATH/test-build"


#
# Analyze the log
#

# Remove existing results directory
rm -rf $result_path
mkdir -p $result_path

# Process log
awk '
BEGIN {
	dump_file = "";

	machine = "";
	machine_count = 0;

	test = "";
	test_count = 0;
}
{
	if ($1 == ">>>" && $2 == "test-build")
	{
		# Token
		if ($3 == "machine")
		{
			machine = $4;
			if (!(machine in machine_hash))
			{
				machine_hash[machine] = 1;
				machine_list[machine_count] = machine;
				machine_count++;
			}
		}
		else if ($3 == "begin")
		{
			test = $4;
			if (!(test in test_hash))
			{
				test_hash[test] = 1;
				test_list[test_count] = test;
				test_count++;
			}
		}
		else if ($3 == "passed" || $3 == "failed")
		{
			test_result[machine "_" test] = $3
		}
		else if ($3 == "end")
		{
			test = "";
		}


		# Update file to dump log
		if (machine != "" && test != "")
			dump_file = "'$result_path'/log_" machine "_" test;
		else
			dump_file = "";
	}
	else
	{
		if (dump_file != "")
			print $0 >> dump_file
	}
}
END {
	
	# Create HTML document
	html_file = "'$result_path'/report.html"
	print "<html><body>" >> html_file
	print "<h1>Report for Multi2Sim Builds</h1>" >> html_file

	# Create table
	print "<table border=1>" >> html_file

	# First row
	print "<td></td>" >> html_file
	for (j = 0; j < test_count; j++)
	{
		test = test_list[j];
		print "<td>" test "</td>" >> html_file
	}

	# Body of table - one row per machine
	for (i = 0; i < machine_count; i++)
	{
		# New row
		machine = machine_list[i];
		print "<tr>" >> html_file

		# First column
		print "<td>" machine "</td>" >> html_file

		# One column per test
		for (j = 0; j < test_count; j++)
		{
			# New column
			test = test_list[j];
			print "<td>" >> html_file

			# Contents
			result = test_result[machine "_" test]
			if (result == "passed")
				print "OK" >> html_file
			else if (result == "failed")
			{
				print "<font color=\"red\">Failed</font>" >> html_file
				print "<a href=\"'$result_path'/log_" machine "_" test "\">Log</a>" >> html_file
			}

			# End of column
			print "</td>" >> html_file
		}

		# End of row
		print "<tr>" >> html_file
	}

	# End table
	print "</table" >> html_file
}
' $log_file



