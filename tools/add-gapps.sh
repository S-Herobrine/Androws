#!/usr/bin/env bash
# Install a GApps package you supply into the Droid runtime.
# Androws does not download, bundle, or redistribute Google binaries; see docs/APPS.md.
# Author: Saeed x Claude
set -euo pipefail

PKG="${1:?usage: add-gapps.sh <gapps-package.zip>   (pico or nano variant recommended)}"
DROID=/run/androws/droid
NEED_MIB=180

[ -f "$PKG" ] || { echo "no such package: $PKG" >&2; exit 1; }
mountpoint -q "$DROID" || { echo "Droid runtime is not mounted, start it first" >&2; exit 1; }

free_mib=$(df -Pm /data | awk 'NR==2{print $4}')
if [ "$free_mib" -lt "$NEED_MIB" ]; then
	cat >&2 <<MSG
Only ${free_mib} MiB free and GApps needs about ${NEED_MIB}.
On a 1 GB device this will not fit. Use Aurora Store or microG instead, or move the
app partition to external storage first. See docs/APPS.md.
MSG
	exit 1
fi

profile=$(cat /etc/androws/profile 2>/dev/null || echo low)
[ "$profile" = low ] && echo "warning: Play services on the low profile will be slow and may not stay resident."

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
unzip -q "$PKG" -d "$work"

echo "installing into the Droid overlay"
androwsctl focus droid >/dev/null
find "$work" -name '*.tar.lz' -exec sh -c 'lzip -d -c "$1" | tar -x -C "$DROID"' _ {} \; 2>/dev/null || \
	cp -a "$work"/system/. "$DROID/system/" 2>/dev/null || true

androws-droid-exec pm reset-permissions 2>/dev/null || true
echo "done, restart the Droid runtime: rc-service androws-droid restart"
