# Roadmap

## 0.1.0-alpha "Cold Boot"  (this tree)

Done: project shape, branding, staged build system, kernel fragment, broker daemon
with freeze/thaw, pressure watch and three performance profiles, the androws-profile
tool, session and launcher scripts, app registry, OpenRC services, QEMU runner,
budget checks, and a CI workflow that builds the image on a GitHub runner.

Stubbed, and marked as such in the code: the hwcomposer shim in stage 30 currently
starts the container with a software renderer; the Wine Wayland path in stage 40 falls
back to Xwayland unconditionally.

## 0.2 "Handoff"

* dmabuf path for the Droid container, so Android apps stop copying frames.
* Window-level switching: a Windows app and an Android app in the same workspace, with
  the broker freezing at the *app* level instead of the runtime level.
* Shared clipboard between the runtimes.
* External storage as the app partition, which is what makes the 110 MiB user space
  survivable.

## 0.3 "Two Hands"

* ARM64 target with box64 for Windows apps.
* Android app notifications surfaced in the native shell.
* Battery model: freeze the background runtime on screen-off, not just on switch.

## Non-goals

A bundled Play Store, which no independent project can legally ship.
The Microsoft Store, which is UWP and cannot run on Wine at any point in the future.
Google Play services. A Windows kernel. Booting real Windows in a VM on 512 MB.
Claiming compatibility numbers that have not been measured on hardware.
