#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TAGS_URL="http://multi2sim.org/svn/multi2sim/tags"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"

M2S_CLIENT_KIT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/..
M2S_CLIENT_KIT_TMP_PATH="$M2S_CLIENT_KIT_PATH/tmp"
M2S_CLIENT_KIT_BIN_PATH="$M2S_CLIENT_KIT_PATH/bin"
M2S_CLIENT_KIT_M2S_SRC_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-src"
M2S_CLIENT_KIT_M2S_BUILD_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-build"
M2S_CLIENT_KIT_M2S_BIN_PATH="$M2S_CLIENT_KIT_TMP_PATH/m2s-bin"
M2S_CLIENT_KIT_M2S_BIN_EXE_PATH="$M2S_CLIENT_KIT_M2S_BIN_PATH/m2s"
M2S_CLIENT_KIT_M2S_BIN_BUILD_INI_PATH="$M2S_CLIENT_KIT_M2S_BIN_PATH/build.ini"

build_ini="$M2S_CLIENT_KIT_M2S_BIN_PATH/build.ini"
inifile_py="$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
log_file="$M2S_CLIENT_KIT_PATH/tmp/build-m2s-local.log"
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
    $prog_name [<options>]

Obtain Multi2Sim from its server, build it, and generate the distribution
package, providing the following output directories:
Generate Multi2Sim's source code at

  ~/m2s-client-kit/tmp/m2s-src
	Folder containing an unmodified version of the SVN repository downloaded
	from the Multi2Sim server.

  ~/m2s-client-kit/tmp/m2s-build
  	Copy of the SVN repository where Autotools commands have run to create
	the Multi2Sim binary and its distribution package

  ~/m2s-client-kit/tmp/m2s-bin
  	Folder containing the Multi2Sim binary and tarball packages. The
	following files are generated in this folder:

        * m2s - Multi2Sim executable.
	* build.ini - Information about this build (INI file)
	* multi2sim.tar.gz - Tarball containing SVN development source.
	* multi2sim-XXX.tar.gz - Tarball containing distribution package.

The last call to this script is recorded, so that the Multi2Sim source is
selectively downloaded or build only if the requested version differs from the
available one.


Options:

  -r <rev>
      Choose a specific SVN revision to fetch. If this argument is not
      specified, the latest available SVN revision is used.

  --tag <tag>

      Use a Multi2Sim version release instead of the trunk. The name in argument
      <tag> must be an existing subdirectory in the 'tags' directory of the
      Multi2Sim SVN repository.

  --configure-args <args>
      Arguments for the 'configure' script run when compiling the package in the
      server. If these arguments share between calls to '$prog_name', the
      package will be regenerated. Example:
          --configure-args "--enable-debug --enable-profile"

EOF
	exit 1
}



# Check information of last call to this script. This information is stored in
# an INI file at "~/m2s-client-kit/tmp/m2s-bin/build.ini".
# Return:
#	0 - Source and build up to date
#	1 - Source up to date, rebuild needed
#	2 - Source and build out of date
#
# Input variables:
#	$rev
#	$tag
#	$configure_args
function check_m2s_build()
{
	local inifile_script
	local temp

	local section_exists
	local ref_revision
	local ref_tag
	local ref_configure_args

	# Find 'build.ini' file
	[ -e "$build_ini" ] || return 2

	# Read information about last build
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists Build" >> $inifile_script
	echo "read Build Revision" >> $inifile_script
	echo "read Build Tag" >> $inifile_script
	echo "read Build ConfigureArgs" >> $inifile_script
	$inifile_py $build_ini run $inifile_script > $temp || exit 1
	for i in 1
	do
		read section_exists
		read ref_rev
		read ref_tag
		read ref_configure_args
	done < $temp
	rm -f $inifile_script $temp
	
	# Check matches
	[ "$section_exists" == 1 ] || return 2
	[ "$rev" == "$ref_rev" ] || return 2
	[ "$tag" == "$ref_tag" ] || return 2
	[ "$configure_args" == "$ref_configure_args" ] || return 1

	# Build matches
	return 0
}




#
# Main Script
#

# Clear log
rm -f $log_file

