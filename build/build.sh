#!/usr/bin/env bash
# Androws image builder. Usage: build.sh all | build.sh 30
# Author: Saeed x Claude
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib/common.sh"

stages=(00-prepare 10-base-rootfs 20-kernel 30-droid-runtime 40-win-runtime 50-shell 60-image)
want="${1:-all}"
mkdirs

started=$(date +%s)
for s in "${stages[@]}"; do
	if [ "$want" != "all" ] && [[ "$s" != "$want"* ]]; then continue; fi
	step "stage $s"
	"$here/stages/$s.sh"
done
step "finished in $(( $(date +%s) - started ))s"
[ "$want" = all ] && ls -lh "$OUT" || true
