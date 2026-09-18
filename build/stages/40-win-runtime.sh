#!/usr/bin/env bash
# Stage 40 - Wine, WoW64, stripped
source "$(dirname "$0")/../lib/common.sh"
need_input wine-9.0.tar.xz

SRC="$WORK/wine-9.0"
[ -d "$SRC" ] || tar -xf "$WORK/input/wine-9.0.tar.xz" -C "$WORK"

cd "$SRC"
step "configuring Wine for size, not for features"
# New WoW64 means no 32-bit multilib build, which is the single biggest saving here:
# a classic dual build is roughly 340 MiB installed, this lands near 148.
./configure \
	--prefix=/usr \
	--enable-archs=x86_64,i386 \
	--without-mingw \
	--without-gstreamer --without-opengl-tests --without-oss --without-v4l2 \
	--without-capi --without-gphoto --without-sane --without-cups \
	--with-wayland --with-x \
	--disable-tests \
	>"$WORK/wine-configure.log" 2>&1 || die "wine configure failed, see $WORK/wine-configure.log"

make -s -j"$(nproc)"
sudo make -s install DESTDIR="$ROOTFS"

step "stripping"
sudo rm -rf "$ROOTFS"/usr/share/wine/{mono,gecko}   # fetched on demand, never bundled
sudo rm -rf "$ROOTFS"/usr/share/man "$ROOTFS"/usr/include/wine
sudo find "$ROOTFS/usr/lib/wine" -name '*.a' -delete
sudo strip --strip-unneeded "$ROOTFS"/usr/lib/wine/*/*.so 2>/dev/null || true

# A skeleton prefix built at image time, not at first launch: creating it on a
# 512 MB device takes ~40 s and the user should not watch that.
sudo install -Dm0644 /dev/stdin "$ROOTFS/etc/androws/win-prefix.reg" <<'REG'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"renderer"="gl"
"VideoMemorySize"="64"

[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"mscoree"=""
"mshtml"=""
REG

budget "win runtime" "$(mib "$ROOTFS/usr/lib/wine")" 150
