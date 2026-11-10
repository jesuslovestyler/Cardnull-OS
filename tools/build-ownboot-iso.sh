#!/usr/bin/env bash
# Cardnull OS — the ownboot image.
#
# This script began at milestone 22 as the experimental
# second image: the standard disc with its UEFI door
# rebuilt around our own loader, while its BIOS door was
# still GRUB's — mixed doors, a waypoint, and the script
# said so. Milestone 24 finished the road: the standard
# build (tools/build-iso.sh) now writes both doors with
# our own chains — the BIOS boot sector and second stage
# behind the El Torito BIOS entry and in the MBR, our
# UEFI loader in the ESP — and no GRUB code stands in
# either image.
#
# What this script still is: the second pressing. It
# runs the standard build, then writes
# dist/cardnull-ownboot.iso as its own xorriso emission
# from the same staging, with the same El Torito pair,
# the same protective MBR and GPT, and the same MBR
# patch — a separately built twin of the standard image,
# kept because the stick experiments and Tyler's witness
# copies have ridden it since milestone 22, and because
# a second pressing is a cheap proof that the build is
# the build, not an accident of one run.
#
# Pipeline:
#   1. The standard build (tools/build-iso.sh).
#   2. The same staging, emitted again as
#      dist/cardnull-ownboot.iso, MBR patched the same
#      way.
#
# Usage:  tools/build-ownboot-iso.sh
# Output: dist/cardnull-ownboot.iso (and the standard
#         dist/cardnull.iso, rebuilt by step 1)
#
# Toolchain needs: everything build-iso.sh needs.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
ISO_DIR="$BUILD/isodir"

echo "==> [1/2] The standard build"
"$ROOT/tools/build-iso.sh"

echo "==> [2/2] The second pressing: dist/cardnull-ownboot.iso"
rm -f "$DIST/cardnull-ownboot.iso"
xorriso -as mkisofs -o "$DIST/cardnull-ownboot.iso" \
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
python3 "$ROOT/tools/patch-mbr.py" "$DIST/cardnull-ownboot.iso"

echo "Done: $DIST/cardnull-ownboot.iso"
