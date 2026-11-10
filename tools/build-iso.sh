#!/usr/bin/env bash
# Cardnull OS — the hand-rolled build.
#
# Pipeline (DESIGN.md's shape, no borrowed machinery):
#   1. Assemble the boot floor           (clang, freestanding)
#   2. Assemble the guest programs       (clang + ld.lld, flat binaries)
#   3. Compile the Swift kernel          (swiftc, Embedded Swift)
#   4. Link kernel.bin                   (ld.lld, linker.ld)
#   5. Pack the first feather            (tools/pack-feather.py)
#   6. Pack a bootable ISO               (grub-mkrescue)
#
# Usage:  tools/build-iso.sh
# Output: dist/cardnull.iso   (kept local; the ISO does not live in git)
#
# Toolchain needs: swiftc (Swift 6+, for Embedded Swift), clang, ld.lld,
# grub-mkrescue (with xorriso and mtools under it). Set SWIFTC to point
# at a swiftc that is not on PATH.

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

for tool in clang grub-mkrescue python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2; exit 1; }
done

TARGET="x86_64-unknown-none-elf"

mkdir -p "$BUILD" "$DIST" "$ISO_DIR/boot/grub"

echo "==> [1/6] Assembling the boot floor"
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

echo "==> [2/6] Assembling the guest programs (milestones 9 and 10)"
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
# alone.
for feather in greet face term; do
    clang --target="$TARGET" -c \
        "$ROOT/feathers/$feather.s" -o "$BUILD/$feather.o"
    "$LD" -Ttext=0x40000000 --oformat binary \
        -o "$BUILD/$feather.bin" "$BUILD/$feather.o"
done

echo "==> [3/6] Compiling the Swift kernel (Embedded Swift, $TARGET)"
"$SWIFTC" \
    -target "$TARGET" \
    -enable-experimental-feature Embedded \
    -parse-as-library \
    -whole-module-optimization \
    -O \
    -module-name Kernel \
    -c "$ROOT/Sources/kernel/Kernel.swift" \
    -o "$BUILD/Kernel.o"

echo "==> [4/6] Linking kernel.bin"
"$LD" -nostdlib -static \
    -T "$ROOT/Sources/boot/linker.ld" \
    -o "$BUILD/kernel.bin" \
    "$BUILD/boot.o" "$BUILD/Kernel.o" "$BUILD/support.o" "$BUILD/font8x8.o"

echo "==> [5/6] Packing the feathers (milestones 11 and 18)"
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

echo "==> [6/6] Packing dist/cardnull.iso"
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
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
# Behind the UEFI door, GRUB speaks through the firmware's text
# console until it is told otherwise — and a console is not a video
# mode, so multiboot2's framebuffer request finds nothing to give.
# Wake the graphics stack first, there only; the BIOS door's GRUB
# already stands on its VBE driver and is left exactly as it was.
if [ "$grub_platform" = "efi" ]; then
    insmod efi_gop
    insmod gfxterm
    terminal_output gfxterm
fi

set timeout=0
set default=0

menuentry "Cardnull OS" {
    multiboot2 /boot/kernel.bin
    boot
}
EOF
# One ISO, two doors (milestone 5): with both the i386-pc and the
# x86_64-efi GRUB modules installed, grub-mkrescue packs the disc
# with a BIOS El Torito boot image and an EFI system partition
# image carrying the UEFI GRUB (BOOTX64.EFI) — which loads the
# same /boot/grub/grub.cfg and the same kernel. Both modules sets
# must be present, or a door silently goes missing.
#
# -iso-level 3 (milestone 11, passed through to xorriso): the
# plain ISO9660 tree is written with names of up to thirty
# characters standing whole, instead of cut down to 8.3 — a
# feather's name is longer than 8.3 allows (HELLO.FEATHER,
# TAMPERED.FEATHER), and cut to HELLO.FEA it would be a lie
# about what the package is. Every older name on the disc is
# within 8.3 already and keeps its exact shape, version suffix
# and all; the kernel's reader, which forgives the suffix and
# matches names of any length the records carry, reads both
# kinds the same way.
grub-mkrescue -o "$DIST/cardnull.iso" "$ISO_DIR" -iso-level 3 \
    >/dev/null

echo "Done: $DIST/cardnull.iso"
