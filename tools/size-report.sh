#!/usr/bin/env bash
# Where the 1 GB went. Run after a build: tools/size-report.sh out
set -euo pipefail
OUT="${1:-out}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RFS="${ROOTFS:-$ROOT/work/rootfs}"

[ -d "$RFS" ] || { echo "no rootfs at $RFS, build first" >&2; exit 1; }

m() { echo $(( ( $(sudo du -sb "$1" 2>/dev/null | cut -f1) + 1048575 ) / 1048576 )); }

printf '%-34s %6s %6s\n' "component" "MiB" "budget"
printf '%-34s %6s %6s\n' "----------------------------------" "------" "------"
printf '%-34s %6s %6s\n' "kernel + initramfs"        "$(m "$RFS/boot")"                    12
printf '%-34s %6s %6s\n' "base userland"             "$(m "$RFS/usr/lib")"                 68
printf '%-34s %6s %6s\n' "wine"                      "$(m "$RFS/usr/lib/wine")"           148
printf '%-34s %6s %6s\n' "droid runtime (squashfs)"  "$(m "$RFS/usr/lib/androws")"        610
printf '%-34s %6s %6s\n' "fonts + graphics"          "$(m "$RFS/usr/share/fonts")"         22
echo
for f in "$OUT"/*.img; do [ -e "$f" ] && printf 'image  %-27s %6s\n' "$(basename "$f")" "$(m "$f")"; done
