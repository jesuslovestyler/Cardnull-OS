# The Cardnull Bootloader

Milestones 22 and 24 (November 10, 2026). Public
domain, like everything in this tree.

## Why

Until this stone, one passenger on the disc was not
ours and not public domain: GRUB (GPL), which loaded
the kernel on both firmware doors. The Boot-Anywhere
road Tyler settled on November 9 — Cardnull boots
itself, natively, from a stick, with nothing borrowed
underneath — needs a loader of our own. This is its
first half: the UEFI door. The BIOS door is the next
stone, and booting from an installed hard disk rides
the pair together later.

## What it is

A small UEFI application in `Sources/bootloader/`:

- **`bootloader.c`** (670 lines) — the loader itself,
  in C: the floor's own tongue, built freestanding by
  clang and lld-link as a PE/COFF EFI application. No
  gnu-efi, no borrowed headers.
- **`efi.h`** (323 lines) — the firmware's shapes,
  written out by hand: the system table, the boot
  services table in its whole order, and the three
  protocols the loader speaks to (Loaded Image, Simple
  File System, Graphics Output). EFI's structures are
  small and public; the header is ours.
- **`trampoline.S`** (103 lines) — the leaving: one
  small assembly piece that steps the processor down
  out of the firmware's long mode into the state the
  kernel's `boot.S` was born expecting.

The compiled loader is 11,264 bytes. It carries the
Unlicense header like every file in the tree.

## What it does, in order

It signs its work first — a loader should:

    Cardnull Bootloader
    Cardnull OS behind the UEFI door, loaded by our own hand.

Then, by Boot Services alone:

1. The watchdog is quieted (five minutes is the
   firmware's patience; the handover takes the time it
   takes).
2. From its own Loaded Image it takes the device
   handle, opens the Simple File System of the volume
   it was itself loaded from, and reads
   `\BOOT\KERNEL.BIN` — the kernel file off the disc,
   the very file GRUB loads, present in the boot
   volume beside the loader.
3. The kernel's ELF program headers are read; the span
   they cover is claimed page by page at its own
   addresses (nothing may already stand there), each
   segment copied to its physical address and its
   unwritten tail — the bss — zeroed honestly.
4. The screen is chosen through the Graphics Output
   Protocol: exactly 1280×800 if the firmware offers
   it, else the current mode if the kernel can draw on
   it, else the first that serves — and SetMode only
   when the choice differs from the standing one.
5. The Multiboot2 information is built (below).
6. The firmware's memory map is fetched and
   ExitBootServices taken, in the retry the contract
   demands (leaving can change the map; the map's key
   must be the latest when the door closes).
7. The trampoline: interrupts off; our own small GDT;
   a far return into compatibility mode; the segment
   registers set; paging, write-protect, long mode,
   and PAE each switched off in their turn; a known
   stack at 0x90000; then the jump — **EAX holding the
   Multiboot2 magic 0x36d76289, EBX the information's
   address**, paging off and flat segments everywhere,
   exactly the state `boot.S` has expected at every
   boot since milestone 1. The kernel builds its own
   tables from there, as it always has.

Any failure along the way stops in plain words on the
screen — what was being attempted, the firmware's own
status word, and "Nothing was handed over. The machine
rests." A loader that cannot tell the truth about a
stop has no business starting anything.

## The information it builds

The kernel read exactly two Multiboot2 tags when this
loader was first written, so the loader built exactly
two. Milestone 23 taught the kernel a third — the
module tag — and the loader grew the one errand with
it, no more:

- **Tag 8, the framebuffer** (40 bytes): the chosen
  mode's address, pitch *in bytes*, width, height,
  bits per pixel, direct-color type, and the red,
  green, and blue channel positions and sizes reckoned
  from the mode's own masks.
