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
stood. Milestone 30 gave the disk manners — rename, copy,
and delete — and the amendment near the end of this
document says exactly what changed and what did not. What
the format cannot do is written down below as plainly as
what it can.

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

These sector numbers are **home-relative** (milestone 28):
they count from the filesystem's home, not always from the
disk's own sector 0. On a plain disk the home is the disk's
sector 0, exactly as this format was first laid. On a
**bootable** disk the home is sector 2048, named by the
disk's partition entry, and the disk's head carries the
boot chain instead — see "The bootable shape" below. Every
reckoning in this document — the superblock, the directory,
the data area, a file's first sector — is made from the
home, so the superblock is sector 0 *of its home* wherever
the home stands.

### The superblock (sector 0 of its home)

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
case. While a name stands it is **never reused** and never
overwritten: there is no overwrite in this format, so a
second `dsave` under a standing name is refused in plain
words. What can free a name — a rename, a delete — is
milestone 30's amendment below.

### File data (sectors 17..)

Each file's bytes stand in one unbroken run of whole
sectors, beginning where the superblock's next-free pointer
stood when the file was written; the pointer then advances
past the run. Nothing is ever moved or compacted, and a
freed run is **not reclaimed**: since milestone 30 a file
can be deleted, and its run then stands unread on the
platter, its bytes untouched, until a `format` — the
next-free pointer never walks backward. What `dsave` can write is bounded by the
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

Every disk command reads the home's first sector afresh
and judges it. The home is found first: a Cardnull
partition entry (type 0xCA) in the disk's MBR names a
home at its start sector; without one, the home is the
disk's sector 0.

- **absent** — no hard disk answered its IDENTIFY: *"No
  hard disk is attached."*
- **silent** — a disk is attached but its first sector
  cannot be read: reported as damaged ground, never guessed
  at.
- **blank** — the home's first sector reads as all zeros:
  *"It is blank: nothing on it is Cardnull's yet."*
- **foreign** — the home's first sector carries something
  that is not Cardnull's signature: *"not a Cardnull disk
  yet"* — the bytes are never interpreted.
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

## The bootable shape (milestone 28)

*Amendment, November 11, 2026.* A disk that `install` has
planted Cardnull on can be **prepared** by the Terminal
command `bootable` — behind a typed confirmation, the
word **bootable** — to start the computer by itself
behind the BIOS door. Preparation changes the disk's
head, and only its head; the filesystem itself moves
whole and byte for byte. In absolute disk sectors:

```
sector 0          our MBR: the boot sector's code, one
                  partition entry, the 0x55AA tail
sectors 4..       BIOSBOOT.IMG, the boot image, laid
                  whole (14,150 bytes today)
sector 2048       the filesystem's home: the superblock
                  stands here, and every sector number
                  in this format counts from here
```

- **The partition entry** is the MBR table's first (and
  only) entry: status **0x80** (boot-flagged), type
  **0xCA**, start **2048**, count the disk's total
  sectors less 2048 (1,046,528 on the bench's disk).
  The rest of the table's ground stands zeroed.
- **The boot image** stands at sector **4**, with its
  El Torito boot-info table patched for this home
  before it is written: the word at offset **12**
  becomes **1** — sector 4 reckoned in the table's
  2048-byte units — and the word at offset **16**
  names the image's whole length (14,150 bytes;
  on the bench, the laid image differed from the
  ISO's BIOSBOOT.IMG at only bytes 12–13).
- **The MBR is written last.** The filesystem migrates
  first (copied top down, so the copy never overwrites
  ground it has not read yet), the image is laid next,
  and only then is sector 0 written and the disk
  flushed — the moment the MBR stands, the disk claims
  to boot, and it must already be whole. Success is
  claimed only when the disk, judged fresh, answers
  ready and prepared with the same files standing.
- **Every refusal precedes any write:** no disk, a
  disk that is not Cardnull's yet, a disk already
  prepared, no room to move its files behind the
  partition, or no sound boot image on the disc — and
  a wrong word at the gate writes nothing at all.
- **Living on a prepared disk:** the kernel locates
  the filesystem at the partition's start (the
  home-relative rule above), and `format` on a
  bootable disk reformats **inside the partition** —
  the MBR, the boot image, and the partition entry
  are not touched, and the disk stays bootable.
  `disk` adds one plain line for such a disk: *"It
  can start the computer by itself."*

