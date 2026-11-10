#!/usr/bin/env python3
"""Cardnull OS — lay our boot sector in the image's MBR.

Milestone 24. Every image the build writes carries our
BIOS boot chain twice over: as the El Torito boot image
file /BOOT/BIOSBOOT.IMG (the CD door) and as the master
boot record itself (the stick door — a machine booting
the image from USB mass storage reads the MBR, not a
boot catalog). The two copies are the same sector: the
boot sector reads its image's place from the El Torito
boot information table at its bytes 8..63, which xorriso
patches into the file copy as it writes the disc; this
patcher writes the same sector into the finished image
at offset 0, so the table's word — the file's ISO sector
and its length — is already the truth in both copies.

What is preserved, exactly: the partition table and the
0x55AA signature xorriso laid at bytes 446..511 (the
protective entry for the GPT the image also carries),
the GPT itself at sector 1, and everything past the
first sector. What is checked before anything is
written: the file copy inside the disc really carries a
patched table (its file place nonzero), the image's
signature stands, and the GPT header stands where the
protective entry says it should. A disc that fails a
check is left untouched and the build stops.

Usage:  patch-mbr.py <image.iso>
"""

import struct
import sys

SECTOR = 2048


def fail(msg):
    print(f"patch-mbr: {msg}", file=sys.stderr)
    sys.exit(1)


def read_at(f, offset, length):
    f.seek(offset)
    data = f.read(length)
    if len(data) != length:
        fail("short read")
    return data


def dir_records(f, lba, size):
    """Yield (name, extent_lba, length, is_dir) from one
    ISO9660 directory, the plain fields only."""
    pos = 0
    while pos < size:
        sector = read_at(f, (lba + pos // SECTOR) * SECTOR, SECTOR)
        at = pos % SECTOR
        rec_len = sector[at]
        if rec_len == 0:
            pos = (pos // SECTOR + 1) * SECTOR
            continue
        rec = sector[at:at + rec_len]
        name_len = rec[32]
        name = rec[33:33 + name_len].decode("ascii", "replace")
        extent = struct.unpack_from("<I", rec, 2)[0]
        length = struct.unpack_from("<I", rec, 10)[0]
        yield name, extent, length, bool(rec[25] & 2)
        pos += rec_len


def find(f, dir_lba, dir_size, wanted):
    for name, extent, length, is_dir in dir_records(f, dir_lba, dir_size):
        plain = name.split(";")[0]
        if plain == wanted:
            return extent, length, is_dir
    return None


def main():
    if len(sys.argv) != 2:
        fail("usage: patch-mbr.py <image.iso>")
    path = sys.argv[1]
    with open(path, "r+b") as f:
        # The primary volume descriptor, at sector 16.
        pvd = read_at(f, 16 * SECTOR, SECTOR)
        if pvd[0] != 1 or pvd[1:6] != b"CD001":
            fail("no ISO9660 primary volume descriptor")
        root = pvd[156:156 + 34]
        root_lba = struct.unpack_from("<I", root, 2)[0]
        root_size = struct.unpack_from("<I", root, 10)[0]

        boot = find(f, root_lba, root_size, "BOOT")
        if boot is None:
            fail("no BOOT directory on the disc")
        img = find(f, boot[0], boot[1], "BIOSBOOT.IMG")
        if img is None:
            fail("no BIOSBOOT.IMG in the BOOT directory")
        img_lba, img_len, _ = img

        # The file copy of the boot sector, as it stands
        # on the finished disc — table patched by xorriso.
        sector = read_at(f, img_lba * SECTOR, 512)
        if sector[510:512] != b"\x55\xaa":
            fail("the boot image's first sector carries "
                 "no signature")
        table_lba = struct.unpack_from("<I", sector, 12)[0]
        table_len = struct.unpack_from("<I", sector, 16)[0]
        if table_lba != img_lba or table_len != img_len:
            fail(f"the boot info table on the disc says "
                 f"{table_lba}/{table_len}, the directory "
                 f"says {img_lba}/{img_len} — the table "
                 f"was not patched as expected")

        # The image's own first sector: xorriso's
        # protective MBR — signature standing, the GPT
        # header behind it.
        mbr = read_at(f, 0, 512)
        if mbr[510:512] != b"\x55\xaa":
            fail("the image's MBR carries no signature")
        gpt = read_at(f, 512, 8)
        if gpt != b"EFI PART":
            fail("the image carries no GPT header at "
                 "sector 1 for its protective entry")

        # The one write: our sector's code and table
        # (bytes 0..445) over the protective MBR's empty
        # code field. The partition table and signature
        # (bytes 446..511) stay exactly as xorriso laid
        # them.
        f.seek(0)
        f.write(sector[:446])
        f.flush()

        check = read_at(f, 0, 512)
        if check[:446] != sector[:446]:
            fail("the MBR write did not take")
        if check[446:] != mbr[446:]:
            fail("the partition table moved under the "
                 "patcher — refusing the result")
        if read_at(f, 512, 8) != b"EFI PART":
            fail("the GPT header moved under the patcher")

    print(f"patch-mbr: MBR now carries our boot sector; "
          f"BIOSBOOT.IMG at ISO sector {img_lba}, "
          f"{img_len} bytes; partition table and GPT "
          f"untouched.")


if __name__ == "__main__":
    main()
