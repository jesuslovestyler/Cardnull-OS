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

Press Enter and the prompt answers. Ten commands, for now:

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

Shut the VM down whenever you like; nothing persists, nothing can break.
