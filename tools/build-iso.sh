#!/usr/bin/env bash
# Cardnull OS — the hand-rolled build.
#
# Pipeline (DESIGN.md's shape, no borrowed machinery):
#   1. Assemble the boot floor           (clang, freestanding)
#   2. Assemble the guest programs       (clang + ld.lld, flat binaries)
#   3. Compile the Swift kernel          (swiftc, Embedded Swift)
#   4. Link kernel.bin                   (ld.lld, linker.ld)
#   5. Pack the first feather            (tools/pack-feather.py)
#   6. Build the BIOS boot chain         (Sources/bootloader/bios*)
#   7. Build our UEFI loader and the ESP (Sources/bootloader/)
#   8. Pack the bundle and write the ISO (pack-bundle.py, xorriso)
#
# Both doors are ours since milestone 24: the BIOS door
# boots our own boot sector and second stage (step 6),
# and the UEFI door boots our own loader (step 7) — no
# GRUB code stands anywhere in the image, and the image's
# MBR carries our boot sector too (tools/patch-mbr.py),
# so a stick carrying the image boots the same chain.
#
# Usage:  tools/build-iso.sh
# Output: dist/cardnull.iso   (kept local; the ISO does not live in git)
#
# Toolchain needs: swiftc (Swift 6+, for Embedded Swift), clang, ld.lld,
# lld-link, xorriso, mtools, python3. Set SWIFTC to point at a swiftc
# that is not on PATH.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
ISO_DIR="$BUILD/isodir"

# --- Find swiftc: env override, PATH, or the usual install homes. -------
SWIFTC="${SWIFTC:-}"
if [ -z "$SWIFTC" ]; then
    if command -v swiftc >/dev/null 2>&1; then
        SWIFTC="$(command -v swiftc)"
    elif [ -x /opt/swift/usr/bin/swiftc ]; then
        SWIFTC=/opt/swift/usr/bin/swiftc
    elif [ -x "$HOME/swift/usr/bin/swiftc" ]; then
        SWIFTC="$HOME/swift/usr/bin/swiftc"
    else
        echo "error: no swiftc found (set SWIFTC=/path/to/swiftc)" >&2
        exit 1
    fi
fi

# --- Find a linker: ld.lld preferred (it links any target from anywhere).
if command -v ld.lld >/dev/null 2>&1; then
    LD="$(command -v ld.lld)"
elif command -v ld >/dev/null 2>&1; then
    LD="$(command -v ld)"
else
    echo "error: no linker found (need ld.lld or ld)" >&2
    exit 1
fi

for tool in clang lld-link xorriso mformat mmd mcopy python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2; exit 1; }
done

TARGET="x86_64-unknown-none-elf"

mkdir -p "$BUILD" "$DIST" "$ISO_DIR/boot"

echo "==> [1/8] Assembling the boot floor"
clang --target="$TARGET" -ffreestanding -c \
    "$ROOT/Sources/boot/boot.S" -o "$BUILD/boot.o"
# -mno-red-zone, on both C files, is load-bearing (milestone 15):
# the red zone is a userspace luxury — an interrupt taken on this
# processor pushes its frame onto the current stack, below the
# stack pointer, exactly where red-zone locals live. Milestone
# 15's proof caught the timer's frame overwriting memset's own
# count with the interrupted address, mid-launch, and memset
# marching into the kernel's text; the hazard is as old as the
# first interrupt stub, and the longer sessions merely dealt it
# enough chances. Kernel C keeps nothing below its stack pointer.
clang --target="$TARGET" -ffreestanding -fno-stack-protector -mno-red-zone -c \
    "$ROOT/Sources/boot/support.c" -o "$BUILD/support.o"
clang --target="$TARGET" -ffreestanding -fno-stack-protector -mno-red-zone -c \
    "$ROOT/Sources/boot/font8x8.c" -o "$BUILD/font8x8.o"

