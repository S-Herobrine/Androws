# Shared helpers for the Androws build stages. Author: Saeed x Claude
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="${WORK:-$ROOT/work}"
OUT="${OUT:-$ROOT/out}"
ROOTFS="$WORK/rootfs"
ARCH="${ARCH:-x86_64}"
VERSION="$(cut -d' ' -f1 < "$ROOT/VERSION")"

ALPINE_BRANCH="${ALPINE_BRANCH:-v3.20}"
KERNEL_VER="${KERNEL_VER:-6.6.52}"

c_ok="\033[32m"; c_hi="\033[36m"; c_err="\033[31m"; c_off="\033[0m"

step()  { printf "${c_hi}==>${c_off} %s\n" "$*"; }
ok()    { printf "${c_ok} ok${c_off} %s\n" "$*"; }
die()   { printf "${c_err}fail${c_off} %s\n" "$*" >&2; exit 1; }

need_tool() {
	command -v "$1" >/dev/null 2>&1 || die "missing host tool: $1 (run: make deps)"
}

need_input() {
	[ -e "$WORK/input/$1" ] || die "supply $WORK/input/$1 yourself, see docs/BUILDING.md"
}

# mib <path> -> size in MiB, rounded up
mib() { echo $(( ( $(du -sb "$1" | cut -f1) + 1048575 ) / 1048576 )); }

budget() {   # budget <label> <actual MiB> <ceiling MiB>
	if [ "$2" -gt "$3" ]; then
		die "$1 is ${2} MiB, ceiling is ${3} MiB"
	fi
	ok "$1 ${2}/${3} MiB"
}

mkdirs() { mkdir -p "$WORK" "$OUT" "$WORK/input" "$WORK/cache"; }
