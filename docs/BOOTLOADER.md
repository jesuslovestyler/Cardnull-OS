# The Cardnull Bootloader

Milestone 22 (November 10, 2026). Public domain, like
everything in this tree.

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

**The doors, stated plainly.** Standard image: GRUB
behind both doors, unchanged. Ownboot image: the UEFI
door is ours; the BIOS door is still GRUB's. Mixed
doors are a waypoint, not a claim.

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

## The next stone

The BIOS door: a small public-domain loader of our
own behind it too, so that one day neither door of
any Cardnull image owes anything to GRUB. The stone
this section once pointed at next — the kernel
learning to carry its files in memory — has since
landed as milestone 23: the bundle rides behind both
doors now (docs/BUNDLE.md), and with the loader and
the bundle together, the pair the stick road needs
stands ready: a stick, which is not a CD, can be a
home when its own stone comes.