echo "==> [2/8] Assembling the guest programs (milestones 9 and 10)"
# The guests: standalone assembly in programs/, linked at the
# address the kernel will lay them down at (0x40000000, the base
# of a guest's estate) and flattened to raw binaries. They are
# packed onto the disc in step 6 as files — never linked into the
# kernel — and the running OS reads them off the real disc, which
# is the milestone's whole point. Milestone 10 adds the pair —
# a and b, the two guests that take turns under `both`. Milestone
# 15 adds spin, the guest that never yields and never leaves: the
# witness that the timer's preemptive turns are real. Milestone
# 18 adds badgfx, which reaches through the drawing door for the
# kernel's own memory and is stopped at the wall, and wildrect,
# which asks the rectangle service for more screen than there is
# and stands, clipped, to tell about it.
for guest in hello count bad a b spin badgfx wildrect; do
    clang --target="$TARGET" -c \
        "$ROOT/programs/$guest.s" -o "$BUILD/$guest.o"
    "$LD" -Ttext=0x40000000 --oformat binary \
        -o "$BUILD/$guest.bin" "$BUILD/$guest.o"
done
# The feathers' programs: the greeting guest in feathers/
# (milestone 11), assembled the same way — it differs from the
# guests above only in how it travels, packed behind a card in
# step 5 rather than carried bare. Milestone 18 adds face, the
# greeting painted through the door's drawing services, and
# term, the terminal that is a feather, standing on the door
# alone. Milestone 31 adds keep, the keeping feather, which
# writes one small file to the Cardnull disk through the
# door's file services and reads it back.
for feather in greet face term keep; do
    clang --target="$TARGET" -c \
        "$ROOT/feathers/$feather.s" -o "$BUILD/$feather.o"
    "$LD" -Ttext=0x40000000 --oformat binary \
        -o "$BUILD/$feather.bin" "$BUILD/$feather.o"
done

echo "==> [3/8] Compiling the Swift kernel (Embedded Swift, $TARGET)"
"$SWIFTC" \
    -target "$TARGET" \
    -enable-experimental-feature Embedded \
    -parse-as-library \
    -whole-module-optimization \
    -O \
    -module-name Kernel \
    -c "$ROOT/Sources/kernel/Kernel.swift" \
    -o "$BUILD/Kernel.o"

echo "==> [4/8] Linking kernel.bin"
"$LD" -nostdlib -static \
    -T "$ROOT/Sources/boot/linker.ld" \
    -o "$BUILD/kernel.bin" \
    "$BUILD/boot.o" "$BUILD/Kernel.o" "$BUILD/support.o" "$BUILD/font8x8.o"

echo "==> [5/8] Packing the feathers (milestones 11 and 18)"
# The feather (docs/FEATHER.md): the card source in feathers/
# and the greeting guest built in step 2, joined by the
# packer, which reckons the program's size and FNV-1a checksum
# from its real bytes and writes them into the card. Beside
# the true feather, a wounded one: the same package with one
# program byte flipped and its checksum left stale, so the
# handler's refusal can be witnessed, not merely believed.
python3 "$ROOT/tools/pack-feather.py" pack \
    "$ROOT/feathers/hello.card" "$BUILD/greet.bin" \
    "$BUILD/HELLO.FEATHER"
python3 "$ROOT/tools/pack-feather.py" tamper \
    "$BUILD/HELLO.FEATHER" "$BUILD/TAMPERED.FEATHER"
# Milestone 18's two: the greeting face and the terminal,
# each behind its own card, packed by the same hand.
python3 "$ROOT/tools/pack-feather.py" pack \
    "$ROOT/feathers/face.card" "$BUILD/face.bin" \
    "$BUILD/FACE.FEATHER"
python3 "$ROOT/tools/pack-feather.py" pack \
    "$ROOT/feathers/term.card" "$BUILD/term.bin" \
    "$BUILD/TERM.FEATHER"
# Milestone 31's feather: the keeping feather, behind its
# own card, packed by the same hand.
python3 "$ROOT/tools/pack-feather.py" pack \
    "$ROOT/feathers/keep.card" "$BUILD/keep.bin" \
    "$BUILD/KEEP.FEATHER"

