#!/bin/bash
set -e

if [ -z "$1" ]; then
	echo "Usage: $0 <program.c>"
	exit 1
fi

PROG_C=$1
PROG_APP=${PROG_C%.c}.app

#if [ ! -f "$PROG_C" ]; then
#	echo "Error: $PROG_C not found"
#	exit 1
#fi

cd BareMetal-AppPort
./clean.sh
./setup.sh
./build-app.sh "$PROG_C"
cp "$PROG_APP" ../BareMetal-Firecracker/sys
cd ..

cd BareMetal-Firecracker
./build.sh "$PROG_APP"
cp sys/baremetal.elf ../
cd ..
./baremetal.sh start
sleep 15
./baremetal.sh output --full
