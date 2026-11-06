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
   and clear.)*
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

Milestone 3 stands (November 6, 2026): the prompt now answers. The
kernel reads the finished line straight off the screen, trims it, folds
capitals down, and answers four commands — `help` lists them, `about`
says what Cardnull OS is, `verse` prints John 1:1 (Douay-Rheims), and
`clear` wipes the screen to a fresh prompt; anything else is answered
plainly as unknown, and an empty line earns only a fresh prompt. The
keyboard is finished, too: the whole main block of a US keyboard —
letters, digits, space, and every punctuation key in its plain and
shifted face — with Caps Lock latching the letters as it should. And
the screen is a true terminal now: output past the last row scrolls
the page upward instead of waiting for room. The keyboard is still
polled (status port 0x64, data port 0x60) — interrupts remain a later
milestone, taken on purpose, one thing at a time. Verified in QEMU,
with commands typed through the emulator's keyboard answered on the
kernel's screen; the same ISO is the one tested in UTM.

Not yet, honestly: interrupts and an IDT, memory management, a
filesystem, UEFI boot, and USB input. Those are milestones 4 and
onward, taken one at a time.
