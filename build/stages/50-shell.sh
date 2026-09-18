#!/usr/bin/env bash
# Stage 50 - broker, session, launcher, branding, services
source "$(dirname "$0")/../lib/common.sh"

step "building the broker"
make -s -C "$ROOT/src/broker" clean
make -s -C "$ROOT/src/broker"
sudo install -Dm0755 "$ROOT/src/broker/androws-brokerd" "$ROOTFS/usr/bin/androws-brokerd"

step "installing the shell"
for f in androws-session androws-launcher androwsctl androws-profile; do
	sudo install -Dm0755 "$ROOT/src/shell/$f" "$ROOTFS/usr/bin/$f"
done
sudo install -Dm0755 "$ROOT/src/apps/androws-registry" "$ROOTFS/usr/bin/androws-registry"

step "installing performance profiles"
sudo install -d "$ROOTFS/etc/androws/profiles"
for c in "$ROOT"/src/profiles/*.conf; do
	sudo install -Dm0644 "$c" "$ROOTFS/etc/androws/profiles/$(basename "$c")"
done
# A default can be baked in by CI; otherwise the image boots low and the first
# session calls androws-profile auto.
default=low
[ -f "$ROOT/src/profiles/DEFAULT" ] && default=$(tr -d '[:space:]' < "$ROOT/src/profiles/DEFAULT")
echo "$default" | sudo tee "$ROOTFS/etc/androws/profile" >/dev/null
ok "default profile: $default"

step "installing services"
for s in "$ROOT"/src/init/*.openrc; do
	name=$(basename "$s" .openrc)
	sudo install -Dm0755 "$s" "$ROOTFS/etc/init.d/$name"
	sudo chroot "$ROOTFS" /sbin/rc-update add "$name" default
done

step "branding"
sudo install -Dm0644 "$ROOT/branding/androws-splash.svg" "$ROOTFS/usr/share/androws/splash.svg"
sudo install -Dm0644 "$ROOT/branding/androws-logo.svg" "$ROOTFS/usr/share/androws/logo.svg"
sudo install -Dm0644 /dev/stdin "$ROOTFS/etc/os-release" <<EOSR
NAME="Androws"
PRETTY_NAME="Androws $VERSION"
ID=androws
ID_LIKE=alpine
VERSION_ID="$VERSION"
HOME_URL="https://github.com/saeed/androws"
LOGO=androws
EOSR

# zram sized at half of RAM: the frozen runtime is the thing that lives in it.
sudo install -Dm0644 /dev/stdin "$ROOTFS/etc/conf.d/zram-init" <<'ZR'
load_on_start=yes
num_devices=1
type0=swap
flag0=32767
size0=256
algo0=lz4
ZR

sudo install -Dm0644 /dev/stdin "$ROOTFS/etc/androws/labwc/rc.xml" <<'RC'
<?xml version="1.0"?>
<labwc_config>
  <theme><cornerRadius>6</cornerRadius></theme>
  <keyboard>
    <keybind key="W-space"><action name="Execute" command="androws-launcher"/></keybind>
    <keybind key="W-Tab"><action name="NextWindow"/></keybind>
    <keybind key="W-d"><action name="Execute" command="androwsctl focus droid"/></keybind>
    <keybind key="W-w"><action name="Execute" command="androwsctl focus win"/></keybind>
  </keyboard>
</labwc_config>
RC

budget "shell + branding" 6 8
