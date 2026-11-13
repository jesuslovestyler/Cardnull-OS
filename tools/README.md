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
  3. compiles the Swift kernel — one module in several files
     under `Sources/kernel/`, named for their subsystems
     (Kernel.swift keeps the boot and the entry; see its
     header for the map) — with swiftc in **Embedded Swift**
     mode for `x86_64-unknown-none-elf`;
  4. links `build/kernel.bin` with ld.lld and
     `Sources/boot/linker.ld`;
  5. packs the feathers with the packer below — each card source
     in `feathers/` joined to its guest, its size and checksum
     reckoned from its real bytes: HELLO (milestone 11), FACE
     and TERM (milestone 18, standing on the door's graphical
     suite) — and packs HELLO's wounded twin, TAMPERED.FEATHER,
     beside them;
  6. stages the disc — `/boot/kernel.bin`, the bundle in
     `/boot`, WELCOME.TXT, the eight guest binaries, and the
     four feathers at its root;
  7. builds both boot chains of our own (milestones 22–24):
     the BIOS chain (the 512-byte boot sector and the 16-bit
     second stage in `Sources/bootloader/`, joined as
     `/boot/biosboot.img`) and the UEFI chain (the loader as a
     freestanding PE/COFF application, no gnu-efi, its header
     hand-written, packed by mtools into the ESP at
     `\EFI\BOOT\BOOTX64.EFI` with the same kernel and bundle
     beside it);
  8. writes **`dist/cardnull.iso`** with xorriso — an
     explicit El Torito pair, our boot image behind the BIOS
     entry (`-boot-info-table` patching its place into the
     sector's table) and our ESP behind the UEFI entry, a
     protective MBR and a true GPT — and lays our boot
     sector into the MBR with `patch-mbr.py`, so the image
     boots the same chain from a stick. No GRUB code stands
     anywhere in the result. The ISO is written at ISO 9660
     level 3 so a feather's name stands whole in the tree
     (HELLO.FEATHER, not HELLO.FEA).

  The floor's C is compiled with the red zone off
  (`-mno-red-zone`, milestone 15): an interrupt's frame lands
  below the stack pointer, exactly where red-zone locals would
  live, and kernel code keeps nothing there — a timer frame once
  overwrote memset's own count, mid-launch, and the count
  became the interrupted address itself.

  Run it from anywhere: `tools/build-iso.sh`. Needs: swiftc (Swift 6+),
  clang, ld.lld, lld-link, xorriso, mtools, python3.
  Set `SWIFTC=/path/to/swiftc` if swiftc is not on the PATH.

- **`build-ownboot-iso.sh`** — the second image: runs
  `build-iso.sh` first (the standard image must always
  stand), then writes `dist/cardnull-ownboot.iso` as its
  own xorriso emission from the same staging, MBR patched
  the same way. It began at milestone 22 as the
  experimental disc whose UEFI door was ours while its
  BIOS door was still GRUB's; since milestone 24 both
  doors of both images are ours, and this is the second
  pressing — a separately built twin, kept for the stick
  experiments. The design is kept in `docs/BOOTLOADER.md`
  and in the scripts' own comments.

- **`patch-mbr.py`** — the MBR patcher (milestone 24):
  lays our boot sector into a finished image's master
  boot record, after verifying the disc's own copy of
  the sector carries the boot-info table xorriso patched
  (the file's ISO sector and length, agreeing with the
  directory), the image signature, and the GPT header —
  and afterward that the partition table (bytes
  446..511) and GPT stand exactly as they did. Only
  bytes 0..445 are written. A disc that fails a check is
  left untouched.

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
- `dist/cardnull-ownboot.iso` — the second image
  (milestone 22's experiment, milestone 24's twin): the same
  disc, both doors ours, separately pressed. Built by
  `build-ownboot-iso.sh`; it does not live in the repo either.
