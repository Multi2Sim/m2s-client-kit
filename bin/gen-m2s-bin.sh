#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"

M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_M2S_PATH="$M2S_CLIENT_KIT_PATH/tmp/m2s"

M2S_SERVER_KIT_PATH="m2s-server-kit"
M2S_SERVER_KIT_TMP_PATH="$M2S_SERVER_KIT_PATH/tmp"
M2S_SERVER_KIT_BIN_PATH="$M2S_SERVER_KIT_PATH/bin"
M2S_SERVER_KIT_BIN_INI_FILE_PATH="$M2S_SERVER_KIT_BIN_PATH/inifile.py"
M2S_SERVER_KIT_M2S_BIN_PATH="$M2S_SERVER_KIT_TMP_PATH/m2s-bin"
M2S_SERVER_KIT_M2S_BIN_EXE_PATH="$M2S_SERVER_KIT_M2S_BIN_PATH/m2s"
M2S_SERVER_KIT_M2S_BIN_BUILD_INI_PATH="$M2S_SERVER_KIT_M2S_BIN_PATH/build.ini"

inifile_py="$HOME/$M2S_CLIENT_KIT_BIN_PATH/inifile.py"
log_file="$HOME/$M2S_CLIENT_KIT_PATH/tmp/gen-m2s-bin.log"
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
it does, a new one is not generated.

Options:

  -r <rev>
      Multi2Sim SVN revision number for generation of binary.

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
temp=`getopt -o r: -l configure-args: -n $prog_name -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi
eval set -- "$temp"
rev=
configure_args=
while true ; do
	case "$1" in
	-r) rev=$2 ; shift 2 ;;
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
if [ -z "$rev" ]; then
	temp=$(mktemp)
	svn info $M2S_SVN_URL > $temp 2>> $log_file || error "cannot obtain SVN info"
	rev=$(sed -n "s,^Revision: ,,gp" $temp)
	rm -f $temp
fi

# Info
echo -n "Checking for Multi2Sim Rev. $rev"

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
	echo "read Build ConfigureArgs" >> $inifile_script
	$inifile_py $build_ini run $inifile_script > $temp || exit 2
	for i in 1
	do
		read section_exists
		read revision
		read configure_args
	done < $temp
	rm -f $inifile_script $temp

	# Check matches
	[ "$section_exists" == 1 ] || exit 1
	[ "$revision" == "'$rev'" ] || exit 1
	[ "$configure_args" == "'$configure_args'" ] || exit 1

	# Build matches
	exit 0
' >> $log_file 2>&1
case $? in
	0)
		echo -n " - up to date"
		echo " - ok"
		exit 0
		;;
	1)
		;;
	*) error "server failed"
esac

# Obtain revision locally
echo -n " - obtain local revision"
if [ -d $HOME/$M2S_CLIENT_KIT_M2S_PATH ]
then
	cd $HOME/$M2S_CLIENT_KIT_M2S_PATH
	svn up -r $rev >/dev/null || error "cannot get SVN revision"
else
	svn co $M2S_SVN_TRUNK_URL $HOME/$M2S_CLIENT_KIT_M2S_PATH \
		-r $rev >/dev/null || error "cannot get local copy"
fi

# Create distribution package
echo -n " - generate package"
cd $HOME/$M2S_CLIENT_KIT_M2S_PATH
rm -f $HOME/$M2S_CLIENT_KIT_M2S_PATH/multi2sim*.tar.gz
if [ ! -e Makefile ]
then
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
	tar -xzvf '$dist_file' || exit 1
	rm -f '$dist_file'
	cd '$dist_file_name' || exit 1

	# Build
	./configure '"$configure_args"' || exit 1
	make || exit 1

	# Copy executable
	mv src/m2s $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH' || exit 1

	# Remove build directory
	cd ..
	rm -rf '$dist_file_name'

	# Record revision
	build_ini="$HOME/'$M2S_SERVER_KIT_M2S_BIN_BUILD_INI_PATH'"
	inifile_py="$HOME/'$M2S_SERVER_KIT_BIN_INI_FILE_PATH'"
	inifile_script=`mktemp`
	echo "write Build Revision '$rev'" >> $inifile_script
	echo "write Build ConfigureArgs \"'"$configure_args"'\"" >> $inifile_script
	$inifile_py $build_ini run $inifile_script || exit 1
	rm -f $inifile_script

' >> $log_file 2>&1 || error "failed building package in server"

# End
echo " - ok"
rm -f $log_file
exit 0

