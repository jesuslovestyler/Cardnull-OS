# Cardnull OS — Design Notes

*Written November 5, 2026, the day the language was chosen. These notes hold
decisions and their reasons, so future work can see why the road bends where
it bends.*

## Decisions

- **Language: Swift** (decided Nov 5, 2026, Tyler). A modern language, chosen
  deliberately over the well-worn C path, and over Rust (Redox already did
  Rust). No shipping operating system is Swift; that frontier is the point.
  Embedded Swift — Swift compiled freestanding, with no operating system
  beneath it — is the mode the kernel is built in.
- **From scratch** (decided Nov 4, reaffirmed Nov 5). Own kernel, own code.
  TempleOS (public domain) is teacher and precedent, not foundation.
  PDOS and every other existing system were considered and set aside.
- **License: public domain** (the Unlicense), like everything Cardnull makes.
- **Target hardware:** x86-64, small hand-built minis — the first is the
  DeskMini-class box (AMD AM4 APU). Developed on a Mac mini; tested in UTM
  (emulated x86-64 PC, QEMU underneath); real hardware is the final exam.
- **Builders:** Tyler Kovalevich and Billy Miecuna. The browser (Chirpy) is
  a separate work and not Billy's; the OS is theirs together.

## Shape

- A thin floor of assembly/C: the boot path, the processor's tables, and the
  handful of privileged instructions Swift cannot emit. This floor stays as
  thin as honesty allows.
- Everything above the floor is Swift: kernel, drivers, filesystem, shell,
  and in time the graphical face and the home software (Chirpy, the Bible).

## Milestones

1. Boot to a screen that says CARDNULL. *(The "hello, world" of an OS.)*
   *(Done — November 6, 2026.)*
2. Keyboard input and a simple shell.
   *(Done — November 6, 2026: milestone 2 brought polled PS/2 keyboard
   input echoing at a prompt; milestone 3 finished the keyboard
   (punctuation, Caps Lock), made the screen scroll, and gave the
   prompt a shell that answers — help, about, verse, clear.
   Milestone 4 — also November 6, 2026 — retired the polling:
   an IDT with a stub for every exception vector, the PIC pair
   remapped to 0x20/0x28, a 100 Hz PIT heartbeat counted by IRQ0,
   the keyboard taken by IRQ1 into a ring buffer, and the kernel
   resting in `hlt` between events instead of spinning. A new
   command, `uptime`, reads the heartbeat aloud. Exceptions now
   print "Exception - halting." rather than dying in silence.
   Milestone 5 — the same evening — opened the second door: the
   ISO is a hybrid that boots behind UEFI firmware as well as
   BIOS, the header asking for a framebuffer and the boot floor
   carrying the Multiboot2 information pointer up to the kernel.
   The kernel keeps the 80x25 character grid itself now and
   paints it through whichever screen the door provided — the
   VGA text grid, or pixels drawn from an embedded public-domain
   8x8 font — so the shell above neither knows nor cares which
   firmware let it in. Behind the UEFI door stands GRUB's own
   EFI build loading the same Multiboot2 kernel; a native EFI
   entry of our own, speaking to the firmware directly, remains
   a later door.)*
3. Memory management; a filesystem that remembers.
   *(Begun — November 9, 2026: milestone 6 taught the kernel to
   read the Multiboot2 memory map and keep a page-frame allocator
   over the RAM it names — reservations for the first megabyte,
   the kernel image, the framebuffer, and every non-RAM region,
   a boot self-test that takes and returns frames, and a `mem`
   command that speaks the reckoned numbers. Milestone 7 — the
   same day — replaced the boot floor's borrowed page tables
   with the kernel's own: four levels of 4 KiB identity mappings
   over the RAM and devices the kernel honestly stands on, the
   unmapped dark left dark, and W^X laid in the leaves — text
   executable and unwritable, everything else writable and
   unexecutable. The page fault gained a reporting handler that
   speaks the faulting address and the error code, in hex and in
   words, before halting cleanly; a `faulttest` command takes
   the fault on purpose so the report can be witnessed. And a
   4 MiB kernel heap stands over the allocator's frames —
   first-fit blocks with splitting and coalescing, a boot
   self-test of patterns written and read back byte for byte,
   and a `heap` command that speaks its books. Milestone 8 —
   the same day again — finished the step: the kernel reads its
   own disc. The CD-ROM hangs off an AHCI controller in every
   machine this kernel boots on (there is no legacy IDE port
   hardware in them), so the driver finds the controller in PCI
   configuration space by its class, maps its registers into
   the kernel's own tables, and speaks ATAPI to the port that
   signs itself a packet device — READ (10) packets, the
   controller's engine walking each sector into memory. Above
   it, a read-only ISO9660 reader walks directories and
   resolves the shell's paths without caring about case; the
   shell gained `ls` and `cat`, and the disc gained a
   WELCOME.TXT — a greeting and John 1:1 in the Douay-Rheims,
   packed into the ISO at build time and nowhere in the kernel
   — as the first thing worth reading.)*
