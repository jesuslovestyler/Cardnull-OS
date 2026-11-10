#!/usr/bin/env bash
# Cardnull OS — the own-bootloader image (milestone 22).
#
# The standard image (tools/build-iso.sh) boots behind both
# doors on GRUB. This script builds a second image beside
# it — dist/cardnull-ownboot.iso — identical in contents
# except behind the UEFI door, where the boot path is OURS:
# a small public-domain UEFI application
# (Sources/bootloader/) stands at the ESP's fallback path
# and loads the kernel itself, speaking the Multiboot2
# the kernel already reads. GRUB's UEFI machinery — its
# BOOTX64.EFI in the ESP, its x86_64-efi modules in the
# tree, the Mac-blessed copy of it — is replaced or
# removed, and no GRUB code stands on that door.
#
# The BIOS door of this image is still GRUB's, exactly as
# in the standard image, and says so in the docs: mixed
# doors are a waypoint, not a claim. The BIOS bootloader
# of our own is the next stone. The standard image is not
# touched by any of this; it is rebuilt by step 1 and left
# standing as the daily image.
#
# Pipeline:
#   1. The standard build (tools/build-iso.sh).
#   2. The bootloader: clang + lld-link, a PE/COFF UEFI
#      application from Sources/bootloader/.
#   3. The ESP: a FAT image in mtools, at the same size
#      GRUB's own ESP keeps, carrying our loader at
#      \EFI\BOOT\BOOTX64.EFI and the very same kernel
#      file at \BOOT\KERNEL.BIN (copied from the same
#      build/kernel.bin the standard image packs at
#      /boot/kernel.bin — identical by construction).
#   4. The image: xorriso rewrites the standard ISO with
#      the boot images replayed, /efi.img replaced by our
#      ESP, the blessed boot.efi replaced by our loader,
#      and GRUB's x86_64-efi modules struck from the tree.
#
# Usage:  tools/build-ownboot-iso.sh
# Output: dist/cardnull-ownboot.iso (and the standard
#         dist/cardnull.iso, rebuilt by step 1)
#
# Toolchain needs: everything build-iso.sh needs, plus
# lld-link and xorriso and mtools on PATH.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"

for tool in clang lld-link xorriso mformat mmd mcopy; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2; exit 1; }
done

echo "==> [1/4] The standard build"
"$ROOT/tools/build-iso.sh"

echo "==> [2/4] Building the bootloader (PE/COFF, UEFI)"
# Hand-rolled declarations (Sources/bootloader/efi.h), no
# borrowed EFI headers; the floor language for a floor
# job. -mno-red-zone for the house's standing reason:
# kernel C keeps nothing below its stack pointer, and the
# loader, which hands the machine to that kernel, keeps
# the same discipline.
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

echo "==> [3/4] Packing the ESP (our loader, the same kernel)"
ESP="$BUILD/esp-ownboot.img"
rm -f "$ESP"
# 2880 KiB — the very size GRUB's ESP keeps, so the image
# that replaces it asks nothing new of the disc's shape.
mformat -C -i "$ESP" -f 2880 ::
mmd -i "$ESP" ::/EFI
mmd -i "$ESP" ::/EFI/BOOT
mmd -i "$ESP" ::/BOOT
mcopy -i "$ESP" "$BUILD/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$ESP" "$BUILD/kernel.bin" ::/BOOT/KERNEL.BIN

echo "==> [4/4] Rewriting the image: the UEFI door is ours"
# The image is rebuilt from the standard image's own
# tree, extracted, modified on disk, and written fresh
# with the very El Torito parameters grub-mkrescue used
# (read off the standard image before this stone began).
# Why not patch the standard image in place? Milestone
# 22's first proofs found out, twice: xorriso's
# -boot_image keep binds the El Torito UEFI image to the
# ESP bytes AS IMPORTED — swapping /efi.img's contents
# changes the file view only, and the firmware still
# boots GRUB's ESP from the catalog's address, into a
# rescue shell over the modules struck below — and the
# inherited hybrid MBR/GPT describe the standard image's
# layout, not this one's, so kept whole they lie, and
# re-emitted (replay) they collide. Building the El
# Torito pair explicitly from the modified tree makes
# every map describe THIS disc: catalog, protective MBR,
# and GPT alike, with the ESP standing where both the
# catalog and the GPT say it stands. (Verified byte by
# byte before the first boot proof: the ESP inside is
# whole and ours at the catalog's address, and GRUB's
# EFI binary appears nowhere in the image.)
#
# The changes to the tree, all of them:
#   /efi.img                       our ESP (step 3)
#   /efi/boot/bootx64.efi          our loader — the copy
#                                  of GRUB's binary that
#                                  stands in the tree at
#                                  the UEFI fallback path
#   /System/Library/CoreServices/boot.efi
#                                  our loader — the Mac-
#                                  blessed copy's place;
#                                  the blessing itself is
#                                  HFS furniture, below
#   /boot/grub/x86_64-efi/         struck — GRUB's UEFI
#                                  modules served only
#                                  the UEFI door; the
#                                  i386-pc modules behind
#                                  the BIOS door are
#                                  untouched, and the
#                                  BIOS El Torito image
#                                  is GRUB's eltorito.img
#                                  with the same patches
#                                  the standard carries
# What the fresh build does not re-create: the standard
# image's HFS+ blessing for old Macs and its GRUB-
# stamped hybrid MBR boot code. A plain protective MBR
# and a true GPT stand in their place; the ownboot
# image is experimental, and a stick that boots by
# partition tables rides the stick stones regardless.
TREE="$BUILD/ownboot-tree"
rm -rf "$TREE"
mkdir -p "$TREE"
xorriso -osirrox on -indev "$DIST/cardnull.iso" \
    -extract / "$TREE" 2>/dev/null
cp "$ESP" "$TREE/efi.img"
cp "$BUILD/BOOTX64.EFI" "$TREE/efi/boot/bootx64.efi"
cp "$BUILD/BOOTX64.EFI" \
    "$TREE/System/Library/CoreServices/boot.efi"
rm -rf "$TREE/boot/grub/x86_64-efi"
# xorriso will not write over an image already standing
# at the output path; yesterday's ownboot comes down.
rm -f "$DIST/cardnull-ownboot.iso"
# -iso-level 3 carries grub-mkrescue's relaxed naming:
# full-length names in the plain ISO9660 fields
# (TERM.FEATHER, not the 8.3-truncated TERM.FEA). The
# kernel's disc reader matches those fields, and
# milestone 22's second proof watched it answer "Not on
# the disc" to a feather standing truncated on a strict
# build. With level 3 the name layout is the standard
# image's own, entry for entry.
xorriso -as mkisofs -o "$DIST/cardnull-ownboot.iso" \
    -V ISOIMAGE \
    -iso-level 3 \
    -c /boot.catalog \
    -b /boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    --grub2-boot-info \
    -eltorito-alt-boot \
    -e /efi.img -no-emul-boot \
    --protective-msdos-label \
    -efi-boot-part --efi-boot-image \
    "$TREE"

echo "Done: $DIST/cardnull-ownboot.iso"
