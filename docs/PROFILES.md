# Performance profiles

Three modes, one command: `androws-profile low | normal | gaming`, or
`androws-profile auto` to pick from installed RAM and whether a GPU is present.

Each mode changes nine things at once, which is the point: the settings are related,
and tuning them separately is how systems end up in incoherent states.

|                         | low            | normal        | gaming            |
|-------------------------|----------------|---------------|-------------------|
| Target RAM              | 512 MB - 1 GB  | 2 - 4 GB      | 4 GB+ with a GPU  |
| zram                    | 256 MB, lz4    | 512 MB, zstd  | 128 MB, lz4       |
| Swappiness              | 150            | 100           | 10                |
| KSM page merging        | on             | on            | off               |
| CPU governor            | schedutil      | schedutil     | performance       |
| Renderer                | pixman, software | gles2       | gles2 + vulkan for Wine |
| Background runtime      | frozen at once | left warm     | frozen and squeezed to 16 MB |
| Foreground ceiling      | 360 MB         | 1200 MB       | 3072 MB           |
| Pressure trip point     | 25             | 40            | 60                |

## Why each mode is shaped the way it is

**low** assumes there is no GPU and no spare page. Everything is biased toward
getting anonymous memory into zram early, which is why swappiness is 150 rather than
the usual 60. The background runtime is frozen the instant it loses focus.

**normal** has room to leave both runtimes warm. Switching between an Android app and
a Windows app stops being a thaw and becomes a window raise. The broker only
intervenes when real pressure shows up, at which point it freezes the background
runtime regardless of profile.

**gaming** inverts the memory strategy. Swapping during a frame is the worst thing
that can happen, so swappiness drops to 10, zram shrinks, KSM's page scanner is turned
off to give the CPU back to the game, and the compositor stops redirecting fullscreen
windows. The other runtime is not just frozen, it is squeezed to 16 MB.

`gaming` is the only profile that stops services: the registry scanner, syslog and the
time daemon come back when you leave it.
