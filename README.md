# Cardnull OS

A Catholic operating system, written from scratch in **Swift** — public domain.

Cardnull OS is the operating system of [Cardnull](https://cardnull.com), a Catholic
computer and software company founded by Tyler Austin James Kovalevich on
November 4, 2026, in Washington, North Carolina. It is being built with
Billy Miecuna.

It will run on small, honest computers — the first target is a hand-built mini,
in the shape of a Mac mini, assembled from bought parts — and it carries
[Chirpy Browser](https://github.com/jesuslovestyler/Chirpy-Browser) and the
Catholic Bible as its home software.

## Why Swift

Every mature operating system is written in C, or in Rust (Redox).
No shipping operating system is written in Swift.
We chose Swift because it is modern, memory-safe, and the language we already
build in — and because something no one has done before is worth doing carefully.
A thin layer of assembly and C sits at the very bottom, where the processor
wakes up; every operating system in any language has that floor.
Everything above it is Swift.

## Why from scratch

Public-domain operating systems exist — TempleOS above all, one man's
fifteen-year work, dedicated to the public domain. TempleOS is our teacher
and our precedent: proof that a single pair of hands can finish an operating
system and give it away. It is not our foundation. Cardnull OS has its own
kernel, written line by line, so that what we give away is truly ours to give.

## Roadmap

1. **Boot** — a Swift kernel that starts on x86-64 (tested in UTM/QEMU on a Mac)
   and writes to the screen.
2. **Speak** — keyboard in, text out; a simple shell.
   *(Done with milestone 3 — the shell answers help, about, verse,
   and clear. Milestone 4 then changed how the kernel waits:
   interrupts, a 100 Hz heartbeat, and an `uptime` command that
   reads it.)*
3. **Remember** — memory management and a filesystem.
4. **Work** — run programs; one thing at a time, then many.
5. **Dress** — a simple graphical face.
6. **Carry** — Chirpy Browser and the Catholic Bible, at home.

## Building

The build does not use Xcode's templates — Xcode is the workshop (the editor
and the Swift compiler), but the kernel is stitched together by the build
script in `tools/`, linked with a custom linker script, and tested in UTM
(emulated x86-64 PC) before it ever touches real hardware.

## License

Public domain. See [LICENSE](LICENSE) — the Unlicense.
Freely you have received; freely give. (Matthew 10:8)

## Status

Milestone 5 stands (November 6, 2026): **one ISO, two doors.** The
same disc image now boots behind UEFI firmware as well as BIOS.
The Multiboot2 header asks the bootloader for a linear framebuffer
— no particular mode, after UEFI GRUB answered an exact request
with "no suitable video mode found" — and the boot floor preserves
the Multiboot2 information pointer and hands it to the kernel,
which reads the framebuffer tag GRUB actually filled in (its
channel fields begin after a two-byte reserved field; read a byte
early and the screen paints cyan, as this kernel's first attempt
did, on both doors alike). The kernel keeps the 80x25 character
grid itself now, in storage the floor lends, and paints it through
whichever screen is live: the VGA text grid, or drawn pixels —
white glyphs on black from a public-domain 8x8 font, doubled when
the mode is roomy — with the cursor drawn as an underline where
there is no hardware cursor to move. The shell does not know which
door it came through: the same five commands answer behind both,
and behind the BIOS door GRUB now sets a graphics mode too, so the
letters there are drawn pixels as well, the text grid remaining
the fallback for a boot with no usable framebuffer. Verified in
QEMU both ways on the q35 machine: BIOS — help, verse, and the
milestone-4 regressions (Caps Lock, the apostrophe, the
backspace-repaired command) all answered; UEFI (OVMF) — verse
answered, and two `uptime` readings advanced with the wall clock
between them.

Before that, milestone 4 taught the kernel to stop asking and be
told: the boot floor carries a stub for every exception vector
and both hardware IRQs the kernel takes; support.c builds the IDT
from them, remaps the 8259 PIC pair to vectors 0x20/0x28 (clear of
the exceptions the BIOS left them sitting on), and sets the PIT
ticking at a 100 Hz heartbeat. The timer interrupt only counts;
the keyboard interrupt only takes the scancode into a small ring
buffer; and the shell — the same scrolling terminal answering the
same commands — drains the ring at its leisure and sleeps in `hlt`
between keystrokes instead of spinning on the ports. Exceptions are
no longer silent: a fault prints "Exception - halting." and rests
the machine. A fifth command joins the shell: `uptime` reads the
heartbeat and answers, e.g., "Awake 1 minute 14 seconds."

Before that, milestone 3 gave the prompt its answers: the kernel
reads the finished line straight off the screen, trims it, folds
capitals down, and answers `help`, `about` (what Cardnull OS is),
`verse` (John 1:1, Douay-Rheims), and `clear`; anything else is
answered plainly as unknown, and an empty line earns only a fresh
prompt. The keyboard is the whole main block of a US keyboard —
letters, digits, space, and every punctuation key in its plain and
shifted face — with Caps Lock latching the letters as it should,
and output past the last row scrolls the page upward. Verified in
QEMU on the q35 machine with the PS/2 keyboard present — commands
typed through the emulator's keyboard, answered on the kernel's
screen, and the two uptime readings advancing with the wall clock
between them; the same ISO is the one tested in UTM.

Not yet, honestly: memory management and a filesystem (roadmap
step 3, "Remember"); USB input — under either firmware, a
USB-only keyboard is beyond us still, which is why the UTM drill
keeps the PS/2 controller forced on and USB input off; and a
native EFI entry of our own — the UEFI door today is GRUB's EFI
build loading the same Multiboot2 kernel, so it is GRUB that
speaks to the firmware and calls ExitBootServices on that road.
Those are the milestones onward, taken one at a time.
