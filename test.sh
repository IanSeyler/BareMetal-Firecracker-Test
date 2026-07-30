#!/bin/bash
set -e

BOLD="\033[1m"
NORMAL="\033[0m"

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
./build-app.sh "$PROG_C"
cp "$PROG_APP" ../BareMetal-Firecracker/sys
cd ..

cd BareMetal-Firecracker
./build.sh "$PROG_APP"
cp sys/baremetal.elf ../
cd ..

if ip link show tap0 > /dev/null 2>&1; then
	./baremetal.sh start
	sleep 15
	./baremetal.sh output --full
else
	echo "Skipping local BareMetal VM test run as tap device 'tap0' not found. Run 'BareMetal-Firecracker/scripts/mkbr0.sh' to create it if local tests are needed."
fi

if [ -f "./bm-api.sh" ]; then
	read -p "Upload baremetal.elf to the BareMetal Cloud for execution? [y/N] " REPLY
else
	REPLY="N"
fi
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
	if [ -z "${BM_API_KEY:-}" ]; then
		echo -e "BM_API_KEY is not set. Make sure you ${BOLD}export BM_API_KEY=YOURKEY${NORMAL} first"
		exit 1
	fi

	NAME=$(basename "$PROG_C" .c)
	NAME=$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9-' '-')
	IMAGE_ID=$(./bm-api.sh images upload "$PROG_APP" "BareMetal-Firecracker/sys/baremetal.elf" | awk -F': ' '/^id:/{print $2}')
	INSTANCE_ID=$(./bm-api.sh instances create "$NAME" 1 16 "$IMAGE_ID" | awk -F': ' '/^id:/{print $2}')
fi
