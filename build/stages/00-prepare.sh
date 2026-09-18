#!/usr/bin/env bash
# Stage 00 - host tools and input checks
source "$(dirname "$0")/../lib/common.sh"
mkdirs

pkgs="build-essential flex bison libelf-dev libssl-dev bc squashfs-tools zstd \
parted dosfstools mtools f2fs-tools qemu-system-x86 curl python3"

if command -v apt-get >/dev/null; then
	step "installing host packages"
	sudo apt-get update -qq
	sudo apt-get install -y -qq $pkgs
elif command -v apk >/dev/null; then
	sudo apk add --no-cache build-base flex bison elfutils-dev openssl-dev bc \
		squashfs-tools zstd parted dosfstools mtools f2fs-tools qemu-system-x86_64 curl python3
else
	die "unsupported host, install by hand: $pkgs"
fi

for t in gcc make squashfs-tools/mksquashfs zstd parted; do need_tool "$(basename "$t")"; done
ok "host ready"

cat <<'NOTE'

Two inputs are yours to supply, this project ships neither:

  work/input/system.img        AOSP 13/14 GSI
  work/input/wine-9.0.tar.xz   Wine source tarball

NOTE
