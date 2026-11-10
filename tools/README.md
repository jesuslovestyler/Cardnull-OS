# Build tools

The Cardnull OS build is a small, hand-rolled pipeline — no Xcode
template knows how to build an operating system, so the stitching lives
here.

## What is here

- **`build-iso.sh`** — the whole pipeline, end to end:
  1. assembles the boot floor (`Sources/boot/boot.S`, `support.c`)
     with clang, freestanding;
  2. assembles the guest programs (`programs/*.s`, and the
     feathers' programs in `feathers/`) with clang and flattens
     them with ld.lld — flat binaries the disc carries as files,
     never linked into the kernel (milestones 9 and 10);
  3. compiles the Swift kernel (`Sources/kernel/Kernel.swift`) with
     swiftc in **Embedded Swift** mode for `x86_64-unknown-none-elf`;
  4. links `build/kernel.bin` with ld.lld and
     `Sources/boot/linker.ld`;
  5. packs the feathers with the packer below — each card source
     in `feathers/` joined to its guest, its size and checksum
     reckoned from its real bytes: HELLO (milestone 11), FACE
     and TERM (milestone 18, standing on the door's graphical
     suite) — and packs HELLO's wounded twin, TAMPERED.FEATHER,
     beside them;
  6. packs **`dist/cardnull.iso`** with grub-mkrescue — a GRUB that
     loads `/boot/kernel.bin` by Multiboot2, the disc also carrying
     WELCOME.TXT, the eight guest binaries, and the four feathers at
     its root. The ISO is written at ISO 9660 level 3 so a
     feather's name stands whole in the tree (HELLO.FEATHER, not
     HELLO.FEA).

  The floor's C is compiled with the red zone off
  (`-mno-red-zone`, milestone 15): an interrupt's frame lands
  below the stack pointer, exactly where red-zone locals would
  live, and kernel code keeps nothing there — a timer frame once
  overwrote memset's own count, mid-launch, and the count
  became the interrupted address itself.

  Run it from anywhere: `tools/build-iso.sh`. Needs: swiftc (Swift 6+),
  clang, ld.lld, python3, grub-mkrescue (xorriso and mtools under it).
  Set `SWIFTC=/path/to/swiftc` if swiftc is not on the PATH.

- **`build-ownboot-iso.sh`** — the second image (milestone 22):
  runs `build-iso.sh` first (the standard image must always
  stand), compiles the bootloader in `Sources/bootloader/`
  (clang and lld-link as a freestanding PE/COFF EFI
  application — no gnu-efi, the EFI header is hand-written in
  the tree), packs an EFI system image with mtools holding the
  loader at `\EFI\BOOT\BOOTX64.EFI`, the same kernel at
  `\BOOT\KERNEL.BIN`, and the file bundle at
  `\BOOT\FILES.BUNDLE` (milestone 23 — our loader reads it
  into memory and names its span in a Multiboot2 module tag),
  then rebuilds the disc from the standard
  image's own tree with that ESP standing as the El Torito
  UEFI image, GRUB's places in the tree taken by the loader,
  and its UEFI module tree struck. The BIOS door of the
  result is still GRUB's; the UEFI door is ours. Output:
  `dist/cardnull-ownboot.iso`. The design and the lessons
  (why a fresh build, why ISO level 3) are kept in
  `docs/BOOTLOADER.md` and in the script's own comments.

- **`pack-feather.py`** — the feather packer (milestone 11): joins a
  card source (the magic line and the maker's keys: title, maker,
  version, support) to a flat guest binary, reckoning the program's
  size and FNV-1a 64 checksum into the card, and writes the finished
  `.feather`; its `tamper` mode flips one program byte of a packed
  feather, leaving the card's checksum stale, so the kernel's
  refusal can be witnessed. The format it packs to is defined in
  `docs/FEATHER.md`.

- **`pack-bundle.py`** — the bundle packer (milestone 23):
  assembles the system's own files — the welcome, every guest
  program, every feather, the very set the ISO staging just
  gathered at the disc's root — into one bundle file
  (`build/files.bundle`), reckoning the payload's count,
  byte total and FNV-1a 64 checksum into its plain-text
  header. It packs from the staging itself and refuses when
  the staging and its manifest disagree either way, so the
  bundle and the disc cannot silently hold different
  contents. The format it packs to is defined in
  `docs/BUNDLE.md`.

- **`run-utm.md`** — how the ISO is attached to a UTM virtual machine
  (emulated x86-64 PC) for the daily drill: boot, watch, shut down.

## Where things land

- `build/` — objects, `kernel.bin`, the ISO staging tree. Gitignored.
- `dist/cardnull.iso` — the bootable image. **The ISO does not live in
  the repo**; it is built locally and carried to the test machine.
- `dist/cardnull-ownboot.iso` — the experimental second image
  (milestone 22): the same disc, its UEFI door ours. Built by
  `build-ownboot-iso.sh`; it does not live in the repo either.
