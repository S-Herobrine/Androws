#!/usr/bin/env bash
# Boot an Androws image under the target's constraints, not the host's.
# Author: Saeed x Claude
set -euo pipefail

IMG="${1:?usage: run-qemu.sh <image.img>}"
RAM="${RAM:-512}"

# 512 MB and nothing more. If it needs -m 1024 to boot, it is not Androws.
exec qemu-system-x86_64 \
	-machine q35,accel=kvm:tcg \
	-cpu host \
	-m "$RAM" \
	-smp 2 \
	-drive file="$IMG",format=raw,if=virtio \
	-device virtio-gpu-pci \
	-device virtio-keyboard-pci \
	-device virtio-tablet-pci \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
	-display gtk,gl=on \
	-serial mon:stdio \
	-name "Androws (${RAM} MB)"
