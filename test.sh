#!/bin/bash
set -e

if [ -z "$1" ]; then
	echo "Usage: $0 <program.c>"
	exit 1
fi

PROG_C=$1
PROG_APP=${PROG_C%.c}.app

cd BareMetal-AppPort
./clean.sh
./setup.sh
./build-app.sh "$PROG_C"
cp "$PROG_APP" ../BareMetal-Firecracker/sys
cd ..

cd BareMetal-Firecracker
./build.sh "$PROG_APP"
./baremetal.sh start
sleep 15
./baremetal.sh output --full
cd ..
