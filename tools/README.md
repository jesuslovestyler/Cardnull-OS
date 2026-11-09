# Build tools

The Cardnull OS build is a small, hand-rolled pipeline — no Xcode
template knows how to build an operating system, so the stitching lives
here.

## What is here

- **`build-iso.sh`** — the whole pipeline, end to end:
  1. assembles the boot floor (`Sources/boot/boot.S`, `support.c`)
     with clang, freestanding;
  2. assembles the guest programs (`programs/*.s`) with clang and
     flattens them with ld.lld — flat binaries the disc carries as
     files, never linked into the kernel (milestone 9);
  3. compiles the Swift kernel (`Sources/kernel/Kernel.swift`) with
     swiftc in **Embedded Swift** mode for `x86_64-unknown-none-elf`;
  4. links `build/kernel.bin` with ld.lld and
     `Sources/boot/linker.ld`;
  5. packs **`dist/cardnull.iso`** with grub-mkrescue — a GRUB that
     loads `/boot/kernel.bin` by Multiboot2, the disc also carrying
     WELCOME.TXT and the three guest binaries at its root.

  Run it from anywhere: `tools/build-iso.sh`. Needs: swiftc (Swift 6+),
  clang, ld.lld, grub-mkrescue (xorriso and mtools under it). Set
  `SWIFTC=/path/to/swiftc` if swiftc is not on the PATH.

- **`run-utm.md`** — how the ISO is attached to a UTM virtual machine
  (emulated x86-64 PC) for the daily drill: boot, watch, shut down.

## Where things land

- `build/` — objects, `kernel.bin`, the ISO staging tree. Gitignored.
- `dist/cardnull.iso` — the bootable image. **The ISO does not live in
  the repo**; it is built locally and carried to the test machine.
