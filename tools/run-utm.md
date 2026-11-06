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
```

That is the Swift kernel running: the boot floor woke the processor,
walked it into 64-bit long mode, and handed control to `kmain`, which
cleared the screen and wrote the banner into the VGA text buffer. The
machine then rests in a halt loop. There is nothing to type yet —
keyboard input is milestone 2.

Shut the VM down whenever you like; nothing persists, nothing can break.
