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


# Obtain Multi2Sim repository for a given tag and revision.

# Input variables:
#	$tag - Tag to obtain (empty = 'trunk')
#	$rev - SVN revision (empty = latest)
#	$log_file - dump log here

# Output variables:
#	$dist_package_path - Path to distribution package
#	$dist_package_name - Name of distribution package (only file)
#	$dist_version - Version of distribution package
#	$dev_package_path - Path to development package
#	$dev_package_name - Name of distribution package (only file)
#	$temp_dir - Directory where packages were created, to be removed later

function get_m2s_package()
{

	# If revision was not given, obtain latest
	if [ -z "$rev" ]
	then
		temp=`mktemp`
		svn info $M2S_SVN_URL > $temp 2>> $log_file || error "cannot obtain SVN info"
		rev=$(sed -n "s,^Revision: ,,gp" $temp)
		rm -f $temp
	fi

	# Info
	if [ -z "$tag" ]
	then
		tag_name="trunk"
		tag_url="$M2S_SVN_TRUNK_URL"
	else
		tag_name="tag '$tag'"
		tag_url="$M2S_SVN_TAGS_URL/$tag"
	fi
	echo -n "Fetching Multi2Sim $tag_name, SVN Rev. $rev"

	# Fetch revision
	temp_dir=`mktemp -d` || exit 1
	cd $temp_dir || exit 1
	svn co $tag_url multi2sim -r $rev >/dev/null \
		|| error "cannot get local copy"
	
	# Create development package first
	dev_package_name="multi2sim-dev.tar.gz"
	dev_package_path="$temp_dir/multi2sim-dev.tar.gz"
	tar -czf $dev_package_path multi2sim \
		|| error "cannot create development package"
	
	# Run autotools locally
	echo -n " - building locally"
	cd $temp_dir/multi2sim || exit 1
	aclocal >> $log_file 2>&1 && \
	autoconf >> $log_file 2>&1 && \
	automake --add-missing >> $log_file 2>&1 && \
	./configure >> $log_file 2>&1 || \
		error "failed running autotools locally"
	
	# Create distribution package
	make dist >> $log_file 2>&1 || exit 1
	dist_package_name=`ls *.tar.gz`
	[ `echo $dist_package_name | wc -w` == 1 ] || \
		error "wrong distribution package: $dist_package_name"
	dist_package_path="$temp_dir/multi2sim/$dist_package_name"
	
	# Get distribution package version (name of unpacked directory)
	dist_version=`awk -F"[\(\), ]+" '/^AM_INIT_AUTOMAKE/ { print $3 }' configure.ac`
	[ -n "$dist_version" ] || error "invalid distribution version"
	
	# Info
	echo
}



# Check that distribution package contains all files present in development
# package. If any file is missing, it probably means that the file was not
# listed under EXTRA_DIST in Makefile.am.

# Input variables
#	$dist_package_name
#	$dist_package_path
#	$dev_package_name
#	$dev_package_path

function check_extra_dist()
{
	local local_temp_dir
	local file_list
	local missing_files

	# Info
	echo -n "Checking integrity of development package"

	# Create temporary directory
	local_temp_dir=`mktemp -d`

	# Copy packages
	cp $dist_package_path $local_temp_dir \
		&& cp $dev_package_path $local_temp_dir \
		|| exit 1

	# Extract packages
	cd $local_temp_dir
	tar -xzf $dist_package_path \
		&& tar -xzf $dev_package_path \
		|| exit 1

	# List files in development package
	cd $local_temp_dir/multi2sim || exit 1
	file_list=`find . -type f | grep -v "\.svn"`

	# Find files in distribution package
	missing_files=0
	cd $local_temp_dir/multi2sim-$dist_version || exit 1
	for file in $file_list
	do
		if [ ! -e "$file" ]
		then
			[ $missing_files == 1 ] || echo
			missing_files=1
			echo -e "\tmissing file - $file"
		fi
	done

	# Report error
	if [ $missing_files == 1 ]
	then
		echo "Error: files missing in distribution package"
		echo -e "\tForgot to include them in EXTRA_DIST?"
		rm -rf $local_temp_dir
		exit 1
	fi

	# End
	rm -rf $local_temp_dir
	echo " - ok"
}




