#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TAGS_URL="http://multi2sim.org/svn/multi2sim/tags"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"

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

# Clear log
rm -f $log_file

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

# List of machines
#server_port_list="fusion1.ece.neu.edu tierra1.gap.upv.es:3322"
server_port_list="hg0.gap.upv.es:3322"

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

		#
		# Tests on development package
		#

		# Test 1 - default build
		echo ">>> test-build begin dev-default"
		cd $temp_dir 2>&1 && \
			rm -rf $dev_dir 2>&1 && \
			tar -xzf $dev_package_path 2>&1 && \
			cd $dev_dir 2>&1 && \
			aclocal 2>&1 && \
			autoconf 2>&1 && \
			automake --add-missing 2>&1 && \
			./configure 2>&1 && \
			make 2>&1 && \
			echo ">>> test-build passed dev-default"
		echo ">>> test-build end dev-default"


		#
		# Tests on distribution package
		#

		# Test 1 - default build
		echo ">>> test-build begin dist-default"
		cd $temp_dir 2>&1 && \
			rm -rf $dist_dir 2>&1 && \
			tar -xzf $dist_package_path 2>&1 && \
			cd $dist_dir 2>&1 && \
			./configure 2>&1 && \
			make 2>&1 && \
			echo ">>> test-build passed dist-default"
		echo ">>> test-build end dist-default"



		# Remove temporary directory
		rm -rf $temp_dir
	' >> $log_file 2>&1
done


# End
rm -rf $temp_dir
########rm -f $log_file
exit 0

