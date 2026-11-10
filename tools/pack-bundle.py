#!/usr/bin/env python3
"""Pack the Cardnull file bundle (milestone 23) — the system's
own files, carried in memory.

The format is written down in docs/BUNDLE.md. In short: one
file holding every loose file the disc's root carries for the
system itself — the welcome, every guest program, every
feather — so a bootloader can hand the whole set to the kernel
as one Multiboot2 module, and the kernel can serve its files
out of memory on a machine whose boot medium is not a CD (a
stick, in Tyler's settled road).

    pack-bundle.py <isodir> <out.bundle>

The bundle is assembled from the ISO staging itself — the
very files step 6 of tools/build-iso.sh has just copied to the
disc's root — so the bundle and the disc can never disagree
about contents. The manifest below names the set in the
staging's own order. The packer guards the agreement both
ways: a manifest file missing from the staging refuses the
packing, and so does a root file of the system's kinds
(WELCOME.TXT, a .BIN, a .FEATHER) standing in the staging
without a place in the manifest — a file the builder added
and the bundle forgot would be exactly the silent divergence
this guard exists to catch.

The header is plain text, in the feather's own manner: the
magic line `CARDNULL FILES 1`, three reckoned lines (the file
count, the payload's whole byte count, and its FNV-1a 64
checksum, computed here from the real bytes), one line per
file (its name and its byte length), a line of three dashes,
and then the files themselves, concatenated in table order.

The checksum is an integrity check — it catches damage and
alteration after packing. It is not a signature: anyone can
recompute it, and the format's document says so.
"""

import os
import sys

MAGIC = b"CARDNULL FILES 1"
SEPARATOR = b"---"
FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3
MASK64 = (1 << 64) - 1

# The bundle's set, in the staging's order: the welcome, the
# bare guests, the feathers. This list is the manifest; the
# guard below holds the staging to it, and it to the staging.
MANIFEST = (
    "WELCOME.TXT",
    "HELLO.BIN",
    "COUNT.BIN",
    "BAD.BIN",
    "A.BIN",
    "B.BIN",
    "SPIN.BIN",
    "BADGFX.BIN",
    "WILDRECT.BIN",
    "HELLO.FEATHER",
    "TAMPERED.FEATHER",
    "FACE.FEATHER",
    "TERM.FEATHER",
)


def fnv1a64(data):
    """FNV-1a, 64-bit: the house reckoning, as the kernel
    reckons it — the same numbers, in the same order."""
    h = FNV_OFFSET
    for byte in data:
        h ^= byte
        h = (h * FNV_PRIME) & MASK64
    return h


def is_system_file(name):
    """The kinds the bundle carries: the welcome, a program,
    a feather — judged by the name, the way the installer
    judges its picks (milestone 21)."""
    upper = name.upper()
    return (upper == "WELCOME.TXT" or upper.endswith(".BIN")
            or upper.endswith(".FEATHER"))


def pack(isodir, out_path):
    staged = set()
    for name in os.listdir(isodir):
        if os.path.isfile(os.path.join(isodir, name)) \
                and is_system_file(name):
            staged.add(name)
    wanted = set(MANIFEST)
    missing = [n for n in MANIFEST if n not in staged]
    if missing:
        sys.exit("pack-bundle: the staging lacks the manifest's "
                 "files: " + ", ".join(missing))
    unlisted = sorted(staged - wanted)
    if unlisted:
        sys.exit("pack-bundle: the staging holds system files "
                 "the manifest does not name: "
                 + ", ".join(unlisted)
                 + " — add them to the manifest in "
                 "tools/pack-bundle.py, so the bundle and the "
                 "disc cannot silently disagree")
    payload = bytearray()
    entries = []
    for name in MANIFEST:
        with open(os.path.join(isodir, name), "rb") as f:
            data = f.read()
        entries.append((name, len(data)))
        payload += data
    out = bytearray()
    out += MAGIC + b"\n"
    out += b"files: %d\n" % len(entries)
    out += b"bytes: %d\n" % len(payload)
    out += b"checksum: %016x\n" % fnv1a64(bytes(payload))
    for name, length in entries:
        out += name.encode("ascii") + b" %d\n" % length
    out += SEPARATOR + b"\n"
    out += payload
    with open(out_path, "wb") as f:
        f.write(out)
    print("packed %s: %d files, %d payload bytes, bundle %d "
          "bytes, fnv1a64 %016x"
          % (out_path, len(entries), len(payload), len(out),
             fnv1a64(bytes(payload))))


if __name__ == "__main__":
    if len(sys.argv) == 3:
        pack(sys.argv[1], sys.argv[2])
    else:
        sys.exit(__doc__)
