# Androws

One device, two app worlds. Androws is a small Linux system that runs Android apps
and Windows apps side by side on hardware with **512 MB of RAM and 1 GB of storage**.

    Author:  Saeed x Claude
    Version: 0.1.0-alpha "Cold Boot"
    License: MIT

## The idea in one paragraph

Androws is not a fork of Android and it is not a fork of Windows. It is a musl-based
Linux base (Alpine) with a Wayland session, carrying two guest runtimes: **Droid**, a
stripped AOSP system image running in a container against binderfs, and **Win**, a
WoW64 Wine build. A small supervisor called the **broker** makes sure only one runtime
is ever thawed. The other one is frozen with the cgroup v2 freezer and compressed into
zram, so it costs ~15 MB instead of ~300 MB. That single rule is what makes 512 MB
enough.

## Three modes

    androws-profile auto      pick from installed RAM and whether a GPU is present
    androws-profile low       512 MB - 1 GB, software rendering, one runtime resident
    androws-profile normal    2 - 4 GB, both runtimes warm, switching is instant
    androws-profile gaming    4 GB+, foreground keeps every page, background goes cold

One command moves zram, swappiness, KSM, the CPU governor, the renderer, the Android
heap limits, the Wine environment and the broker's freeze policy together. See
`docs/PROFILES.md`.

## Apps

Android apps and Windows apps appear in one launcher list. What Androws cannot ship
is written down in `docs/APPS.md`: the Play Store is not redistributable and is yours
to add, and the Microsoft Store is a UWP application that Wine cannot run at all.
Microsoft's own services do work, through their Android apps or the browser.

## Repository layout

    branding/        logo, wordmark, boot splash (SVG)
    docs/            architecture, memory and storage budgets, build guide, roadmap
    build/           staged image builder (base -> kernel -> runtimes -> shell -> image)
    src/broker/      androws-brokerd, the runtime arbiter (C, ~0 dependencies)
    src/shell/       session, launcher, androwsctl
    src/apps/        unified app registry (Android packages + Windows shortcuts)
    src/init/        OpenRC services
    src/profiles/    low, normal and gaming, one file each
    tools/           QEMU runner, size report, GApps helper for a package you supply
    .github/         CI workflow that builds the image on a GitHub runner

## Quick start

    make deps        # host packages needed to build
    make image       # produces out/androws-<version>-x86_64.img
    make run         # boots that image in QEMU with 512 MB of RAM

The build needs an AOSP GSI and a Wine tarball you supply yourself; see
`docs/BUILDING.md`. Nothing in this repository redistributes Android or Windows
binaries. If you have no Linux machine, run the `build-image` workflow on GitHub
instead: it produces the `.img`, plus `.vdi` and `.vhdx` for VirtualBox and Hyper-V.

## What is honest about this project

Androws does not run Windows. It runs Windows *applications*, through Wine, with the
compatibility limits Wine has. It does not run Google Play services. Under 512 MB you
will hold one Android app or one Windows app in the foreground at a time; switching
between them is fast because the frozen side stays in zram, but it is a switch, not
true side-by-side multitasking. Every number in `docs/BUDGETS.md` is a design target
with the measurement method written next to it, not a benchmark result.

See `docs/ROADMAP.md` for what is built, what is stubbed, and what is next.
