#!/bin/bash

M2S_SVN_URL="http://multi2sim.org/svn/multi2sim"
M2S_SVN_TRUNK_URL="http://multi2sim.org/svn/multi2sim/trunk"
M2S_CLIENT_KIT_PATH="m2s-client-kit"
M2S_CLIENT_KIT_M2S_PATH="$M2S_CLIENT_KIT_PATH/tmp/m2s"
M2S_SERVER_KIT_PATH="m2s-server-kit"
M2S_SERVER_KIT_TMP_PATH="$M2S_SERVER_KIT_PATH/tmp"
M2S_SERVER_KIT_M2S_BIN_PATH="$M2S_SERVER_KIT_TMP_PATH/m2s-bin"
M2S_SERVER_KIT_M2S_BIN_EXE_PATH="$M2S_SERVER_KIT_M2S_BIN_PATH/m2s"
M2S_SERVER_KIT_M2S_BIN_REV_PATH="$M2S_SERVER_KIT_M2S_BIN_PATH/rev"

log_file="$HOME/$M2S_CLIENT_KIT_PATH/tmp/gen-m2s-bin.log"


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
	prog=$(echo $0 | awk -F/ '{print $NF}')
	cat << EOF

Syntax:
    $prog [<options>] <server>[:<port>]

Generate an Multi2Sim binary in <server>:~/m2s-server-kit/tmp/m2s-bin/.
The script first checks which if the destination already contains a valid
binary. If it does, a new one is not generated.

Options:

  -r <rev>
      Multi2Sim SVN revision number for generation of binary.

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
TEMP=`getopt -o r: \
	-n 'gen-m2s-bin.sh' -- "$@"`
if [ $? != 0 ] ; then exit 1 ; fi
eval set -- "$TEMP"
rev=
while true ; do
	case "$1" in
	-r) rev=$2 ; shift 2 ;;
	--) shift ; break ;;
	*) echo "$1: invalid option" ; exit 1 ;;
	esac
done

# Arguments
if [ $# -ne 1 ]; then
	syntax
fi

# Server and port
server=$(echo $1 | awk -F: '{print $1}')
port=$(echo $1 | awk -F: '{print $2}')
if [ -z "$port" ]; then
	port=22
fi
shift

# If revision was not given, obtain latest
if [ -z "$rev" ]; then
	temp=$(mktemp)
	svn info $M2S_SVN_URL > $temp 2>> $log_file || error "cannot obtain SVN info"
	rev=$(sed -n "s,^Revision: ,,gp" $temp)
	rm -f $temp
fi

# Info
echo -n "Checking for Multi2Sim Rev. $rev"

# Check revision number of last binary generated.
# This value is stored in file "<server>:~/m2s-server-kit/tmp/m2s-bin/rev"
# Return:
#	0 - Revision math, no rebuild needed.
#	1 - Revision mismatch or not present, need to rebuild.
ssh -p $port $server '

	# Create directory
	mkdir -p $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH'

	# Check if information is available
	if [ ! -e $HOME/'$M2S_SERVER_KIT_M2S_BIN_REV_PATH' ]
	then
		exit 1
	fi

	# Check if M2S executable is available
	if [ ! -e $HOME/'$M2S_SERVER_KIT_M2S_BIN_EXE_PATH' ]
	then
		exit 1
	fi


	# Check if version matches
	rev=`cat $HOME/'$M2S_SERVER_KIT_M2S_BIN_REV_PATH'`
	if [ "$rev" != "'$rev'" ]
	then
		exit 1
	fi

	# Version matches
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
	*) error "cannot connect to server"
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
	./configure --enable-debug >> $log_file 2>&1 || \
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
	./configure --enable-debug || exit 1
	make || exit 1

	# Copy executable
	mv src/m2s $HOME/'$M2S_SERVER_KIT_M2S_BIN_PATH' || exit 1

	# Remove build directory
	cd ..
	rm -rf '$dist_file_name'

	# Record revision
	echo '$rev' > $HOME/'$M2S_SERVER_KIT_M2S_BIN_REV_PATH' || exit 1

' >> $log_file 2>&1
case $? in
	0)
		;;
	*) error "failed building package in server"
esac

# End
echo " - ok"
rm -f $log_file
exit 0

