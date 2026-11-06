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
   the CD first (or press Esc at the SeaBIOS screen and choose the
   CD-ROM).
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
cleared the screen, wrote the banner into the VGA text buffer, and
opened a prompt. Click into the machine's window and type — the whole
keyboard answers: letters, digits, punctuation, Shift and Caps Lock
for capitals, Backspace to take back what you typed (never the
prompt). Fill the screen and it scrolls, like any terminal.

Press Enter and the prompt answers. Four commands, for now:

- `help` — the list of commands
- `about` — what Cardnull OS is
- `verse` — John 1:1, in the Douay-Rheims wording
- `clear` — a clean screen and a fresh prompt

Commands are matched kindly: capitals or lowercase, stray spaces at
the ends forgiven. Anything else is answered plainly as unknown. (The
UTM settings, settled milestone 2: UEFI boot off, Force PS/2
Controller on, USB input disabled — the kernel polls the PS/2
keyboard; there are no interrupts yet.)

Shut the VM down whenever you like; nothing persists, nothing can break.
