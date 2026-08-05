#!/bin/bash
set -e

BOLD="\033[1m"
NORMAL="\033[0m"

if [ -z "$1" ]; then
	echo "Usage: $0 <program.c> [otherfile.c ...]"
	exit 1
fi

PROG_SRCS=("$@")
PROG_APP="$(basename "${PROG_SRCS[0]}" .c).app"

# Mirror each source's path (and any header files sitting alongside it)
# into BareMetal-AppPort, so quote-form #includes between them resolve
# the same way there as they do here.
for SRC in "${PROG_SRCS[@]}"; do
	if [ ! -f "$SRC" ]; then
		echo "Error: $SRC not found"
		exit 1
	fi
	SRC_DIR=$(dirname "$SRC")
	mkdir -p "BareMetal-AppPort/$SRC_DIR"
	cp "$SRC" "BareMetal-AppPort/$SRC_DIR/"
	for HDR in "$SRC_DIR"/*.h; do
		if [ -f "$HDR" ]; then
			cp "$HDR" "BareMetal-AppPort/$SRC_DIR/"
		fi
	done
done

cd BareMetal-AppPort
./build-app.sh "${PROG_SRCS[@]}"
cp "$PROG_APP" ../BareMetal-Firecracker/sys
cd ..

cd BareMetal-Firecracker
./build.sh "$PROG_APP"
cp sys/baremetal.elf ../
cd ..