- **Tag 3, the module** (32 bytes, since milestone
  23): the file bundle's span — its start and end as
  the loader claimed and filled them — and the naming
  string `FILES.BUNDLE`, the same shape GRUB's
  `module2` leaves behind on the doors GRUB keeps. It
  stands between the framebuffer tag and the memory
  map tag when a bundle rode, and is absent when none
  did: the loader reads `\BOOT\FILES.BUNDLE` from
  beside the kernel into pages it claims as its own
  data, and each failure on that road — the file not
  on the volume, no room for it, a reading cut short —
  is spoken plainly ("The file bundle did not ride:
  ...") and the boot goes on without one. The bundle
  is cargo, not a condition; the kernel proves it
  before serving a byte of it, and falls back to the
  disc when it does not prove (docs/BUNDLE.md).
- **Tag 6, the memory map**: 24-byte entries translated
  one by one from the firmware's descriptors —
  conventional, loader, boot-services, and persistent
  memory as *available*; ACPI reclaim and NVS under
  their own kinds; the unusable named so; everything
  else reserved. Entries are written as the firmware
  confessed them (its order, its regions, nothing
  merged or invented), and if the map ever outgrew the
  keeping made for it, the loader would stop and say
  so rather than hand the kernel a shortened world.

## The screen reckoning — a lesson kept

The pixel's whole span counts, reserved byte and all.
The bench firmware's screen is BlueGreenRedReserved —
32 bits to a pixel by definition — but the loader's
first reckoning counted only the color channels,
called it 24, and handed the kernel a pitch of 3840
against the screen's true 5120. The desktop came up
squeezed and tiled, three quarters painted. The
loader's own sign-on named the fault — "Screen: 1280
by 800, 24 bits to a pixel" — and the fix counts the
reserved mask with the colors, on mask-described modes
and named formats alike. GRUB, reading the same word
whole, never erred; now neither do we.

The bench truth, November 10, 2026: the mode taken was
**1280×800 at 32 bits**, pitch 5120, framebuffer at
0x80000000 — the desktop's own shape, the one every
witnessed boot has used. On other firmware the loader
takes what is honestly offered and the report of a
boot should name what it took; it prefers 1280×800
exactly and never invents a mode the firmware did not
offer.

## The ownboot image

`tools/build-ownboot-iso.sh` builds the standard image
first (it must always stand), then builds a second,
`dist/cardnull-ownboot.iso`: the same tree, modified in
exactly these places —

- `/efi.img` is an EFI system image packed by mtools
  holding three files and nothing else: our loader at
  `\EFI\BOOT\BOOTX64.EFI`, `\BOOT\KERNEL.BIN`, the
  same kernel bytes the disc's own copy carries, and
  — since milestone 23 — `\BOOT\FILES.BUNDLE`, the
  file bundle, the same bytes the standard image lays
  in its `/boot` for GRUB's `module2`.
- `/efi/boot/bootx64.efi` and the Mac-blessed
  `/System/Library/CoreServices/boot.efi` — the two
  places GRUB's binary also stands in the tree — are
  our loader as well.
- `/boot/grub/x86_64-efi/` is struck: those modules
  served only GRUB's UEFI path.

— and written fresh with the El Torito parameters
grub-mkrescue itself used, read off the standard image
before this stone began: the BIOS image is GRUB's
eltorito.img with its boot-info patches, the UEFI
image is `/efi.img`, a plain protective MBR stands,
and the GPT is written fresh and true (its EFI
partition standing exactly where the catalog puts the
ESP). The image is written at ISO 9660 level 3, the
standard's own naming — a strict build truncates
TERM.FEATHER to TERM.FEA, and the kernel, matching
the plain fields, honestly answers "Not on the disc."

Why fresh, and not a patch of the standard image in
place? The bench taught that too, twice over: xorriso
keeps an imported El Torito boot image bound to the
bytes it was imported with — swap the file and the
firmware still boots the old ESP — and the standard
image's hybrid maps describe the standard's layout, so
kept into a changed tree they do not describe anything
that exists. Building the pair of maps openly makes
every one of them describe *this* disc.

What the fresh build does not re-create: the standard
image's HFS+ blessing for old Macs, and its
GRUB-stamped hybrid MBR boot code. The ownboot image
is a CD image; a stick that boots by partition tables
rides the stick stones, when the whole road — loader
included — is ours. (Since milestone 23 the image's
ISO tree also carries `/boot/files.bundle` and its
GRUB configuration a `module2` line, because the
ownboot image's BIOS door is GRUB's and GRUB carries
the bundle there the same way it does on the standard
image; the UEFI door's copy of the bundle rides in
the ESP, as the section above tells.)

**The doors, stated plainly** (as milestone 22 left
them). Standard image: GRUB behind both doors,
unchanged. Ownboot image: the UEFI door is ours; the
BIOS door is still GRUB's. Mixed doors are a waypoint,
not a claim. Milestone 24, below, finished the road:
both doors of both images are ours now, and this
section stands as the waypoint's record.

## Proof

QEMU with OVMF (the UEFI door all UTM-shape proofs
use), UTM's machine shape, 512 MB, November 10, 2026:
the ownboot image boots to the desktop whole;
`verse`; `mem` — 129,475 frames total, 1,552 used,
against the standard image's 1,551 in the same session
shape, one frame of loader keeping and the map
otherwise the same in kind; `sound` — the Doxology
phrase printed and measured in the captured audio;
TERM.FEATHER — its card read off *this* disc, its
face standing on the door's services alone, `verse`
answered inside it, a clean exit home; `net` — the
network answering with an offered address; `disk` —
reading the hard disk milestone 21 installed, its 14
files standing. The ESP's inventory is two files
(loader 11,264 bytes; kernel 228,384), and GRUB's EFI
binary appears nowhere in the image — proven by byte
search. The standard image, rebuilt in the same run,
boots as ever. Tyler's UTM run is, as always, the
final witness; it rides his word.

Milestone 23 grew the loader by the one errand: the
bundle. The loader stands at 12,800 bytes now; its
sign-on speaks the new line — "The file bundle rides
in memory: 7147 bytes." — and the ESP's inventory is
three files (loader 12,800 bytes; kernel 242,552;
bundle 7,147). The bench witnessed the bundle riding
behind this door (the kernel's `about` naming memory
as the files' home, a feather painting from it), and
then the same image attached the way a stick
attaches — USB mass storage on the bench's xHCI
controller, one hard disk beside it, no CD device in
the machine at all — and the whole system lived off
the bundle this loader carried in: files listed and
read, feathers running, and the bundle itself copied
onto the hard disk by `install`. The loader's part in
that boot is exactly the module tag; the kernel's
proving and serving are docs/BUNDLE.md's story.

## The BIOS door (milestone 24)

The other half of the road, laid the same day: behind
the BIOS door, GRUB is replaced by a boot chain of
our own, in both images. It is three pieces in
`Sources/bootloader/`, beside the UEFI loader:

- **`biosboot.S`** (222 lines) — the boot sector:
  exactly 512 bytes of hand assembly, and it lives
  twice in every image. As the El Torito boot image
  file `/BOOT/BIOSBOOT.IMG`, its first 2 KiB are what
  the BIOS loads at 0x7C00 from a CD; xorriso's
  `-boot-info-table` patches the El Torito boot
  information table at its bytes 8..63 with the file's
  place on the disc. And as the image's master boot
  record, written there after the burn by
  `tools/patch-mbr.py` — the same sector, the same
  patched table, over the protective MBR xorriso lays
  down, its partition table and the GPT untouched —
  so a stick carrying the image boots the identical
  bytes through the MBR door. The sector learns the
  boot drive from DL, learns the drive's sector size
  from the drive itself (EDD's parameter word), reads
  the whole boot image — itself and the second stage
  behind it — off the disc in 16 KiB packet reads,
  and steps into the stage at 0x7E00. The sector-size
  word is the chain's one piece of diplomacy: every
  later read is reckoned in ISO sectors and translated
  through that multiplier, so a CD's 2048-byte sector
  and a stick's 512 are the same road at two widths.
- **`biosentry.S`** (354 lines) — the second stage's
  skin: its entry hand, the BIOS thunks (teletype,
  EDD read, one E820 step, one VESA call — each taking
  its errand from globals and leaving its answer
  there), the two protected-mode hands that copy and
  zero anywhere in the first 4 GiB, and `go_kernel`,
  the handoff.
- **`biosmain.c`** (766 lines) — the stage's mind, in
  C compiled for the 16-bit world (`-m16`): the
  memory map by E820, the ISO9660 walk, the ELF
  laying, the VESA choosing, the information's
  building, in that signed order.

The compiled boot image is 11,558 bytes: the sector
and an 11,046-byte second stage, which must end below
0x10000 — its buffers are offsets under segment zero,
and the build holds it to that line.

### What it does, in order

It signs its work, as the other door's loader does:

    Cardnull Bootloader
    Cardnull OS behind the BIOS door, loaded by our own hand.
    Memory map: 9 regions, by the machine's own E820 word.
    The kernel is in hand: 242552 bytes, read from the boot disc, laid at 1 MiB.
    The file bundle rides in memory: 7147 bytes.
    Screen: 1280 by 800, 32 bits to a pixel.

1. **The memory map first** (int 15h, EAX=E820), while
   the text screen still stands to confess a failure:
   the whole walk gathered into the stage's keeping,
   the types to be translated when the information is
   built. The sector-size multiplier from the boot
   sector rides along in a byte the entry hand gathers.
2. **The disc's tree** (int 13h AH=42h): the primary
   volume descriptor at sector 16, the root, the BOOT
   directory, and the two files the stage exists for —
   `KERNEL.BIN`, and `FILES.BUNDLE` beside it when the
   disc carries one. The names are matched in the
   plain ISO9660 fields, the `;1` forgiven, exactly
   the kernel's own reading of the same tree.
3. **The laying**: the kernel file is staged below a
   mebibyte, its ELF program headers read, and each
   segment copied to its physical address and its
   unwritten tail zeroed — the copies and zeroings
   past a mebibyte done by the protected-mode hands,
   which step up alone (interrupts off, a small GDT of
   our own, one `rep movsb`) and step back down to the
   same real-mode room. The bundle, when one rides, is
   laid right behind the kernel's span. The BIOS is
   only ever spoken to as a plain real-mode caller:
   segments zero, buffers it can reckon.
4. **The screen** through VESA VBE: the mode list
   walked, a direct-color flat-field mode of at least
   640 by 200 at 24 or 32 bits required, and 1280 by
   800 at 32 preferred by name — the desktop's own
   shape, and the mode GRUB chose on this door before
   us. The chosen mode is then asked its facts once,
   and the tag keeps exactly what it answered.
5. **The information** — the same three tags the UEFI
   loader builds, no more: the framebuffer tag from
   the chosen mode, the module tag naming the bundle's
   span when one rode, the memory map tag translated
   region for region from E820 (available stays
   available; the ACPI kinds keep their numbers; all
   else is reserved), and the end tag.
6. **The handoff**, through `go_kernel`: a flat 32-bit
   GDT, protected mode entered, data segments seated,
   a scratch stack, EAX the Multiboot2 magic, EBX the
   information's address, and a jump to the kernel's
   entry — the doorstep `boot.S` was written for, the
   same one GRUB and the UEFI trampoline deliver.

**The contract held: the kernel did not change by one
line.** `boot.S` reads EBX, builds its own tables,
and wakes; nothing in the floor moved either.

### Failure, spoken

A road that fails stops the chain where it stands,
with the reason in plain words on the text screen and
the machine resting: no packet reads on the drive,
an empty boot table, a failed read (the sector's
three); no memory map, an unreadable or unconfessed
disc, a missing or misshapen kernel, no screen the
kernel can draw on (the stage's). A missing bundle is
not among them: the stage says the bundle did not
ride, and the boot goes on without one — cargo, not
a condition, as behind the other door.

### The images, now

Both images are written by `tools/build-iso.sh`'s
explicit El Torito pair (xorriso): our boot image
behind the BIOS entry, our ESP behind the UEFI entry,
a plain protective MBR and a true GPT — and then the
patcher lays our sector in the MBR. The ownboot image
is a second pressing of the same staging
(`tools/build-ownboot-iso.sh`). What the new standard
build no longer carries, stated plainly: the old
image's HFS+ blessing for pre-2012 Mac firmware and
the in-tree `/EFI/BOOT` copy of the loader — furniture
the ownboot image has lived without since milestone
22. A byte search of both finished images for GRUB —
the name, its error strings, its module trees, its
signatures — finds nothing at all. The images stand
at 3,651,584 bytes each; most of the old 12 MB bulk
was GRUB's furniture.

### Proof

QEMU with SeaBIOS, the bench's shapes, November 10,
2026. The standard image behind the BIOS door, the
full walk: the loader's sign-on caught in the text
memory it flashes through ("Memory map: 9 regions");
the desktop at 1280 by 800; `about` — "Files:
carried in memory - 13 files in the bundle"; `mem` —
130,942 frames total, 129,387 free, 1,555 used at
512 MB, the allocator's self-test passed; `ls` and
`cat` served from memory; TERM.FEATHER run from
memory and exited clean; `net` — the filter-dump
holds exactly one DISCOVER and its OFFER, xid
matched; `sound` — the Doxology measured in the
captured audio, all eight notes at their true
frequencies; `disk` — the milestone-21 disk read,
its 14 files standing. The ownboot image behind the
BIOS door — its first BIOS boot ever — the same
desktop, bundle, and TERM. The stick shape behind
SeaBIOS: the standard image as USB mass storage, a
fresh hard disk, no CD device anywhere — booted
through the MBR copy of the sector, the whole system
living off the bundle in memory, FACE and TERM run
from it, the Files window listing it, and `install`
copying the bundle onto the disk: 14 files, `dls`
whole (`mem` on that door: 130,941 total, 1,555
used — the stick's map differs from the disc's by a
frame, and the figure says so). And the regression
spot-checks: both images behind the UEFI door,
desktops rising and `about` naming the bundle, the
wiring change having broken nothing. Tyler's UTM run
is, as always, the final witness.

## Booting from an installed disk (milestone 28)

November 11, 2026: the chain this document built
learned its second road. A hard disk prepared by the
kernel's `bootable` command (the shape is defined in
docs/DISK.md) carries this same chain at its head —
our MBR at sector 0, the boot image at sector 4, and
the CARDNULL DISK 1 filesystem behind its partition
at sector 2048 — and SeaBIOS, booting the disk,
hands the machine to the MBR copy of the boot
sector exactly as it does from a stick carrying an
image. The second stage grew for the road:
`biosmain.c` is 962 lines now (766 at milestone 24).

The stage tells a disc from a disk by one probe,
made after the memory map is gathered:

1. **Sector 16 is read and asked for CD001.** On a
   CD — or a stick carrying the ISO image — the
   primary volume descriptor stands at sector 16
   and confesses CD001 at its bytes 1–5, with the
   descriptor's kind byte 1 at byte 0. Standing
   there, the ISO road runs **unchanged in every
   behaviour**: the ISO9660 walk to the BOOT
   directory, KERNEL.BIN and FILES.BUNDLE found in
   the disc's tree, read in the disc's own
   sector width.
2. **Anything else is taken for a prepared hard
   disk**, and the walk is the disk's own: the MBR
   at sector 0 is read and its table searched for
   the Cardnull partition (an entry of type 0xCA);
   the sector that entry names is read and must
   confess the **CARDNULL DISK 1** superblock; then
   the filesystem's flat directory — sixteen sectors
   of 64-byte entries behind the superblock — is
   walked in the disk's native 512-byte sectors for
   KERNEL.BIN and FILES.BUNDLE, their entries' first
   sectors reckoned from the partition's start.
   A disk with no Cardnull partition, a partition
   that does not confess itself, or no KERNEL.BIN
   standing in it stops the loader where it stands,
   in plain words, and nothing is handed over.

Everything downstream of the finding is one road
again: the kernel file staged, its ELF segments
laid at 1 MiB, the bundle laid right behind the
kernel's span, the screen chosen by VESA VBE, the
same Multiboot2 information built, the same
handoff. Only the reading hand and the sign-on's
one word differ — the disk road reads by raw
512-byte sectors with no ISO multiplier, and the
loader signs it so:

    The kernel is in hand: 281248 bytes, read from the boot disk, laid at 1 MiB.
    The file bundle rides in memory: 7680 bytes.

("boot disc" on the ISO road; "boot disk" here.)
The bundle's absence is cargo, not a condition, on
this road too: its pointers simply stay zero and
the boot goes on without one.

The bench proved the road whole: a prepared disk
booted with **no CD device in the machine at all** —
the sign-on above, the desktop, the disk's own
sixteen files listed and read, the bundle serving
from memory, a file saved on that boot read back
word for word after a cold reboot — and the ISO
road's regressions stood beside it, the ownboot
image behind SeaBIOS and the standard image behind
UEFI exactly as before. The scope is the stone's
own, stated plainly: **the BIOS door only**.
Booting an installed disk behind the UEFI door —
our UEFI loader learning the disk's shape as this
stage has — is not yet.

## The next stone

Neither door of any Cardnull image owes anything to
GRUB now; the bootloader pair is complete, and the
bundle rides behind both doors (docs/BUNDLE.md).
What the pair made possible was the stick road
itself: an image a stick can carry that boots
natively — proven at milestone 24 — and, since
milestone 28 above, booting from an installed hard
disk behind the BIOS door, the installer's old
confession answered by `bootable` laying this same
chain on the disk it prepares. What still waits is
the same boot from an installed disk behind the
UEFI door, and the stick itself as a prepared,
bootable home rather than an image it carries.
