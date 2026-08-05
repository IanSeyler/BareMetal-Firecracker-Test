#!/bin/bash
set -e

BOLD="\033[1m"
NORMAL="\033[0m"

# Check for firecracker
if ! command -v firecracker > /dev/null 2>&1; then
	echo -e "${BOLD}Error${NORMAL}: 'firecracker' not found. Local tests will not work." >&2
	exit 1
fi

# Check for tap0
if ! ip link show tap0 > /dev/null 2>&1; then
	echo -e "${BOLD}Warning${NORMAL}: tap device 'tap0' not found. VM will be started without network access. Run 'BareMetal-Firecracker/scripts/mkbr0.sh' to enable it." >&2
fi

./baremetal.sh start
sleep 15
./baremetal.sh output --full
