# Building Androws

## Host requirements

A Linux host with 8 GB of RAM and 30 GB of free disk. The build does not need an AOSP
checkout; it repacks a GSI you already have.

    make deps     # installs: build-essential, squashfs-tools, zstd, qemu, mtools,
                  # dosfstools, parted, gcc, flex, bison, libelf-dev, python3

## Inputs you supply

Androws redistributes no Android or Windows code. Put these in `work/input/` yourself:

    work/input/system.img        an arm64 or x86_64 GSI (AOSP 13 or 14)
    work/input/wine-x.y.tar.xz   a Wine source tarball, 9.0 or newer for WoW64

## Stages

Each stage is independent and can be re-run on its own with `make stage S=30`.

| Stage | Script                | Produces                                     |
|-------|-----------------------|----------------------------------------------|
| 00    | 00-prepare.sh         | host packages, work tree, input checks        |
| 10    | 10-base-rootfs.sh     | Alpine minirootfs, trimmed                    |
| 20    | 20-kernel.sh          | bzImage with binderfs, zram, overlayfs, F2FS  |
| 30    | 30-droid-runtime.sh   | stripped Droid squashfs from your GSI         |
| 40    | 40-win-runtime.sh     | Wine WoW64 build, stripped                    |
| 50    | 50-shell.sh           | compositor, broker, launcher, branding        |
| 60    | 60-image.sh           | partitioned .img, budget checks               |

## Trying it without hardware

    make run

Boots the image in QEMU with `-m 512` and a 1 GB disk, which is the point: if it does
not boot there, it is not finished.