echo "==> [6/8] Staging the disc"
# A clean staging every time: the tree is rebuilt whole
# below, and a stale corner of an earlier build — the old
# GRUB tree above all — must never ride into the image.
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot"
cp "$BUILD/kernel.bin" "$ISO_DIR/boot/kernel.bin"
# The welcome file (milestone 8): a plain text file at the disc's
# root, its source kept in disc/ beside the kernel's sources. It
# is not linked into the kernel — the running OS reads it back
# off the real disc through its own ATAPI driver and ISO9660
# reader, which is the milestone's whole point.
cp "$ROOT/disc/WELCOME.TXT" "$ISO_DIR/WELCOME.TXT"
# The guest programs (milestones 9 and 10): the flat binaries
# built in step 2, at the disc's root under the names their
# milestones wear. Files, like the welcome — the OS reads them
# off the disc, lays them in ground of their own, and runs them,
# one at a time under `run` or two at a time under `both`.
cp "$BUILD/hello.bin" "$ISO_DIR/HELLO.BIN"
cp "$BUILD/count.bin" "$ISO_DIR/COUNT.BIN"
cp "$BUILD/bad.bin" "$ISO_DIR/BAD.BIN"
cp "$BUILD/a.bin" "$ISO_DIR/A.BIN"
cp "$BUILD/b.bin" "$ISO_DIR/B.BIN"
cp "$BUILD/spin.bin" "$ISO_DIR/SPIN.BIN"
# Milestone 18's two bare guests: the wall's witness and the
# clip's witness, carried bare like their elders.
cp "$BUILD/badgfx.bin" "$ISO_DIR/BADGFX.BIN"
cp "$BUILD/wildrect.bin" "$ISO_DIR/WILDRECT.BIN"
# The feathers (milestone 11): the packages the new `feather`
# command opens — the card read first, the checksum proven,
# and only then the program run. Files on the disc, like
# everything the OS reads; nothing of them is in the kernel.
# Milestone 18 adds its two faced feathers beside the first.
cp "$BUILD/HELLO.FEATHER" "$ISO_DIR/HELLO.FEATHER"
cp "$BUILD/TAMPERED.FEATHER" "$ISO_DIR/TAMPERED.FEATHER"
cp "$BUILD/FACE.FEATHER" "$ISO_DIR/FACE.FEATHER"
cp "$BUILD/TERM.FEATHER" "$ISO_DIR/TERM.FEATHER"
cp "$BUILD/KEEP.FEATHER" "$ISO_DIR/KEEP.FEATHER"
# The bundle (milestone 23, docs/BUNDLE.md): the same fourteen
# files the staging just gathered, packed into one file — the
# welcome, every guest, every feather — and laid in /boot, where
# both bootloaders carry it into memory beside the kernel,
# each naming its span in a Multiboot2 module tag. The packer
# assembles it from this very staging and refuses to pack when
# the staging and the manifest disagree either way, so the
# bundle and the disc can never hold different contents. The
# kernel serves its files out of the bundle in memory when the
# module rides; the loose files stay on the disc as the
# fall-back, exactly as the milestones left them.
python3 "$ROOT/tools/pack-bundle.py" "$ISO_DIR" "$BUILD/files.bundle"
cp "$BUILD/files.bundle" "$ISO_DIR/boot/files.bundle"
echo "==> [7/8] Building the boot chains (milestone 24: both doors ours)"
# The BIOS chain: a 512-byte boot sector of our own
# (Sources/bootloader/biosboot.S) and a second stage
# (biosentry.S's skin, biosmain.c's mind, compiled for
# the 16-bit world it wakes in), joined into one boot
# image. The sector must be exactly 512 bytes, and the
# stage must end below 0x10000 — its buffers are offsets
# under segment zero, and the chain is honest about the
# line it cannot cross.
clang --target="$TARGET" -ffreestanding -c \
    "$ROOT/Sources/bootloader/biosboot.S" -o "$BUILD/biosboot.o"
"$LD" -Ttext=0x7C00 --oformat binary \
    -o "$BUILD/biosboot-sector.bin" "$BUILD/biosboot.o"
[ "$(stat -c%s "$BUILD/biosboot-sector.bin")" = "512" ] || {
    echo "error: the boot sector is not 512 bytes" >&2; exit 1; }
clang --target=i686-pc-none-elf -m16 -ffreestanding \
    -c "$ROOT/Sources/bootloader/biosentry.S" \
    -o "$BUILD/biosentry.o"
clang --target=i686-pc-none-elf -m16 -ffreestanding \
    -fno-stack-protector -O2 -Wall \
    -c "$ROOT/Sources/bootloader/biosmain.c" \
    -o "$BUILD/biosmain.o"