# Test build of development and distribution package in remote machines.

# Input variables
#	$dist_package_name
#	$dist_package_path
#	$dist_version
#	$dev_package_path
#	$log_file

function test_build()
{

	# List of machines
	server_port_list="frijoles.ece.neu.edu fusion1.ece.neu.edu"
	#server_port_list="frijoles.ece.neu.edu fusion1.ece.neu.edu tierra1.gap.upv.es:3322"
	#server_port_list="hg0.gap.upv.es:3322 tierra1.gap.upv.es:3322"
	#server_port_list="boston.disca.upv.es hg0.gap.upv.es:3322"
		

	# Iterate through machine list
	for server_port in $server_port_list
	do
		# Server and port
		server=$(echo $server_port | awk -F: '{ print $1 }')
		port=$(echo $server_port | awk -F: '{ print $2 }')
		[ -n "$port" ] || port=22
	
		# Copy distribution and development packages
		echo "Machine $server (port $port)"
		scp -P $port -q $dist_package_path $dev_package_path $server: \
			>> $log_file 2>&1
		if [ $? != 0 ]
		then
			echo -e "\tCannot connect to remote machine"
			continue
		fi
	
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
				cd $temp_dir 2>&1 && \
					rm -rf $dev_dir 2>&1 && \
					tar -xzf $dev_package_path 2>&1 && \
					cd $dev_dir 2>&1 && \
					aclocal 2>&1 && \
					autoconf 2>&1 && \
					automake --add-missing 2>&1 && \
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
			mv multi2sim-dev.tar.gz $temp_dir || exit 1
			mv '$dist_package_name' $temp_dir || exit 1
			dev_package_path="$temp_dir/multi2sim-dev.tar.gz"
			dist_package_path="$temp_dir/'$dist_package_name'"
			dev_dir="$temp_dir/multi2sim"
			dist_dir="$temp_dir/multi2sim-'$dist_version'"
			cd $temp_dir || exit 1
	
			# Extract packages
			tar -xzf $dev_package_path
			tar -xzf $dist_package_path
	
			# Tests on development package
			#test_dev_build dev-default
			test_dev_build dev-debug --enable-debug
			#test_dev_build dev-debug-no-gtk --enable-debug --disable-gtk
			#test_dev_build dev-debug-no-glut --enable-debug --disable-glut
			#test_dev_build dev-no-gtk --disable-gtk
			#test_dev_build dev-no-glut --disable-glut
	
			# Tests on distribution package
			#test_dist_build dist-default
			#test_dist_build dist-debug --enable-debug
			#test_dist_build dist-debug-no-gtk --enable-debug --disable-gtk
			#test_dist_build dist-debug-no-glut --enable-debug --disable-glut
			#test_dist_build dist-no-gtk --disable-gtk
			#test_dist_build dist-no-glut --disable-glut
	
			# Remove temporary directory
			rm -rf $temp_dir
		' >> $log_file 2>&1
	done
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
configure_args=
tag=
while true ; do
	case "$1" in
	-r) rev=$2 ; shift 2 ;;
	--tag) tag=$2 ; shift 2 ;;
	--) shift ; break ;;
	*) echo "$1: invalid option" ; exit 1 ;;
	esac
done

# Arguments
[ $# == 0 ] || syntax

# Reset log file
log_file="$HOME/$M2S_CLIENT_KIT_TMP_PATH/test-build.log"
rm -f $log_file

# Run
get_m2s_package
check_extra_dist
#test_build
#test_build_check

# End
rm -rf $temp_dir
exit 0