4. Running programs.
   *(Begun — November 9, 2026: milestone 9 loads and runs the
   first separate programs. The guests are small assembly
   programs kept in `programs/`, assembled to flat binaries and
   packed onto the disc as files — never linked into the
   kernel. `run` reads one off the disc into page tables of its
   own — cloned from the kernel's, with the single branch
   toward the guest's estate carrying the user bit — and
   enters it in ring 3 on a fixed estate: its image
   read-and-execute (never writable), a scratch page, a stack.
   The guest speaks through one door, interrupt 0x80: write a
   string, write a character, exit with a code the shell
   reports truly. A guest that reaches for the kernel's ground
   faults in user mode; the fault is reported, the guest is
   stopped where it stands, its estate is handed back to the
   allocator, and the shell stands — the separation is
   enforced by the tables, not by the guest's good behaviour.
   Milestone 10 — the same day — finished the step's second
   half: two guests alive at once, taking turns. The door grew
   a yield service, and the floor keeps each guest's whole
   state — tables, stack, place, flags, registers — in one of
   two books, trading the machine between them; each guest
   resumes exactly where it yielded, in its own ground. A
   guest that leaves or falls while its partner lives hands
   the machine to the partner, which runs on alone — a falling
   guest is stopped by the same page-fault road, its partner
   undisturbed in the same session. The keeping is
   cooperative by decision: a guest that never yields keeps
   the machine, and preemption — the timer taking the machine
   by force — is a named later step, as is any wider company
   than two. Milestone 11 — the same day again — gave
   programs their travelling clothes: the feather format,
   defined in docs/FEATHER.md. A feather is one file: a
   plain-text card (title, maker, version, and the maker's
   support line — voluntary income for the maker, never a
   tax-deductible donation) and the packer's reckoning (the
   program's size and its FNV-1a checksum), a line of three
   dashes, and the program itself. The `feather` command
   reads the card, proves it — a program that does not match
   its card's checksum is refused and not run, as
   TAMPERED.FEATHER witnesses on every disc — prints it, and
   only then runs the program down milestone 9's road; `run`
   refuses a feather and sends the reader to `feather`,
   because a raw loader must never execute a card as code.
   The checksum is an integrity check against corruption,
   and the format says so in as many words: it is not a
   signature, and the reviewed, signed feather belongs to
   the store era, still to come.)*
5. A simple graphical interface.
   *(Done — November 9, 2026: milestone 12 gave the OS its
   face. A `gui` command leaves the text console and draws a
   desktop on the framebuffer the boot provided — a cardinal
   gradient, the OS's name in gold, and one window, Welcome,
   carrying the greeting and John 1:1 in the Douay-Rheims.
   The PS/2 mouse, woken once at boot before the interrupt
   gate opens and reporting by IRQ12 into a ring, drives a
   pointer whose ground is lifted into a cushion before it
   is drawn and laid back when it moves, so it never smears
   a trail. One interaction is honest and real: a button
   that counts its clicks, read from the packets' own
   button state. The window's close box and Esc both
   restore the text console exactly — the character grid is
   never touched — and the face takes no frames and no
   heap, painting ground the boot already reserved; `mem`
   reads the same numbers before a visit and after it. Its
   limits are stated in the kernel: one window, in one
   place, undragged and unresized; no window manager; no
   program but the kernel draws. With this stone, the
   ladder these notes described at the choosing of the
   language stands climbed: boot, speak, remember, work,
   dress. What remains is the sixth step, and the later
   doors it opens onto: a writable disc and an installer,
   so the OS can live on a machine's own drive; preemption
   — the timer taking the machine by force; the signed
   feather and its store; networking; and Little
   Cardnull. Milestone 13 — the same day, at Tyler's word
   after the partial witness — finished the face's first
   growth: the OS boots into the desktop; a second window,
   the Terminal, hosts the kernel's own shell on its own
   grid, guests printing inside it; and the mouse's waking
   was rebuilt as the full standard ceremony — reset,
   self-test, name, defaults, reporting — with timer-bound
   waits, a kept transcript printed at boot and drawn on
   the desktop, the configuration byte re-verified after
   the waking and at the face's opening, and a port-poll
   beside the IRQ, after milestone 12's UTM witness drew
   the desktop perfectly but heard no mouse at all.)*
6. Chirpy Browser and the Catholic Bible at home on it.

## Principles

- **Honest.** No borrowed engine dressed as ours, no claimed capability we
  do not have — the same rule as Chirpy Browser.
- **Simple.** One thing done truly beats ten things done halfway.
- **Given away.** Public domain from the first commit. The software is a
  gift; Cardnull sells what is around it — the building, the setup, the
  support, the computers themselves.
- **At God's pace.** No debt, no rush that breaks things. As He provides.
