# Build tools

The Cardnull OS build is a small, hand-rolled pipeline — Xcode supplies the
Swift compiler and the editor, but no Xcode template knows how to build an
operating system, so the stitching lives here.

When milestone 1 begins, this directory gains:

- `build.sh` — compiles the Swift kernel in embedded/freestanding mode,
  assembles the boot floor, links with `linker.ld`, and produces a bootable
  image.
- `linker.ld` — the linker script that lays the kernel out at the address
  the boot path expects.
- `run-utm.md` — how the image is attached to a UTM virtual machine
  (emulated x86-64 PC) for the daily drill: boot, watch, crash safely,
  repeat.

Nothing here is a placeholder pretending to work; these files arrive with
the milestone that uses them.
