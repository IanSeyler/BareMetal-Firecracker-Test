#!/bin/bash
set -e

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
