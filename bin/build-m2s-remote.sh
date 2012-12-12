#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TAGS_URL="http://multi2sim.org/svn/multi2sim/tags"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_M2S_PATH="$M2S_CLIENT_KIT_PATH/tmp/multi2sim"

M2S_SERVER_KIT_PATH="m2s-server-kit"
M2S_SERVER_KIT_TMP_PATH="$M2S_SERVER_KIT_PATH/tmp"
M2S_SERVER_KIT_BIN_PATH="$M2S_SERVER_KIT_PATH/bin"
M2S_SERVER_KIT_BIN_INI_FILE_PATH="$M2S_SERVER_KIT_BIN_PATH/inifile.py"
M2S_SERVER_KIT_M2S_BIN_PATH="$M2S_SERVER_KIT_TMP_PATH/m2s-bin"
M2S_SERVER_KIT_M2S_BIN_EXE_PATH="$M2S_SERVER_KIT_M2S_BIN_PATH/m2s"
M2S_SERVER_KIT_M2S_BIN_BUILD_INI_PATH="$M2S_SERVER_KIT_M2S_BIN_PATH/build.ini"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
log_file="$HOME/$M2S_CLIENT_KIT_PATH/tmp/build-m2s-remote.log"
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

Generate an Multi2Sim binary in <server>:~/m2s-server-kit/tmp/m2s-bin/. The
script first checks which if the destination already contains a valid binary. If
it does, the previously generated binary is used instead. By default, the latest
SVN revision of the Multi2Sim development trunk is fetched and built.

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

Arguments:

  <targethost>
      Destination host

  <port>
      Port for ssh connections (default is 22)

EOF
	exit 1
}




#
# Main Script
#

# Clear log
rm -f $log_file

# Options
temp=`getopt -o r: -l configure-args:,tag: -n $prog_name -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi
eval set -- "$temp"
rev=
configure_args=
tag=
while true ; do
	case "$1" in
	-r) rev=$2 ; shift 2 ;;
	--tag) tag=$2 ; shift 2 ;;
	--configure-args) configure_args=$2 ; shift 2 ;;
	--) shift ; break ;;
	*) echo "$1: invalid option" ; exit 1 ;;
	esac
done

# Arguments
[ $# == 1 ] || syntax
server_port=$1

# Server and port
server=$(echo $server_port | awk -F: '{print $1}')
port=$(echo $server_port | awk -F: '{print $2}')
[ -n "$port" ] || port=22

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
echo -n "Checking Multi2Sim $tag_name, SVN Rev. $rev"

# Check information of last binary generated. This information is stored in an
# INI file at "<server>:~/m2s-server-kit/tmp/m2s-bin/build.ini"
# Return:
#	0 - Build up to date, no rebuild needed.
#	1 - Build out of date or not present, need to rebuild.
ssh -p $port $server '

	# Create directory
	mkdir -p $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH'

	# Check if information about last build, and build itself, is available
	m2s_exe="$HOME/'$M2S_SERVER_KIT_M2S_BIN_EXE_PATH'"
	build_ini="$HOME/'$M2S_SERVER_KIT_M2S_BIN_BUILD_INI_PATH'"
	[ -e "$build_ini" ] || exit 1
	[ -e "$m2s_exe" ] || exit 1

	# Read info of last build from INI file
	inifile_py="$HOME/'$M2S_SERVER_KIT_BIN_INI_FILE_PATH'"
	inifile_script=`mktemp`
	temp=`mktemp`
	echo "exists Build" >> $inifile_script
	echo "read Build Revision" >> $inifile_script
	echo "read Build Tag" >> $inifile_script
	echo "read Build ConfigureArgs" >> $inifile_script
	$inifile_py $build_ini run $inifile_script > $temp || exit 2
	for i in 1
	do
		read section_exists
		read revision
		read tag
		read configure_args
	done < $temp
	rm -f $inifile_script $temp

	# Check matches
	[ "$section_exists" == 1 ] || exit 1
	[ "$revision" == "'$rev'" ] || exit 1
	[ "$tag" == "'$tag'" ] || exit 1
	[ "$configure_args" == "'$configure_args'" ] || exit 1

	# Build matches
	exit 0
' >> $log_file 2>&1
case $? in
	0)
		# Build matches
		echo -n " - up to date"
		echo " - ok"
		exit 0
		;;
	1)
		# Build does not match
		;;
	*)
		# Error in server
		error "server failed"
esac

# Obtain revision locally
echo -n " - obtain local revision"
cd && rm -rf $M2S_CLIENT_KIT_M2S_PATH
if [ -z "$tag" ]
then
	svn co $M2S_SVN_TRUNK_URL $HOME/$M2S_CLIENT_KIT_M2S_PATH \
		-r $rev >/dev/null || error "cannot get local copy"
else
	svn co $M2S_SVN_TAGS_URL/$tag $HOME/$M2S_CLIENT_KIT_M2S_PATH \
		-r $rev >/dev/null || error "cannot get local copy"
fi

# Create distribution package
echo -n " - generate package"
cd $HOME/$M2S_CLIENT_KIT_M2S_PATH
rm -f $HOME/$M2S_CLIENT_KIT_M2S_PATH/multi2sim*.tar.gz
if [ ! -e Makefile ]
then
	libtoolize >> $log_file 2>&1 && \
	aclocal >> $log_file 2>&1 && \
	autoconf >> $log_file 2>&1 && \
	automake --add-missing >> $log_file 2>&1 && \
	./configure $configure_args >> $log_file 2>&1 || \
	error "failed running autotools locally"
fi
make dist >> $log_file 2>&1 || \
	error "failed to generate distribution package"

# Copy to server
echo -n " - copy to server"
cd $HOME/$M2S_CLIENT_KIT_M2S_PATH
dist_file=$(ls multi2sim*.tar.gz)
dist_file_name=${dist_file%.tar.gz}
if [ `echo $dist_file | wc -w` != 1 ]
then
	error "unexpected distribution package name"
fi
scp -q -P $port $dist_file $server:$M2S_SERVER_KIT_TMP_PATH >> $log_file 2>&1 \
	|| error "cannot copy distribution package to server"

# Unpack and build in server
echo -n " - building"
ssh -p $port $server '

	# Unpack
	cd '$M2S_SERVER_KIT_TMP_PATH' || exit 1
	rm -rf '$dist_file_name'
	tar -xmzvf '$dist_file' || exit 1
	rm -f '$dist_file'
	cd '$dist_file_name' || exit 1

	# Build
	./configure '"$configure_args"' || exit 1
	make || exit 1

	# Copy executable
	mv bin/m2s $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH' || exit 1

	# Remove build directory
	cd ..
	rm -rf '$dist_file_name'

	# Record revision
	build_ini="$HOME/'$M2S_SERVER_KIT_M2S_BIN_BUILD_INI_PATH'"
	inifile_py="$HOME/'$M2S_SERVER_KIT_BIN_INI_FILE_PATH'"
	inifile_script=`mktemp`
	echo "write Build Revision '$rev'" >> $inifile_script
	echo "write Build Tag '$tag'" >> $inifile_script
	echo "write Build ConfigureArgs \"'"$configure_args"'\"" >> $inifile_script
	$inifile_py $build_ini run $inifile_script || exit 1
	rm -f $inifile_script

' >> $log_file 2>&1 || error "failed building package in server"

# End
echo " - ok"
rm -f $log_file
exit 0

