# Trying Cardnull OS in UTM

The daily drill: boot the ISO in an emulated PC, watch it speak, shut it
down. Nothing on the real machine is touched.

## What you need

- The ISO: `dist/cardnull.iso`, produced by `tools/build-iso.sh`.
  (It is built locally and never committed to git.)
- UTM on the Mac, with an **Emulate** (not Virtualize) x86-64 PC machine.
  Emulate matters: the Mac's own processor is ARM, and Cardnull OS is
  x86-64 — UTM/QEMU translates, which is exactly what we want at this
  stage.

## Steps

1. In UTM, open the x86-64 PC machine (or create one: **Create a New
   Virtual Machine → Emulate → PC**; memory 128 MB is plenty; no hard
   drive is needed yet — the OS lives entirely in the boot image).
2. Set the CD/DVD drive to `dist/cardnull.iso` (machine settings →
   Drives → the CD drive → Browse), and make sure the boot order puts
   the CD first. (Behind the BIOS door: or press Esc at the SeaBIOS
   screen and choose the CD-ROM. Behind the UEFI door — Edit → QEMU →
   **UEFI Boot** checked — the firmware finds the disc's UEFI entry
   on its own; give it some seconds on the TianoCore splash.)
3. Start the machine.

## What you should see

GRUB flashes past (its timeout is zero), and then a black screen with
one word at the top left:

```
CARDNULL

> 
```

That is the Swift kernel running: the boot floor woke the processor,
walked it into 64-bit long mode, and handed control to `kmain`, which
cleared the screen, wrote the banner, and opened a prompt. Click into the machine's window and type — the whole
keyboard answers: letters, digits, punctuation, Shift and Caps Lock
for capitals, Backspace to take back what you typed (never the
prompt). Fill the screen and it scrolls, like any terminal.

Press Enter and the prompt answers. Thirteen commands, for now:

- `help` — the list of commands
- `about` — what Cardnull OS is
- `verse` — John 1:1, in the Douay-Rheims wording
- `clear` — a clean screen and a fresh prompt
- `uptime` — how long the kernel has been awake
- `mem` — the machine's memory, counted from the bootloader's map
  (`memory` answers too)
- `heap` — the kernel heap, counted from its books
- `faulttest` — take a page fault on purpose, and hear it reported
- `ls` — what is on the disc (`ls /boot` looks inside a folder)
- `cat` — print a file from the disc: `cat /welcome.txt`
- `run` — run a program from the disc: `run /hello.bin`
- `both` — run two programs, taking turns: `both /a.bin /b.bin`
- `feather` — open a feather package and run its program:
  `feather /hello.feather`

Commands are matched kindly: capitals or lowercase, stray spaces at
the ends forgiven. Anything else is answered plainly as unknown.
Try `uptime` twice, a little while apart: the second reading is
larger by the wait — the kernel counts a 100 Hz heartbeat by
interrupt now, and rests in between instead of polling. And try
`mem`: since milestone 6 the kernel reads the memory map the
bootloader hands over and keeps a page-frame allocator over the
RAM it finds, so the answer is the machine's own numbers — usable
RAM, frames total, free, and used, with the allocator's boot
self-test verdict. The numbers differ a little between the BIOS
and UEFI doors, because the two firmwares' maps honestly differ;
both are the truth as that door's bootloader reported it. And
try `heap`: since milestone 7 the kernel keeps a heap — 4 MiB of
frames in one run, a chain of first-fit blocks inside it — and
the command speaks its books (region, bytes and blocks used and
free, and the boot self-test's verdict). Milestone 7 also moved
the kernel into page tables of its own building — it no longer
runs on the boot floor's wide borrowed map — with W^X laid in
the leaves: its code pages cannot be written, and its data
pages cannot be executed. You can witness the tables' honesty
yourself with `faulttest`: the command reaches for an address
no page covers (0xDEAD0000), the fault is reported on screen —
"Page fault - halting.", the address, and the error code in hex
and in words — and the machine halts, cleanly, without
rebooting. Restart the VM afterward; the halt is the command
working, not the machine breaking. (The UTM
settings, settled milestone 2: Force PS/2 Controller on, USB input
disabled — the keyboard is still a PS/2 device; what changed in
milestone 4 is that it speaks by IRQ1, not by being asked. And
since milestone 5 the disc boots behind either firmware: **UEFI
Boot** off is the BIOS door, on is the UEFI door — same shell,
same commands. Behind the UEFI door there is no text grid,
so the kernel draws its letters as pixels, and GRUB now sets a
graphics mode behind the BIOS door too, so the letters are drawn
there as well — possibly larger than before, depending on the
mode offered. The words are the same.)

One more thing to try since milestone 8: watch the line under
the banner as the machine boots — "Disc: QEMU DVD-ROM, AHCI
port 2." (the drive's name and port will read as UTM's drive
reports them). That is the kernel finding the very disc it
booted from and reading its table of contents. `ls` shows the
disc's root — BOOT, the EFI machinery, and WELCOME.TXT, a
greeting that lives only on the disc. `cat /welcome.txt` reads
it back, sector by sector: a welcome from Cardnull and John 1:1
in the Douay-Rheims. `cat /boot/grub/grub.cfg` reads GRUB's own
config off the same disc. Paths do not care about capitals, and
asking for what is not there is answered plainly. Reading is
all the disc gets — nothing is written, ever.

