#!/bin/bash
set -e

BOLD="\033[1m"
NORMAL="\033[0m"

echo -e "${BOLD}BareMetal-Firecracker-Test${NORMAL}"

echo -e "Running clean"
./clean.sh

# Pre-flight checks: make sure required utilities are installed
echo -e "Pre-flight check"
for cmd in git mkfs.ext2 curl unzip tar gcc nasm make patch jq; do
	if ! command -v "$cmd" > /dev/null 2>&1; then
		echo "Error: required command '$cmd' not found. Please install it before running this script." >&2
		exit 1
	fi
done

echo -e "${BOLD}Pulling repositories${NORMAL}"

echo -e "BareMetal-AppPort"
git clone --quiet https://github.com/ReturnInfinity/BareMetal-AppPort
echo -e "BareMetal-Firecracker"
git clone --quiet https://github.com/ReturnInfinity/BareMetal-Firecracker

mkdir BareMetal-AppPort/build/
cp files/* BareMetal-AppPort/build
cd BareMetal-AppPort
./setup.sh
cd ..

DISK="$PWD/disk.img"
DISKSIZE=512M

# Create the disk image if it doesn't already exist
if [ ! -f "$DISK" ]; then
#	echo "Creating $DISKSIZE ext2 disk image"
	mkfs.ext2 -q -F "$DISK" "$DISKSIZE"
fi
