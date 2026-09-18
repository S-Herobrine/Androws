# Androws architecture

    +--------------------------------------------------------------+
    |  androws-launcher        one list: Android apps + Windows apps |
    +--------------------------------------------------------------+
    |  androws-session (labwc / wlroots, Wayland, no Xorg)           |
    +----------------------------+---------------------------------+
    |  androws-brokerd  <-- the only component that decides which    |
    |  runtime is thawed, and how much memory it may have            |
    +-------------------+--------------------+---------------------+
    |  Droid runtime    |  Win runtime       |  native apps         |
    |  stripped AOSP    |  Wine (WoW64)      |  foot, files, etc.   |
    |  in a container   |  in a prefix       |                      |
    +-------------------+--------------------+---------------------+
    |  cgroup v2 (freezer, memory.high) | binderfs | zram | Xwayland |
    +--------------------------------------------------------------+
    |  Alpine / musl userland, OpenRC, busybox                        |
    +--------------------------------------------------------------+
    |  Linux 6.6 LTS, custom defconfig                               |
    +--------------------------------------------------------------+

## Why a Linux base and not a fork of either OS

Forking AOSP means carrying a build system that needs ~250 GB of disk and 16 GB of RAM
to produce an image that does not fit the target anyway. Forking Windows is not
possible. The only workable shape is a thin host that can *host* both app models:

* Android apps need binder, a Java runtime, and a HAL surface. A container built on
  binderfs + a stripped GSI gives all three without emulation.
* Windows apps need the Win32 API. Wine provides it natively on the same CPU, so there
  is no translation layer to pay for on x86_64. On ARM you additionally need FEX or
  box64, which is out of scope for 0.1.

## The one rule: a single hot runtime

`androws-brokerd` owns two cgroups:

    /sys/fs/cgroup/androws/droid
    /sys/fs/cgroup/androws/win

When a runtime moves to the background the broker writes `1` to its `cgroup.freeze`,
drops `memory.high` to 24 MB and asks the kernel to reclaim. Its anonymous pages land
in zram at roughly 3:1, so a 300 MB Android world becomes ~15 MB of resident cost.
Thawing is a single write back to `cgroup.freeze` plus the page faults needed to bring
the working set back, which measures in the low hundreds of milliseconds rather than a
cold start of several seconds.

The broker also watches `/proc/pressure/memory`. If the 10-second `some` average
crosses 25 it freezes the background runtime early instead of waiting for the OOM
killer to make a worse decision.

## Graphics

One compositor, `labwc` on wlroots, talking directly to DRM/KMS. No Xorg anywhere.

* Droid renders through a Wayland-backed hwcomposer shim, the approach Waydroid uses:
  the container's surface flinger hands buffers out as dmabufs and the compositor
  imports them, so there is no copy and no GL context on the host side.
* Win runs on Wine's Wayland driver where the application allows it, and falls back to
  Xwayland, which is started on demand and stopped again after 60 idle seconds.

## Storage

The system is a read-only squashfs compressed with zstd level 19, mounted through an
overlay whose upper layer is F2FS on the remaining free space. That has three effects:
the image ships smaller, the read-only layer cannot be corrupted by a bad shutdown, and
a factory reset is a single `rm -rf` of the upper directory.

## Security posture for 0.1

The Droid container runs unprivileged with a user namespace, a seccomp profile, and no
access to the host's `/dev` beyond binderfs, dri, and input. Wine runs as the same
unprivileged user with its prefix on the overlay. Neither runtime can see the other's
filesystem; a shared folder is bind-mounted at `~/Shared` into both, and that is the
only intentional path between them.