And since milestone 9, the disc carries three small programs
beside the welcome — HELLO.BIN, COUNT.BIN, BAD.BIN, which exist
only as files (see them in `ls`, with their sizes). They are
the first things this OS has ever run that are not itself.
`run /hello.bin` loads the first into ground of its own — page
tables cloned from the kernel's, the kernel's ground stamped
shut to it — and runs it in ring 3, the processor's least
privileged mode: it greets you in its own words, leaves by the
door it was given (interrupt 0x80, the one gate a guest may
knock on), and the shell reports "Program exited: 0".
`run /count.bin` reckons 1 to 10 and prints them, one to a
line — the numbers are computed in the program, not recited.
`run /bad.bin` is the proof of the wall: the program reaches
for the kernel's first byte, the reach faults, and the report
appears at the top of the screen — "Page fault in a guest
program - the guest was stopped.", the address 0x100000, and
"protection violation, user mode" — the guest is stopped, its
ground is handed back, and the shell answers the next command
as if nothing had happened (try `verse`). Unlike `faulttest`
there is nothing to restart: the halt there is the kernel's
own road, and this road was built to be survived.

And since milestone 10, the disc carries two more guests —
A.BIN and B.BIN — and the shell can keep two programs at once:
`both /a.bin /b.bin`. Each is loaded into ground of its own,
exactly as `run` loads one, and then they take turns: A prints
a token (A1), yields the machine at the same door (a third
service now, yield), and B prints B1 and yields back — A1 B1
A2 B2 down the screen. A stops after five tokens and leaves;
B, with seven, prints its last two alone. The shell reports
each ending beside its name — "/a.bin exited: 5",
"/b.bin exited: 7" (the guests leave with their counts, so
you can check the report against the tokens). The taking of
turns is cooperative: a program holds the machine until it
yields, leaves, or falls — nothing snatches it away — and two
programs is the measure, no more. The wall stands with
company in the room: try `both /bad.bin /a.bin`, and BAD is
stopped at the wall while A counts out all five of its tokens
in the same session, undisturbed, after which the shell
answers the next command as ever. When the session ends, both
guests' ground is handed back frame by frame; `mem` reads the
same numbers before a session and after it.

And since milestone 11, the disc carries two packages in the
OS's own format: HELLO.FEATHER and TAMPERED.FEATHER (see
them in `ls`, 493 bytes each). A feather is a program that
travels behind a card — plain text naming its title, its
maker, its version, and how its maker may be supported,
with the program's size and checksum reckoned by the packer
(the format is written down in `docs/FEATHER.md` in the
tree). Try `feather /hello.feather`: the shell reads the
whole file, proves the program against the card's checksum,
and prints the card first — the honest label, read before
the run — then the program greets you ("Hello! I am the
first feather Cardnull OS ever opened.") and leaves by the
same door as any guest, and the shell reports its exit. The
line beneath the card — "Integrity: checksum verified - an
integrity check, not a signature." — is the truth about the
checksum: it catches damage and alteration, and it is not
the signing the store era will bring; nothing claims
otherwise. Then try `feather /tampered.feather`: the same
package with one byte of its program flipped after packing —
the shell refuses it in plain words ("...does not match its
card's checksum - it may be damaged or altered. It was not
run.") and nothing runs. `feather /hello.bin` answers "is
not a feather", and `run /hello.feather` refuses in its
turn and sends you to `feather` — a package's card is never
executed as code. As ever, the ground a feather's program
stood on is handed back: `mem` reads the same numbers
before an opening and after it.

Shut the VM down whenever you like; nothing persists, nothing can break.
