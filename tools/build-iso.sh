#!/usr/bin/env bash
# Cardnull OS — the hand-rolled build.
#
# Pipeline (DESIGN.md's shape, no borrowed machinery):
#   1. Assemble the boot floor           (clang, freestanding)
#   2. Compile the Swift kernel          (swiftc, Embedded Swift)
#   3. Link kernel.bin                   (ld.lld, linker.ld)
#   4. Pack a bootable ISO               (grub-mkrescue)
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

for tool in clang grub-mkrescue; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2; exit 1; }
done

TARGET="x86_64-unknown-none-elf"

mkdir -p "$BUILD" "$DIST" "$ISO_DIR/boot/grub"

echo "==> [1/4] Assembling the boot floor"
clang --target="$TARGET" -ffreestanding -c \
    "$ROOT/Sources/boot/boot.S" -o "$BUILD/boot.o"
clang --target="$TARGET" -ffreestanding -fno-stack-protector -c \
    "$ROOT/Sources/boot/support.c" -o "$BUILD/support.o"
clang --target="$TARGET" -ffreestanding -fno-stack-protector -c \
    "$ROOT/Sources/boot/font8x8.c" -o "$BUILD/font8x8.o"

echo "==> [2/4] Compiling the Swift kernel (Embedded Swift, $TARGET)"
"$SWIFTC" \
    -target "$TARGET" \
    -enable-experimental-feature Embedded \
    -parse-as-library \
    -whole-module-optimization \
    -O \
    -module-name Kernel \
    -c "$ROOT/Sources/kernel/Kernel.swift" \
    -o "$BUILD/Kernel.o"

echo "==> [3/4] Linking kernel.bin"
"$LD" -nostdlib -static \
    -T "$ROOT/Sources/boot/linker.ld" \
    -o "$BUILD/kernel.bin" \
    "$BUILD/boot.o" "$BUILD/Kernel.o" "$BUILD/support.o" "$BUILD/font8x8.o"

echo "==> [4/4] Packing dist/cardnull.iso"
cp "$BUILD/kernel.bin" "$ISO_DIR/boot/kernel.bin"
# The welcome file (milestone 8): a plain text file at the disc's
# root, its source kept in disc/ beside the kernel's sources. It
# is not linked into the kernel — the running OS reads it back
# off the real disc through its own ATAPI driver and ISO9660
# reader, which is the milestone's whole point.
cp "$ROOT/disc/WELCOME.TXT" "$ISO_DIR/WELCOME.TXT"
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
grub-mkrescue -o "$DIST/cardnull.iso" "$ISO_DIR" >/dev/null

echo "Done: $DIST/cardnull.iso"
