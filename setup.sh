#!/bin/bash
set -e

BOLD="\033[1m"
NORMAL="\033[0m"

echo -e "${BOLD}BareMetal-App Setup${NORMAL}\n"

echo -e "Running clean"
./clean.sh

# Pre-flight checks: make sure required utilities are installed
echo -e "Pre-flight check"
for cmd in git curl unzip tar gcc nasm make patch jq; do
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

# Create the disk image if it doesn't already exist -- a plain zeroed
# (sparse) file, not an ext2 filesystem: BMFS (port/bmfs.c in
# BareMetal-AppPort) treats this as raw sectors it lays its own
# superblock/directory table/file data across directly, with no
# filesystem of its own underneath. Formatting it with mkfs.ext2 would
# leave non-zero ext2 metadata sitting in the exact sectors BMFS uses
# for its own superblock/directory table, which BMFS then misreads as
# pre-existing (garbage) directory entries -- corrupting block
# allocation for the first file any app creates.
if [ ! -f "$DISK" ]; then
#	echo "Creating $DISKSIZE disk image"
	truncate -s "$DISKSIZE" "$DISK"
fi

echo -e "\nComplete! Run ${BOLD}./test.sh YOURPROGRAM.c${NORMAL} to build and run your program."