"$LD" -nostdlib -static -T "$ROOT/Sources/bootloader/bios.ld" \
    -o "$BUILD/bios-stage2.elf" \
    "$BUILD/biosentry.o" "$BUILD/biosmain.o"
"$LD" -nostdlib -static -T "$ROOT/Sources/bootloader/bios.ld" \
    --oformat binary \
    -o "$BUILD/bios-stage2.bin" \
    "$BUILD/biosentry.o" "$BUILD/biosmain.o"
stage2_bytes="$(stat -c%s "$BUILD/bios-stage2.bin")"
[ $((0x7E00 + stage2_bytes)) -le 65536 ] || {
    echo "error: the second stage ends past 0x10000" >&2; exit 1; }
cat "$BUILD/biosboot-sector.bin" "$BUILD/bios-stage2.bin" \
    > "$BUILD/biosboot.img"
cp "$BUILD/biosboot.img" "$ISO_DIR/boot/biosboot.img"

# The UEFI chain (milestones 22 and 23): our loader as a
# PE/COFF application, and the ESP it stands on — the
# loader at \EFI\BOOT\BOOTX64.EFI, the same kernel at
# \BOOT\KERNEL.BIN, the bundle beside it at
# \BOOT\FILES.BUNDLE. The ESP keeps the 2880 KiB size
# the disc has always carried.
clang -target x86_64-unknown-windows \
    -ffreestanding -fno-stack-protector -mno-red-zone -O2 -Wall \
    -c "$ROOT/Sources/bootloader/bootloader.c" \
    -o "$BUILD/bootloader.o"
clang -target x86_64-unknown-windows \
    -ffreestanding \
    -c "$ROOT/Sources/bootloader/trampoline.S" \
    -o "$BUILD/trampoline.o"
lld-link -subsystem:efi_application -entry:efi_main -nodefaultlib \
    -out:"$BUILD/BOOTX64.EFI" \
    "$BUILD/bootloader.o" "$BUILD/trampoline.o"
ESP="$ISO_DIR/efi.img"
rm -f "$ESP"
mformat -C -i "$ESP" -f 2880 ::
mmd -i "$ESP" ::/EFI
mmd -i "$ESP" ::/EFI/BOOT
mmd -i "$ESP" ::/BOOT
mcopy -i "$ESP" "$BUILD/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$ESP" "$BUILD/kernel.bin" ::/BOOT/KERNEL.BIN
mcopy -i "$ESP" "$BUILD/files.bundle" ::/BOOT/FILES.BUNDLE

echo "==> [8/8] Writing dist/cardnull.iso (xorriso, then our MBR)"
# One ISO, two doors, both ours. The El Torito pair is
# written explicitly, the way milestone 22's ownboot
# build learned to write it: the BIOS entry names our
# boot image (-boot-info-table asks xorriso to patch
# the image place into the boot sector's table, the
# word the sector itself reads), the UEFI entry names
# the ESP; a plain protective MBR and a true GPT stand
# where GRUB's hybrid MBR once did, and the MBR's empty
# code field is then given our boot sector by the
# patcher — so the image boots the same chain from a
# stick as from a disc.
#
# What the fresh build does not re-create: the old
# standard image's HFS+ blessing for old Macs and its
# GRUB-stamped hybrid MBR boot code. The blessing was
# furniture for pre-2012 Mac firmware; the ownboot
# image has lived without it since milestone 22, and
# GRUB's code is the very thing this milestone removes.
#
# -iso-level 3 (milestone 11): the plain ISO9660 tree is
# written with names of up to thirty characters standing
# whole, instead of cut down to 8.3 — a feather's name is
# longer than 8.3 allows (HELLO.FEATHER, TAMPERED.FEATHER),
# and cut to HELLO.FEA it would be a lie about what the
# package is. The kernel's reader, and the BIOS stage's,
# match those fields the same way.
rm -f "$DIST/cardnull.iso"
xorriso -as mkisofs -o "$DIST/cardnull.iso" \
    -V ISOIMAGE \
    -iso-level 3 \
    -c /boot.catalog \
    -b /boot/biosboot.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e /efi.img -no-emul-boot \
    --protective-msdos-label \
    -efi-boot-part --efi-boot-image \
    "$ISO_DIR"
python3 "$ROOT/tools/patch-mbr.py" "$DIST/cardnull.iso"

echo "Done: $DIST/cardnull.iso"
