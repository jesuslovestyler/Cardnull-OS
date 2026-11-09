#!/usr/bin/env python3
"""Pack a Cardnull feather (milestone 11) — and, for the proof
that the handler's checking works, wound one on purpose.

The format is written down in docs/FEATHER.md. In short: a
feather is one file — the magic line `CARDNULL FEATHER 1`, a
plain-text card of `key: value` lines, two reckoned lines the
packer adds (the program's size and its FNV-1a 64 checksum,
both computed here, from the real bytes), a line of three
dashes, and then the program itself, byte for byte.

    pack-feather.py pack   <card> <program> <out.feather>
    pack-feather.py tamper <in.feather> <out.feather>

`pack` refuses a card that does not open with the magic line
or that lacks title, maker, version, or support: a package
that cannot name itself honestly does not get packed.

`tamper` copies a packed feather and flips one byte of the
program, leaving the card — checksum and all — exactly as it
was. The result is a feather whose program no longer matches
its card, which the kernel's handler must refuse and not run:
TAMPERED.FEATHER exists to walk that road on purpose, the way
BAD.BIN exists to walk the wall's.

The checksum is an integrity check — it catches damage and
alteration after packing. It is not a signature: anyone can
recompute it, and the format says so in its document.
"""

import sys

MAGIC = b"CARDNULL FEATHER 1"
REQUIRED_KEYS = (b"title", b"maker", b"version", b"support")
SEPARATOR = b"---"
FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3
MASK64 = (1 << 64) - 1


def fnv1a64(data):
    """FNV-1a, 64-bit: the feather checksum, as the kernel
    reckons it — the same numbers, in the same order."""
    h = FNV_OFFSET
    for byte in data:
        h ^= byte
        h = (h * FNV_PRIME) & MASK64
    return h


def card_lines(card_bytes):
    """The card as a list of lines, newlines stripped, with the
    file's own trailing newline forgiven."""
    lines = card_bytes.split(b"\n")
    while lines and lines[-1] == b"":
        lines.pop()
    return lines


def find_program_offset(data):
    """The byte where the program begins: just past the
    separator line's newline. None when there is none."""
    pos = 0
    while pos < len(data):
        end = data.find(b"\n", pos)
        if end == -1:
            line, next_pos = data[pos:], len(data)
        else:
            line, next_pos = data[pos:end], end + 1
        if line == SEPARATOR:
            return next_pos
        pos = next_pos
    return None


def pack(card_path, program_path, out_path):
    with open(card_path, "rb") as f:
        card = f.read()
    with open(program_path, "rb") as f:
        program = f.read()
    lines = card_lines(card)
    if not lines or lines[0] != MAGIC:
        sys.exit("pack-feather: the card does not open with "
                 "the magic line 'CARDNULL FEATHER 1'")
    keys = set()
    for line in lines[1:]:
        if b":" in line:
            keys.add(line.split(b":", 1)[0].strip().lower())
    missing = [k.decode() for k in REQUIRED_KEYS if k not in keys]
    if missing:
        sys.exit("pack-feather: the card is missing: "
                 + ", ".join(missing))
    if not program:
        sys.exit("pack-feather: the program is empty")
    out = bytearray()
    for line in lines:
        out += line + b"\n"
    out += b"program-size: %d\n" % len(program)
    out += b"program-fnva: %016x\n" % fnv1a64(program)
    out += SEPARATOR + b"\n"
    out += program
    with open(out_path, "wb") as f:
        f.write(out)
    print("packed %s: card %d bytes, program %d bytes, "
          "fnv1a64 %016x" % (out_path, len(out) - len(program),
                             len(program), fnv1a64(program)))


def tamper(in_path, out_path):
    with open(in_path, "rb") as f:
        data = bytearray(f.read())
    offset = find_program_offset(bytes(data))
    if offset is None or offset >= len(data):
        sys.exit("pack-feather: no program found to tamper with")
    at = offset + min(5, len(data) - offset - 1)
    data[at] ^= 0xFF
    with open(out_path, "wb") as f:
        f.write(data)
    print("tampered %s: flipped the program byte at %d; "
          "the card's checksum now lies" % (out_path, at))


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "pack":
        pack(sys.argv[2], sys.argv[3], sys.argv[4])
    elif len(sys.argv) == 4 and sys.argv[1] == "tamper":
        tamper(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
