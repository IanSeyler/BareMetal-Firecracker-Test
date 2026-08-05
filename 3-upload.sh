#!/bin/bash
set -e

BOLD="\033[1m"
NORMAL="\033[0m"

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

	NAME=$(basename "$PROG_APP" .app)
	NAME=$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9-' '-')
	IMAGE_ID=$(./bm-api.sh images upload "$PROG_APP" "BareMetal-Firecracker/sys/baremetal.elf" | awk -F': ' '/^id:/{print $2}')
	INSTANCE_ID=$(./bm-api.sh instances create "$NAME" 1 16 "$IMAGE_ID" | awk -F': ' '/^id:/{print $2}')
fi