The scope is stated as plainly as the shape: this is
the **BIOS door only**. Booting an installed disk
behind the UEFI door is not yet.

## Files with manners (milestone 30)

*Amendment, November 12, 2026.* Three Terminal commands
joined the disk family — the family is ten now:
`rename OLD NEW`, `copy SOURCE NEW`, and `delete NAME`.
**The format did not change** — no byte of the layout
above moved, and version 1 stands. What changed is two
rules this document first stated: a name once standing
can now be freed, and a file can be removed. This
amendment supersedes milestone 21's "no deletion in v1",
and it says exactly how far the change reaches.

- **Rename** rewrites the file's directory entry where
  it stands — same slot, same first sector, same
  length; only the name changes. The data run is not
  read, moved, or copied. The old name is free the
  moment the rename lands, and another file may take
  it at once. Renaming to the very name the file
  already has, to a name that stands, from a name that
  does not stand, or to a name the format cannot hold
  is refused in plain words before anything is written.
- **Copy** makes a second, independent file: the
  source's bytes are written to a fresh run at the
  next-free pointer, and a new entry stands for them.
  Afterwards the two files share nothing — either can
  be renamed or deleted without touching the other.
  Copy never overwrites: a destination name that
  stands is refused.
- **Delete** is gated, as `format` and `install` are
  gated: the Terminal names the file and its size,
  says plainly that nothing can bring it back, and
  demands the typed word **delete** (capitals folded,
  the whole word demanded). Anything else writes
  nothing at all. A true delete zeroes the file's 64
  directory bytes: the slot and the name are free at
  once, and the file is gone from `dls` and `dcat` for
  good — across a cold reboot, proven. **Its data run
  is not reclaimed.** The next-free pointer never
  walks backward, so the deleted bytes stand unread on
  the platter until a `format`, and the room `disk`
  reports does not grow when a file is deleted: on the
  bench it read 536,860,160 bytes with four files
  standing and the same 536,860,160 with two. Deleting
  is a way to remove a file, not a way to make room;
  `format` remains the only road back to an empty disk.

Each of the three writes in the standing order — for
copy, the data first, as `dsave` writes it; then the
directory entry; then the superblock; then a flush —
so a half-finished operation never leaves the disk
claiming what is not there. And every refusal precedes
any write: a session of nothing but refusals — taken
names, missing files, a wrong word at delete's gate —
left the bench disk byte-identical, hash for hash.

## The writing window and the door (milestone 31)

*Amendment, November 12, 2026.* Two more roads write
to the disk, and both keep its laws. **The format did
not change** — no byte of the layout above moved, and
version 1 stands.

- **The Write window** (the desktop's editor) saves
  under the family's rules: a fresh name is written
  exactly as `dsave` writes — data, then the directory
  entry, then the superblock, then a flush — and a
  name that stands is refused, in the window's own
  plain words. One bounded exception, stated openly:
  saving the very file the window has open writes the
  new words back into that file's own run, when they
  still fit its sectors; the entry's length is
  rewritten, the count and the next-free pointer do
  not move. A writing that has outgrown its run is
  not moved and nothing else is touched: the window
  asks for a new name instead. This is the one road
  on which a standing file's bytes change, and it
  reaches only the file's own ground.
- **The door's file services** (interrupt 0x80,
  services 10 and 11, published in docs/FEATHER.md)
  let a guest program read a named file into its
  memory and write its memory out as a named file —
  one sector, 512 bytes, at a time, refused whole
  past that bound. Writing there is creation only:
  a name that stands is refused, exactly as at the
  Terminal and in the window, because it is the same
  filesystem down all three roads — a file a feather
  writes is a file `dcat` and the editor read, and
  the other way around. Every refusal on every road
  precedes any write: on the bench, a session of
  refusals from the window and the door together
  left the disk byte-identical, hash for hash.

## The bounds, stated

- 128 files at most; a name at most 31 letters.
- No folders, no overwrite of another file. Renaming,
  copying, and deleting stand since milestone 30,
  under the amendment above; the editor's saving of
  its own open file into its own run stands since
  milestone 31, under the amendment above that.
- One unbroken run per file; the disk fills from sector 17
  of its home upward and does not compact.
- `dsave` writes text the shell was handed — small files
  only; the Write window holds one page of 8,192 bytes;
  the door carries one sector at a time; `install`
  copies whole files of any size.
- The format is version 1. A later version will be a new
  signature and its own document, never a quiet change to
  this one.
