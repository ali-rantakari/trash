#!/usr/bin/env bash
# 
# install script for trash
# (c) 2010 Ali Rantakari
# 

DN="`dirname \"$0\"`"
THISDIR="`cd \"$DN\"; pwd`"

BINDIR=/usr/local/bin
MANDIR=/usr/local/share/man/man1

BINFILE="${THISDIR}/trash"
MANFILE="${THISDIR}/trash.1"



if [ ! -e "${BINFILE}" ];then
	echo "Error: can not find \"${BINFILE}\". Make sure you're running this script from within the distribution directory (the same directory where trash resides.) If you already are, run 'make' to build trash and then try running this script again."
	exit 1
fi
if [ ! -e "${MANFILE}" ];then
	echo "Error: can not find \"${MANFILE}\" (the man page.) Make sure you're running this script from within the distribution directory (the same directory where trash resides.)"
	exit 1
fi
echo "================================="
echo
echo "This script will install:"
echo
printf "trash executable to: \e[36m${BINDIR}\e[m\n"
printf "trash man page to: \e[36m${MANDIR}\e[m\n"
echo
echo $'We\'ll need administrator rights to install to these locations so \e[33mplease enter your admin password when asked\e[m.'
echo $'\e[1mPress any key to continue installing or Ctrl-C to cancel.\e[m'
read
echo
sudo -v
if [ ! $? -eq 0 ];then echo "error! aborting." >&2; exit 10; fi
echo

echo -n "Creating directories..."
sudo mkdir -p ${BINDIR}
if [ ! $? -eq 0 ];then echo "...error! aborting." >&2; exit 10; fi
sudo mkdir -p ${MANDIR}
if [ ! $? -eq 0 ];then echo "...error! aborting." >&2; exit 10; fi
echo "done."

echo -n "Installing the binary executable..."
sudo cp -f "${BINFILE}" "${BINDIR}"
if [ ! $? -eq 0 ];then echo "...error! aborting." >&2; exit 10; fi
echo "done."

echo -n "Installing the man page..."
sudo cp -f "${MANFILE}" "${MANDIR}"
if [ ! $? -eq 0 ];then echo "...error! aborting." >&2; exit 10; fi
echo "done."

echo 
echo $'\e[32mtrash has been successfully installed.\e[m'
echo

