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

if ! ip link show tap0 > /dev/null 2>&1; then
	echo -e "${BOLD}Warning${NORMAL}: tap device 'tap0' not found. VM will be started without network access. Run 'BareMetal-Firecracker/scripts/mkbr0.sh' to enable it." >&2
fi
./baremetal.sh start
sleep 15
./baremetal.sh output --full

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
