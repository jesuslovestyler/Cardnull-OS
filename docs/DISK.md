# The Cardnull Disk Format

*Written November 10, 2026, with milestone 21 — the day the OS
learned to write. This document is the format's definition;
the kernel's hard-disk driver answers to what is written
here. The format's name is **CARDNULL DISK 1**.*

## What a Cardnull disk is

A Cardnull disk is a hard disk the OS has made its own: a
simple, flat home for files, laid out by `format` and filled
by `dsave` and `install`. It is deliberately nobody else's
format — not FAT, not ext, nothing borrowed — because it only
has to do one thing well: hold a person's files where the OS
itself put them, and give them back word for word.

It is small on purpose. There is one directory, at the root;
there are no folders, no permissions, no journals, and in
this first version **no deleting**: a name, once taken,
stands. What the format cannot do is written down below as
plainly as what it can.

## The layout

The disk is read and written in **sectors of 512 bytes** —
the size the drive itself reports, and the size `format`
refuses to proceed without. Sector numbers (LBAs) count from
0. Every multi-byte number is stored little-endian.

```
sector 0          the superblock
sectors 1..16     the directory: 128 entries, 64 bytes each
sectors 17..      file data, in unbroken runs of sectors
```

### The superblock (sector 0)

| bytes   | what stands there                                        |
|---------|----------------------------------------------------------|
| 0..14   | the signature: the fifteen letters `CARDNULL DISK 1`     |
| 15      | zero                                                     |
| 16..19  | the format version: 1                                    |
| 20..23  | the sector size: 512                                     |
| 24..31  | the disk's total sectors, as its IDENTIFY reported them  |
| 32..35  | the directory's first sector: 1                          |
| 36..39  | the directory's length in sectors: 16                    |
| 40..43  | the data area's first sector: 17                         |
| 44..47  | how many files stand (a mirror — see below)              |
| 48..51  | the next free data sector                                |
| 52..503 | zero                                                     |
| 504..511| the checksum (see below)                                 |

The **checksum** is the house's own reckoning, the same one
the feather format carries: **FNV-1a, 64-bit** — the hash
begins at 14695981039346656037 (0xCBF29CE484222325); for each
byte, the hash is XORed with the byte and then multiplied by
1099511628211 (0x100000001B3), all modulo 2^64. It is taken
over bytes 0..503 of the superblock, with the checksum field
itself standing outside the reckoning. Like the feather's,
it is an **integrity check, not a signature**: it proves the
superblock was not torn or trampled, not who wrote it.

The file count at bytes 44..47 is a *mirror*: writers keep
it true, but readers never trust it — `disk` and `dls`
count the directory's standing entries for themselves, so a
mirror that disagrees with the directory is a curiosity,
never a lie told to the user.

### The directory (sectors 1..16)

128 entries of 64 bytes, in no promised order:

| bytes    | what stands there                                      |
|----------|--------------------------------------------------------|
| 0        | 1 if the entry stands; 0 if the slot is empty          |
| 1..31    | the name: up to 31 letters; the rest stands zero       |
| 32..35   | the file's first sector                                |
| 36..39   | the file's length, in bytes                            |
| 40..63   | zero                                                   |

A name is at
most 31 letters — letters, digits, `.`, `-` and `_` — and is
never `.` or `..`. Names are compared without caring about
case, and a name once standing is **never reused**: there is
no overwrite and no delete in this version, so a second
`dsave` under a standing name is refused in plain words.

### File data (sectors 17..)

Each file's bytes stand in one unbroken run of whole
sectors, beginning where the superblock's next-free pointer
stood when the file was written; the pointer then advances
past the run. Nothing is ever moved or compacted, and a
freed run — there are none, there being no delete — would
not be reclaimed. What `dsave` can write is bounded by the
shell's own line: a name and words up to the line's reach,
so a `dsave` file is at most a few hundred bytes and always
fits within one sector's content, though the run is counted
in whole sectors. `install` copies files of any size the
disc carries, a sector at a time, in runs of as many sectors
as each file needs.

## The order of a writing

A file is written so the disk never claims what is not
there:

1. the file's **data** sectors are written;
2. the **directory entry** is written;
3. the **superblock** is written last — its next-free
   pointer and count now covering the new file — and the
   drive is told to **flush** its cache.

If a writing fails partway, the superblock is rewritten to
the standing it had before the attempt whenever it can be,
so the disk keeps the truth it had. `format` follows the
same law: the directory's sixteen sectors are zeroed first,
and the superblock — the disk's birth certificate — is
written **last**, so an interrupted format leaves a disk
that honestly reads as *not a Cardnull disk yet*, never a
half-made one. `format` claims success only after reading
the superblock back and finding it standing.

## How a disk is judged

Every disk command reads sector 0 afresh and judges it:

- **absent** — no hard disk answered its IDENTIFY: *"No
  hard disk is attached."*
- **silent** — a disk is attached but its first sector
  cannot be read: reported as damaged ground, never guessed
  at.
- **blank** — sector 0 reads as all zeros: *"It is blank:
  nothing on it is Cardnull's yet."*
- **foreign** — sector 0 carries something that is not
  Cardnull's signature: *"not a Cardnull disk yet"* — the
  bytes are never interpreted.
- **damaged** — the signature stands but the version, the
  checksum, or the geometry disagree with the disk's own
  IDENTIFY: reported as damaged, in plain words.
- **ready** — signature, version, checksum, and geometry
  all agree: a Cardnull disk, whose files may be listed,
  read, and added to.

## The road the bytes travel

The hard disk is spoken to through the machine's **AHCI**
controller — the same controller milestone 8 found for the
CD — as a plain ATA disk (never a packet device), by DMA:
READ DMA EXT / WRITE DMA EXT (0x25 / 0x35) when the disk's
reach passes the 28-bit line, the classic forms (0xC8 /
0xCA) below it, FLUSH CACHE after makings. The CD's ATAPI
path is untouched and has **no write road at all**: no code
in the kernel can write to the CD, and `format` and
`install` say so on screen before they ask for their word.

## The bounds, stated

- 128 files at most; a name at most 31 letters.
- No folders, no delete, no overwrite, no renaming.
- One unbroken run per file; the disk fills from sector 17
  upward and does not compact.
- `dsave` writes text the shell was handed — small files
  only; `install` copies whole files of any size.
- The format is version 1. A later version will be a new
  signature and its own document, never a quiet change to
  this one.
