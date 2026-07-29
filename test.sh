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

read -p "Upload baremetal.elf to the BareMetal Cloud for execution? [y/N] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
	if [ -z "${BM_API_KEY:-}" ]; then
		echo "BM_API_KEY is not set. Make sure you `export BM_API_KEY=YOURKEY` first"
		exit 1
	fi

	NAME=$(basename "$PROG_C" .c)
	NAME=$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9-' '-')
	IMAGE_ID=$(./bm-api.sh images upload "$PROG_APP" "BareMetal-Firecracker/sys/baremetal.elf" | awk -F': ' '/^id:/{print $2}')
	INSTANCE_ID=$(./bm-api.sh instances create "$NAME" 1 16 "$IMAGE_ID" | awk -F': ' '/^id:/{print $2}')
fi
