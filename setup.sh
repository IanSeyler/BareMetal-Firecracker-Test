#!/bin/bash
set -e

# Pre-flight checks: make sure required utilities are installed
for cmd in git mkfs.ext2 curl unzip tar gcc nasm make patch jq; do
	if ! command -v "$cmd" > /dev/null 2>&1; then
		echo "Error: required command '$cmd' not found. Please install it before running this script." >&2
		exit 1
	fi
done

git clone https://github.com/ReturnInfinity/BareMetal-AppPort
git clone https://github.com/ReturnInfinity/BareMetal-Firecracker
mkdir BareMetal-AppPort/build/
cp files/* BareMetal-AppPort/build

DISK="$PWD/disk.img"
DISKSIZE=512M

# Create the disk image if it doesn't already exist
if [ ! -f "$DISK" ]; then
	echo "Creating $DISKSIZE ext2 disk image at $DISK"
	mkfs.ext2 -q -F "$DISK" "$DISKSIZE"
fi
