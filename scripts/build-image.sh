#!/usr/bin/env bash
# Build a Flipper OS disk image for one board, in a container, from the
# build-scripts submodule. The finished image is copied into images/.
#
# Usage:  scripts/build-image.sh
#
# Environment:
#   BOARD          target board (default: sige5, the BPI-M5 Pro)
#   KERNELS        kernels to build, in order (default: "mainline bsp", as upstream does)
#   KEEP_SRC       yes = reuse cloned sources, update = git pull, no = re-clone (default: yes)
#   BUILD_ID       label in the image file name (default: local-<UTC timestamp>)
#   UPDATE_ROOTFS  non-empty = rebuild the root filesystem image so it picks up
#                  freshly built kernels (default: 1; set to "" to reuse the cached one)
#   UPDATE_OSPACK  non-empty = rebuild the Debian package set as well (default: unset)
#   SKIP_CONTAINER_BUILD  non-empty = do not rebuild the builder container image
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/build-scripts"
IMAGE="flipperone-linux-build"

export BOARD="${BOARD:-sige5}"
export KERNELS="${KERNELS:-mainline bsp}"
export KEEP_SRC="${KEEP_SRC:-yes}"
export BUILD_ID="${BUILD_ID:-local-$(date -u '+%Y%m%d-%H%M')}"
export UPDATE_ROOTFS="${UPDATE_ROOTFS-1}"
export UPDATE_OSPACK="${UPDATE_OSPACK-}"

# Docker Desktop does not always link its CLI into the PATH.
if ! command -v docker >/dev/null 2>&1; then
	PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"
fi

if [ ! -f "$SCRIPTS/build-images.sh" ]; then
	echo "build-scripts/ is empty. Run: git submodule update --init" >&2
	exit 1
fi
if ! docker info >/dev/null 2>&1; then
	echo "Docker is not running. Start Docker Desktop and try again." >&2
	exit 1
fi

# The container cannot read the submodule's git metadata, so pass it in.
export GIT_HASH="$(git -C "$SCRIPTS" rev-parse --short HEAD)"
export GIT_BRANCH="$(git -C "$SCRIPTS" symbolic-ref --short HEAD 2>/dev/null || echo detached)"
export GIT_MSG="$(git -C "$SCRIPTS" log -1 --pretty=format:%s)"

if [ -z "${SKIP_CONTAINER_BUILD:-}" ]; then
	docker build -t "$IMAGE" "$SCRIPTS"
fi

mkdir -p "$ROOT/images"

# Sources and build output live on Docker volumes, not on the Mac's disk:
# the kernel tree needs a case-sensitive filesystem, and bind mounts are slow.
docker run --rm --privileged \
	-e BOARD -e KERNELS -e KEEP_SRC -e BUILD_ID \
	-e UPDATE_ROOTFS -e UPDATE_OSPACK \
	-e GIT_HASH -e GIT_BRANCH -e GIT_MSG \
	-v "$SCRIPTS:/workspace" \
	-v flipper-build-src:/workspace/src \
	-v flipper-build-prebuilt:/workspace/prebuilt \
	-v flipper-build-artifacts:/artifacts \
	-v "$ROOT/images:/host-images" \
	-w /workspace \
	--entrypoint bash \
	"$IMAGE" -euc '
		./build-uboot.sh
		for k in $KERNELS; do
			"./build-kernel-$k.sh"
		done
		./build-images.sh
		cp -v /artifacts/images/debian-512-"$BOARD"-"$BUILD_ID".img.* /host-images/
	'

echo
echo "Done: $ROOT/images/debian-512-$BOARD-$BUILD_ID.img.zst"