# Options
temp=`getopt -o r:h -l configure-args:,tag:,help -n $prog_name -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi
eval set -- "$temp"
rev=
configure_args=
tag=
while true ; do
	case "$1" in
	-h|--help) syntax ;;
	-r) rev=$2 ; shift 2 ;;
	--tag) tag=$2 ; shift 2 ;;
	--configure-args) configure_args=$2 ; shift 2 ;;
	--) shift ; break ;;
	*) echo "$1: invalid option" ; exit 1 ;;
	esac
done

# Arguments
[ $# == 0 ] || syntax

# If revision was not given, obtain latest
if [ -z "$rev" ]
then
	temp=$(mktemp)
	svn info $M2S_SVN_URL > $temp 2>> $log_file || error "cannot obtain SVN info"
	rev=$(sed -n "s,^Revision: ,,gp" $temp)
	rm -f $temp
fi

# Info
if [ -z "$tag" ]
then
	tag_name="trunk"
else
	tag_name="tag '$tag'"
fi

# Check M2S build
echo -n "Checking Multi2Sim $tag_name, SVN Rev. $rev"
check_m2s_build
check_m2s_build_result=$?

# Finish if build is up to date
if [ "$check_m2s_build_result" == 0 ]
then
	echo " - up to date"
	exit
fi

# Download Multi2Sim source if revision/tag don't match
if [ "$check_m2s_build_result" == 2 ]
then
	# Download source
	echo -n " - downloading source"
	cd && rm -rf $M2S_CLIENT_KIT_M2S_SRC_PATH
	if [ -z "$tag" ]
	then
		svn co $M2S_SVN_TRUNK_URL $M2S_CLIENT_KIT_M2S_SRC_PATH \
			-r $rev >/dev/null || error "cannot get local copy"
	else
		svn co $M2S_SVN_TAGS_URL/$tag $M2S_CLIENT_KIT_M2S_SRC_PATH \
			-r $rev >/dev/null || error "cannot get local copy"
	fi
fi

# Make a copy of 'm2s-src' into 'm2s-build'
cd && rm -rf $M2S_CLIENT_KIT_M2S_BUILD_PATH
[ ! -d $M2S_CLIENT_KIT_M2S_BUILD_PATH ] || error "cannot remove 'm2s-build'"
cp -r $M2S_CLIENT_KIT_M2S_SRC_PATH $M2S_CLIENT_KIT_M2S_BUILD_PATH \
	|| error "cannot copy 'm2s-src' to 'm2s-build'"

# Build
echo -n " - building"
cd $M2S_CLIENT_KIT_M2S_BUILD_PATH
libtoolize >> $log_file 2>&1 && \
	aclocal >> $log_file 2>&1 && \
	autoconf >> $log_file 2>&1 && \
	automake --add-missing >> $log_file 2>&1 && \
	./configure $configure_args >> $log_file 2>&1 && \
	make clean >> $log_file 2>&1 && \
	make -j 4 >> $log_file 2>&1 && \
	make dist >> $log_file 2>&1 || \
		error "build failed"

# Obtain distribution version
cd $M2S_CLIENT_KIT_M2S_BUILD_PATH
dist_package=`ls multi2sim-*.tar.gz`
dist_package_count=`echo $dist_package | wc -w`
[ "$dist_package_count" == 1 ] || error "invalid number of packages ($dist_package_count)"
dist_version=`echo $dist_package | sed "s/^multi2sim-\(.*\)\.tar\.gz/\1/g"`
[ -n "$dist_version" ] || error "cannot obtain distribution package version"

# Copy executable
echo -n " - saving binary"
cd && rm -rf $M2S_CLIENT_KIT_M2S_BIN_PATH
mkdir -p $M2S_CLIENT_KIT_M2S_BIN_PATH
cp $M2S_CLIENT_KIT_M2S_BUILD_PATH/bin/m2s \
	$M2S_CLIENT_KIT_M2S_BIN_EXE_PATH ||
	error "failed copying binary"
mv $M2S_CLIENT_KIT_M2S_BUILD_PATH/multi2sim-*.tar.gz \
	$M2S_CLIENT_KIT_M2S_BIN_PATH ||
	error "failed moving distribution package"

# Create package with SVN development source
cd $M2S_CLIENT_KIT_M2S_SRC_PATH
tar -czf $M2S_CLIENT_KIT_M2S_BIN_PATH/multi2sim.tar.gz * \
	--transform 's,^,multi2sim/,' --exclude-vcs \
	|| error "cannot create development package"

# Record revision
inifile_script=`mktemp`
echo "write Build Revision $rev" >> $inifile_script
echo "write Build Tag $tag" >> $inifile_script
echo "write Build ConfigureArgs \"$configure_args\"" >> $inifile_script
echo "write Build Version $dist_version" >> $inifile_script
$inifile_py $build_ini run $inifile_script || exit 1
rm -f $inifile_script

# End
echo " - ok"
rm -f $log_file
exit 0

