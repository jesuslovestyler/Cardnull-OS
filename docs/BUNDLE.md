# The Bundle Format

*Written November 10, 2026, with milestone 23 — the day the
kernel learned to carry its files in memory. This document is
the format's definition; the packer (tools/pack-bundle.py),
both bootloaders' loading of it, and the kernel's proving and
serving of it all answer to what is written here.*

## What a bundle is

A **bundle** is one file carrying the system's own files —
the welcome, every guest program, every feather: the very
set the disc's root holds for the system itself. It exists
because of a plain fact Tyler settled on November 9, 2026:
a stick is not a CD. A machine booted from a stick has no
disc for the kernel's disc reader to read, so the files must
ride in memory, handed over by the bootloader as one
Multiboot2 module — GRUB's `module2` behind the doors GRUB
still keeps, and Cardnull's own loader behind the UEFI door
it took at milestone 22.

The bundle is a passenger, never the only copy of anything:
the same files stand loose on the disc beside it, and when
no bundle rides — or one rides and does not prove sound —
the disc serves them exactly as it has since milestone 8.

## The layout

Byte for byte, in order:

```
CARDNULL FILES 1
files: 13
bytes: 6884
checksum: c88e88b9377a087e
WELCOME.TXT 300
HELLO.BIN 234
...
TERM.FEATHER 2739
---
<the files' bytes, in table order, and nothing after>
```

- **The magic line.** The file's first line is exactly
  `CARDNULL FILES 1` — the format's name and its version.
- **The three reckoned lines.** `files:` counts the table's
  entries; `bytes:` counts the whole payload; `checksum:`
  carries the payload's FNV-1a 64 checksum (below), sixteen
  lowercase hex digits, both reckoned by the packer from the
  real bytes as it packs.
- **The entry table.** One line per file: its name, one
  space, its byte length. A file's place in the payload is
  the sum of the lengths before it — offsets are counted,
  never written, so the table cannot disagree with itself
  about where a file stands.
- **The separator.** A line of exactly three dashes, `---`.
  The payload begins at the byte after its newline.
- **The payload.** The files themselves, concatenated in
  table order, and the bundle ends exactly at the payload's
  end: a bundle carrying anything after its payload, or
  ending before it, does not prove.

Lines end with a single line feed (0x0A). Names are the
disc's own kind: printable letters without a space (the
table's separator) and without a slash (the path's) — one
flat root, no directories, because the system's own files
have always stood at the root.

## The caps, stated plainly

- at most **64 files** in the table;
- a name of at most **31 letters**;
- one file of at most **1 MiB**;
- the whole payload of at most **16 MiB**.

The packer holds the build to the same measures the kernel
proves by, so a bundle the build can pack is a bundle the
kernel can judge — and anything past the caps is refused by
one or the other, never silently trimmed.

## The checksum, and what it is not

The checksum is **FNV-1a, 64-bit** — the house reckoning,
the same offset and prime the feather's card carries —
folded over the whole payload. It is an **integrity check**:
it catches damage and alteration after packing. It is
**not a signature**: anyone can recompute it, so it proves
only that the payload matches the header's word, never who
packed it. Nothing in this format claims otherwise.

## How the kernel receives it

1. **The span is reserved.** The bootloader reports the
   bundle's physical span in a Multiboot2 module tag (type
   3). The kernel notes the span before its frame allocator
   is raised and reserves it out of the free pool: the
   cargo is not the yard. The frames stand in `mem`'s used
   count and are never handed to the heap or a guest.
2. **The bundle is proven at boot**, before a byte of it is
   served: the magic line; the three reckoned lines in
   their shapes and caps; the table (every name a plain
   name within its cap, every length within its cap, the
   lengths summing exactly to the declared payload); the
   payload ending exactly at the span's end; and the
   checksum, folded over the whole payload and matched
   against the header's word. A bundle that fails any of
   it is reported in the boot transcript in plain words —
   and never served from.
3. **The serving rule.** A valid bundle rides, the bundle
   serves: `ls`, `cat`, `run`, `both`, `feather`, the Files
   window's list and its Reader, and the installer's copies
   all read from memory. No bundle, or an unsound one, and
   the disc path serves, unchanged in every behavior. The
   hard disk's world is its own: `disk`, `dls`, `dcat`,
   `dsave`, `format` never read the bundle.
4. **The source is spoken plainly.** The boot transcript
   and `about` carry the one true sentence: "Files: carried
   in memory - N files in the bundle." when the bundle
   serves, "Files: read from the disc." when it does not.

## How the build keeps the promise

The bundle is assembled by tools/pack-bundle.py from the
ISO staging itself — the very files tools/build-iso.sh has
just copied to the disc's root — so bundle and disc are two
carryings of one set, not two sets kept in step by care.
The packer guards the agreement both ways: a manifest file
missing from the staging refuses the packing, and so does a
system file standing in the staging that the manifest does
not name. If a future milestone adds a system file, it adds
a manifest line in the same commit, or the build stops and
says why.
