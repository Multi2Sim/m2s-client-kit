#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TAGS_URL="http://multi2sim.org/svn/multi2sim/tags"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_RESULT_PATH="$M2S_CLIENT_KIT_PATH/result"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
build_m2s_local_sh="$HOME/$M2S_CLIENT_KIT_BIN_PATH/build-m2s-local.sh"
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
    $prog_name [<options>] <machine>[:<port>] ...

Build Multi2Sim on several target machines with the following options:

  * Build of development version using autotools (liboolize, aclocal,
    autoconf, automake, configure, make).
  * Build of distribution package (tar, configure, make).

Both for the development version and the distribution package, the following
configuration scenarios are tested:

  * Default configuration, no flags for ./configure script.
  * ./configure script with flags '--enable-debug'.
  * ./configure script with flags '--enable-debug --disable-gtk'.
  * ./configure script with flags '--enable-debug --disable-glut'.
  * ./configure with flags '--disable-gtk'.
  * ./configure with flags '--disable-glut'.
  * ./configure with flags '--disable-flex-bison'.


Options:

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



# Test build of development and distribution package in remote machines.

# Input variables
#	$dist_package_name
#	$dist_package_path
#	$dist_version
#	$dev_package_path
#	$log_file

# Arguments
#	$1 - $server_port

function test_build()
{
	local server_port=$1
	local server
	local port

	# Split server and port
	server=$(echo $server_port | awk -F: '{ print $1 }')
	port=$(echo $server_port | awk -F: '{ print $2 }')
	[ -n "$port" ] || port=22

	# Get distribution package version
	version=`$inifile_py $HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-bin/build.ini \
		read Build Version`
	[ -n "$version" ] || error "cannot obtain distribution package version"

	# Copy distribution and development packages
	echo "Machine $server (port $port)"
	scp -P $port -q \
		$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-bin/multi2sim.tar.gz \
		$HOME/$M2S_CLIENT_KIT_TMP_PATH/m2s-bin/multi2sim-$version.tar.gz \
		$server: \
		>> $log_file 2>&1 \
		|| error "failed sending packages to $server"
	
	# Log file
	echo -e "\n*\n* Machine '$server'\n*\n" >> $log_file
	echo ">>> test-build machine $server" >> $log_file
	
	# Connect to server
	ssh -p $port $server '
	
		# Test development version build
		#   $1 - Test name
		#   $2 [$3 ...] - Configure flags
		function test_dev_build()
		{	
			local test_name=$1
			shift
			local configure_args="$*"

			# Info
			echo ">>> test-build begin $test_name"

			# Build test
			# NOTE: Line below creating directory "m4" is used to
			# overcome bugs in older Autotools. Not needed for
			# newer.
			cd $temp_dir 2>&1 && \
				rm -rf $dev_dir 2>&1 && \
				tar -xzf $dev_package_path 2>&1 && \
				cd $dev_dir 2>&1 && \
				libtoolize 2>&1 && \
				aclocal 2>&1 && \
				autoconf 2>&1 && \
				automake --add-missing 2>&1 && \
				mkdir -p m4 && \
				./configure $configure_args 2>&1 && \
				make 2>&1

			# Diagnose
			if [ $? == 0 ]
			then
				echo ">>> test-build passed $test_name"
			else
				echo ">>> test-build failed $test_name"
			fi
			echo ">>> test-build end $test_name"
		}

		# Test distribution version build
		#   $1 - Test name
		#   $2 [$3 ...] - Configure flags
		function test_dist_build()
		{
			local test_name=$1
			shift
			local configure_args="$*"

			# Info
			echo ">>> test-build begin $test_name"

			# Build test
			cd $temp_dir 2>&1 && \
				rm -rf $dist_dir 2>&1 && \
				tar -xzf $dist_package_path 2>&1 && \
				cd $dist_dir 2>&1 && \
				./configure $configure_args 2>&1 && \
				make 2>&1

			# Diagnose
			if [ $? == 0 ]
			then
				echo ">>> test-build passed $test_name"
			else
				echo ">>> test-build failed $test_name"
			fi
			echo ">>> test-build end $test_name"
		}
	
		# Copy packages to temporary directory
		temp_dir=`mktemp -d`
		version="'$version'"
		mv multi2sim.tar.gz $temp_dir || exit 1
		mv multi2sim-$version.tar.gz $temp_dir || exit 1
		dev_package_path="$temp_dir/multi2sim.tar.gz"
		dist_package_path="$temp_dir/multi2sim-$version.tar.gz"
		dev_dir="$temp_dir/multi2sim"
		dist_dir="$temp_dir/multi2sim-$version"
		cd $temp_dir || exit 1

		# Extract packages
		tar -xzf $dev_package_path
		tar -xzf $dist_package_path

		# Tests on development package
		test_dev_build dev-default
		test_dev_build dev-debug --enable-debug
		test_dev_build dev-debug-no-gtk --enable-debug --disable-gtk
		test_dev_build dev-debug-no-glut --enable-debug --disable-glut
		test_dev_build dev-no-gtk --disable-gtk
		test_dev_build dev-no-glut --disable-glut
		test_dev_build dev-no-flex-bison --disable-flex-bison

		# Tests on distribution package
		test_dist_build dist-default
		test_dist_build dist-debug --enable-debug
		test_dist_build dist-debug-no-gtk --enable-debug --disable-gtk
		test_dist_build dist-debug-no-glut --enable-debug --disable-glut
		test_dist_build dist-no-gtk --disable-gtk
		test_dist_build dist-no-glut --disable-glut
		test_dist_build dist-no-flex-bison --disable-flex-bison

		# Remove temporary directory
		rm -rf $temp_dir
	' >> $log_file 2>&1
}


function test_build_check()
{
	# Remove existing results directory
	result_path="$HOME/$M2S_CLIENT_KIT_RESULT_PATH/test-build"
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
	
	# Dump info
	echo "Report dumped in $result_path/report.html"
}
	


#
# Main Script
#

# Options
temp=`getopt -o r: -l tag: -n $prog_name -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi
eval set -- "$temp"
rev=
rev_arg=
tag=
tag_arg=
while true ; do
	case "$1" in
	-r) rev=$2 ; rev_arg="-r $2" ; shift 2 ;;
	--tag) tag=$2 ; tag_arg="--tag $2" ; shift 2 ;;
	--) shift ; break ;;
	*) echo "$1: invalid option" ; exit 1 ;;
	esac
done

# Arguments
[ $# -gt 0 ] || syntax
server_port_list="$*"

# Reset log file
log_file="$HOME/$M2S_CLIENT_KIT_TMP_PATH/test-build.log"
rm -f $log_file

# Try to connect to all machines
echo "Checking connectivity to servers..."
for server_port in $server_port_list
do
	# Server and port
	server=$(echo $server_port | awk -F: '{ print $1 }')
	port=$(echo $server_port | awk -F: '{ print $2 }')
	[ -n "$port" ] || port=22

	# Check connection with timeout of 10 seconds, and no password
	echo -n "$server (port $port)"
	ssh $server -p $port -o "ConnectTimeout=10" -o "PasswordAuthentication=no" \
		'echo " - ok"' 2>$log_file \
		|| error "failed to connect to $server"
done
echo

# Get Multi2Sim local copy
$build_m2s_local_sh $rev_arg $tag_arg
echo

# Test build on every machine
echo "Running build tests..."
for server_port in $server_port_list
do
	test_build $server_port
done
echo

# Plot result
test_build_check

# End
rm -rf $temp_dir
exit 0

