# Budgets

Every line below is a target with the way it is measured. Numbers are MiB.
`tools/size-report.sh` prints the storage table from a real build; the memory table is
read from cgroup `memory.current` on a booted device by `androwsctl mem`.

## Memory, 512 MB device

| Component                              |  MiB | How it is measured                    |
|----------------------------------------|-----:|---------------------------------------|
| Kernel, drivers, page tables           |   45 | `MemTotal - MemAvailable` at init     |
| OpenRC, mdev, logging, network         |   10 | sum of `memory.current` in system.slice|
| Compositor (labwc + wlroots + libinput)|   28 | `memory.current` of session.slice     |
| Broker, launcher, registry             |   12 | `memory.current` of androws.slice     |
| zram metadata and reclaim overhead     |   18 | `zramctl` mem_used_total minus data   |
| Foreground runtime, hot                |  330 | `memory.current` of the thawed cgroup |
| Background runtime, frozen in zram     |   15 | `memory.current` of the frozen cgroup |
| **Total**                              |**458**|                                      |
| Headroom                               |   54 | must stay above 32 or the build fails |

The 330 MiB foreground figure assumes Droid: zygote plus a trimmed `system_server`
sits near 180, leaving ~150 for one app. A Wine foreground is cheaper, about 210 for a
mid-size Win32 application, which is why the headroom check uses the Droid case.

## Storage, 1 GB device (976 MiB usable)

| Component                               |  MiB | Notes                                 |
|-----------------------------------------|-----:|---------------------------------------|
| Kernel + initramfs                      |   12 | bzImage plus zstd initramfs           |
| Alpine base, musl, busybox, OpenRC      |   68 | no docs, no man pages, no locales     |
| Wayland stack, labwc, one font family   |   22 | Inter subset, no emoji font           |
| Wine, WoW64 build, stripped             |  148 | no mono, no gecko, tests removed      |
| Droid system image, squashfs + zstd     |  610 | stripped GSI, no GApps, no bundled apps|
| Androws shell, broker, branding         |    6 |                                       |
| **System total**                        |**866**|                                      |
| F2FS overlay for user data and apps     |  110 | what is left of 976                   |

110 MiB of user space is the real constraint of this project. It is enough for a
handful of APKs or one modest Windows program, and it is the reason the roadmap puts
app storage on external media before it puts anything else.

## The rules the build enforces

`build/stages/60-image.sh` fails the build if any of these break:

1. System partition exceeds 880 MiB.
2. Predicted peak memory exceeds 480 MiB.
3. The Droid image is larger than 640 MiB after compression.
