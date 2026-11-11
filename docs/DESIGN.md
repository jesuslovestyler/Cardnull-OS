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
   firmware let it in. Behind the UEFI door the standard image
   still walks in by GRUB's own EFI build; since milestone 22
   (November 10, 2026) the ownboot image walks in by a native
   EFI entry of our own, speaking to the firmware directly and
   handing over the same Multiboot2 word — `docs/BOOTLOADER.md`
   keeps its design.)*
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
   the store era, still to come. Milestone 15 — the same
   day again — took the keeping by force: the timer now
   ends a running guest's turn itself. While a pair
   stands, the heartbeat's ticks count against the running
   guest's slice — ten ticks, a tenth of a second at
   100 Hz — and a spent slice saves the guest's whole
   state into its book out of the interrupt's own frame
   (a different frame from the door's: the processor
   builds it where the guest was standing, and the floor's
   stub reads the registers off its own pushes and the
   place, flags, and stack top out of the frame) and
   resumes the partner from the partner's book, the paused
   guest unable to tell it was paused. A new guest, SPIN,
   witnesses it: it never yields and never leaves, and
   paired with A it no longer starves A — A counts out and
   leaves on slices cut from SPIN's spinning, and SPIN
   runs on alone until Esc, which every session's opening
   line names ("Press Esc to stop the session."), ends the
   session and brings the shell home; the same word bounds
   a lone `run` of a guest that never ends. Yield remains
   a service and acts as an early slice end, and the
   pair's report closes with the session's accounting —
   the turns taken at the door beside the turns taken by
   the timer, a switch counted only when the machine
   truly changed hands. The milestone's proof also caught
   a hazard as old as the first interrupt stub: the
   floor's C kept its locals in the red zone below the
   stack pointer, where an interrupt's frame lands, and a
   timer frame overwriting memset's own count sent it
   marching into the kernel's text; the floor's C is
   built with the red zone off now, as kernel code must
   be. The edges that remain are plain: the company is
   still two guests exactly; preemption governs the pair
   (a single guest is bounded by the Esc road, not by
   turns); and the kernel's own work is never preempted —
   a tick that finds the kernel running only counts.)*
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
   so the OS can live on a machine's own drive; the signed
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
   the desktop perfectly but heard no mouse at all.
   Milestone 14 — the same day, at Tyler's word that the
   Terminal had not enough space — rearranged the desktop
   around the window the work is done in: the Terminal
   opens over the whole work area with its grid reckoned
   from its window (76 x 37 at 1280 x 800, within a floor
   keeping that became a fixed capacity), the Welcome
   window is a compact card that starts closed, a bottom
   bar carries the mouse's standing line, a launcher for
   each window, the session's uptime, and the Home button
   that is the face's labelled road home beside Esc's
   standing rule, and the windows can be carried by their
   title bars — by an outline that erases itself, the
   window painted whole at rest — with a maximize control
   on the Terminal besides. The limits shrink honestly:
   the outline is not a live repaint, and no program but
   the kernel draws, still. Milestone 16 — the same day,
   at Tyler's word on witnessing milestone 14 ("do you
   see how the screen buttons get crunched... i want it
   to be intuitive, no codes at the bottom, only in the
   terminal") — polished the face without changing it,
   and set down the desktop's law, which is Tyler's and
   stands for every later stone: **the desktop speaks
   plain words only; codes live in the shell.** The
   bottom bar's layout became a budget reckoned from the
   framebuffer's width: margins, the standing word, and
   each launcher at the size its label honestly needs,
   the clock right-anchored before Home, and — the rule
   that keeps the promise — the gaps give first and the
   furniture never shrinks; a word that cannot stand
   whole is shortened in plain language or left off,
   never squeezed. The mouse's standing on the face is
   two plain words ("Mouse ready" / "Mouse not
   answering"); its full report — the wake transcript
   and the tallies of what the face has taken from it —
   moved into a `mouse` shell command, answered
   identically at the text console and in the Terminal.
   The boot screen keeps its transcript: it is the
   console's face, not the desktop's. The windows'
   carrying was made sure rather than different: one
   shared keeping for both title bars' boxes, a press
   judged by the rectangle that is painted, the dragged
   window's title wearing its held look for the whole
   carry, a clamp stated as a rule (the title bar keeps
   a reachable strip — 120 pixels sideways, the whole
   strip inside the work area up and down), and the
   double-click on the Terminal's title bar trading
   maximize for restore, the convention people already
   know. Fit and feel, not a new face: the look is
   milestone 14's, kept. Milestone 17 — November 10,
   2026 — opened another of the later doors: the
   machine's voice. The speaker is the classic PC
   speaker, the one sound-maker every PC carries:
   the timer's second channel, its output joined to
   the speaker through a gate (the two low bits of
   port 0x61). A tone is a divisor reckoned from a
   frequency — the timer's clock of 1,193,182 Hz
   divided by the tone, the same division the
   heartbeat's own 11932 came from — and a duration
   reckoned on the heartbeat itself, the kernel
   resting in `hlt` while the gate stands open.
   Channel 0 is never written by the singing: the
   heartbeat, and everything that reads it (uptime,
   the scheduler's slices, the bar's clock), keeps
   its beat through a song and after it. The gate's
   law is silence at every ending — each note closes
   it, the phrase's end closes it again — so no tone
   is ever left standing. A `sound` command plays one
   phrase, the Doxology's opening on the tune Old
   Hundredth, and prints each note before it sounds
   (name, frequency, length), so the playing is
   accountable on the screen in the places it cannot
   be heard; the shell waits while the phrase plays,
   and no background machinery is pretended. Two
   absences are stated as design, not oversight:
   guests cannot sing — the door (interrupt 0x80)
   gains no sound service this stone, and a feather
   with a voice is future work; and no audio chip is
   driven — the intel-hda in the test machine sits as
   silent as it has sat for sixteen milestones, and
   a driver for it is future work too. Milestone
   18 — November 10, 2026 — opened the face to guests,
   and retired the limit every earlier stone in this
   step restated ("no program but the kernel draws").
   The service door (interrupt 0x80) grew a second
   suite — screen size, fill rectangle, draw text, read
   key, poll mouse: services 4–8, written down in
   docs/FEATHER.md — answered by the kernel behind the
   same walls as the first suite: a guest never touches
   the framebuffer; it names places, shapes, colours
   and words, and the kernel's own hand draws, clipped
   to the screen, with degenerate and wholly-off-screen
   rectangles refused by a stated answer rather than a
   fault. Draw text proves its reach against the
   guest's estate with the write-string discipline —
   and stops the guest where a reach leaves the estate,
   under a protection report of the door's own, where
   service 1 has always answered all-ones and let the
   guest walk on; the sharpening is deliberate, and
   the disc carries its witnesses: BADGFX, refused at
   the door's wall with its address reported, and
   WILDRECT, whose too-large rectangle is drawn
   clipped while its guest stands unharmed. The face
   rules are stated as law in the kernel and the
   feather document: a graphical guest takes the whole
   screen for its session (no windowing of guests
   yet); on every road home — the leaving, a fault,
   the door's stop, or the user's Esc, which keeps
   milestone 15's standing armed through graphical
   sessions and is never delivered to a guest — the
   covered world is repainted from what was never
   touched, the desktop and the Terminal's
   conversation from their keepings or the text
   shell's grid, exactly; and a pair session keeps
   the text door only, its graphical knocks refused
   with the reason spoken once on the shared screen,
   a face not being a thing two guests can share by
   turns. And the stone milestone 13 promised when it
   labelled the kernel's Terminal window honestly
   ("a true terminal feather waits on guest services")
   arrived as a feather: TERM.FEATHER, a terminal
   standing on the door alone — its own framed
   screen, prompt, echo, scrollback and small command
   set — beside FACE.FEATHER, a greeting painted by
   its guest, cardinal and all. Faces cost no frames
   and no heap: `mem` reads the same numbers before a
   graphical session and after it. What the suite is
   not: a window manager for guests, a sound service
   (the speaker remains the kernel's own voice), or a
   signature — the store's day is still to come.
   Milestone 19 — November 10, 2026 — gave the disc a
   face: a Files window on the desktop, and a Reader
   beside it. The window lists the disc's root through
   the very walk `ls` makes — one machinery, two faces,
   so the list and the command can never disagree —
   each entry wearing a drawn mark of its kind, its
   true name, and its size in plain words, under a
   status line that counts the disc's files; the list
   scrolls by rail buttons and by the arrow and Page
   keys, the mouse here reporting no wheel and none
   being pretended. A double-click opens by kind, and
   the openings are honest about their roads: a text
   file is read into the Reader sector by sector, as
   `cat` reads, and wrapped by a walk reckoned fresh
   at the window's width; a feather or a program is
   not run by the window at all — the window gives the
   Terminal the room and types the command into it,
   letter by letter, so the card, the proof and the
   report are the commands' own, and a half-typed line
   is never typed over (the window says so instead);
   and what does not open — the system files, and
   folders at this stone — is answered in the status
   line in plain words, listed and never hidden. The
   desktop's law binds the new windows whole: plain
   words only, the shared box geometry, the composed
   bar reckoned again for a third launcher with the
   gaps giving first. The state lives in one floor
   keeping of stated bounds — 48 entries, 31 letters,
   a Reader page of 9,760 bytes with its going-on
   confessed on the page itself — and the list is
   read at the opening, the disc being read-only:
   reopening is the refresh, stated rather than
   machinery pretended. Milestone 20 — November 10,
   2026 — opened the networking door these notes named
   among the later ones. A driver for the Intel e1000
   the test machines carry, found on the PCI bus by
   vendor and class as milestone 8 found the disc
   controller, its registers mapped through the
   kernel's tables as that driver's were. The shape is
   the house's throughout: descriptor rings and packet
   buffers kept in allocator frames, every address
   proven below the card's 32-bit DMA reach before the
   card is told it; the card's hardware address read
   out of the card itself, never invented; its
   interrupts silenced and the rings polled on the
   heartbeat, the conversation being short enough that
   interrupt-driven reception is a named later
   refinement rather than a present need. And the
   conversation is deliberately one exchange: a DHCP
   discover built by hand, an offer judged strictly —
   each field read only within the frame's proven
   length, the asking's own transaction number
   required — reported with its addresses, and the
   address not taken, the shell confessing as much on
   screen. The taking of a lease, an address of our
   own, ARP and everything above this exchange belong
   to later stones; guests gain no service at the
   door, and the packet fields never stand where a
   guest can reach them. Milestone 21 — November 10,
   2026 — took the writable step these notes promised
   at the ladder's climbing: a hard-disk driver, a
   format of our own, and an installer. The driver
   speaks AHCI DMA to the hard disk on the very
   controller the CD taught the kernel — the bus
   settled by the machines' own evidence, Tyler's
   UTM declaring both drives IDE and those drives
   standing, on q35, on the AHCI controller's ports —
   leaving the CD's read-only path untouched and
   without any write road. The format, CARDNULL DISK
   1, is defined in `docs/DISK.md` and is small the
   way the feather is small: a checksummed superblock,
   one flat directory, files in unbroken runs, written
   data-then-entry-then-superblock so the disk never
   claims what is not there, and judged afresh at
   every command — blank, foreign, damaged, or ready,
   in plain words. Making is gated by a typed word,
   and the refusal of a wrong word is proven to leave
   the disk byte-identical. The installer copies the
   system's own files through the real disc path and
   writes its own confession onto the disk: booting
   from the disk waits for Cardnull's own bootloader.
   That bootloader — the last GPL-shaped passenger,
   GRUB, replaced by a small public-domain loader of
   our own — has since begun: milestone 22 (November
   10, 2026) laid its UEFI half as the ownboot image,
   whose UEFI door is ours end to end; its BIOS door
   is the next stone, so that booting from an
   installed disk can follow the pair. The stone after
   teaches the kernel to carry its files in memory,
   so a stick, which is not a CD, can be a home too.
   The Files window keeps its disc face at this stone;
   a face for the hard disk rides a later one. And the
   bundle landed as milestone 23, the same day: the
   system's own files — the welcome, every program,
   every feather — packed by the build from the very
   staging the disc is built from into one bundle file
   (docs/BUNDLE.md), carried behind both doors (GRUB's
   module on the standard image; our loader reading
   \BOOT\FILES.BUNDLE into claimed pages and naming
   the span in a module tag), proven by the kernel at
   boot — signature, sums, and the payload's checksum
   — before a byte of it serves, and then serving the
   whole file world from memory: the shell's roads,
   the Files window and its Reader, and install's
   copies, while the hard disk's own world never reads
   it and the disc path stands unchanged beneath, the
   fallback whenever no sound bundle rides. The bench
   witnessed the decisive shape: the ownboot image
   riding as a USB stick's shape with no CD device in
   the machine at all, and the whole system living off
   the cargo in memory — the stick road's second half
   standing beside its bootloader. And the road's
   first half finished the same day: milestone 24
   (November 10, 2026) replaced GRUB behind the BIOS
   door with a boot chain of our own
   (docs/BOOTLOADER.md) — a 512-byte boot sector that
   lives twice in each image, as the El Torito boot
   file and, laid into the MBR by the build's own
   patcher, as the master boot record itself, and a
   16-bit second stage that gathers E820, walks the
   disc's tree, lays the kernel and the bundle,
   chooses the screen by VESA VBE, and hands over the
   same Multiboot2 word the kernel already reads, the
   kernel unchanged by a line — so neither door of
   either image carries GRUB code anywhere, a byte
   search finds none, and the stick shape was proven
   behind SeaBIOS as well: the standard image on USB
   mass storage, booted through the sector's MBR copy,
   living off the bundle, installing from it, with no
   CD in the machine. Milestone 25 — November 10,
   2026 — gave feathers windows: a graphical feather
   launched from the desktop opens in a window titled
   with its card's own title, its size fixed at the
   opening for the honest reason that a feather
   reckons its face from the door's answer once, and a
   size that moved under it would make the reckoning
   a lie. The door kept its numbers and took the
   window's meanings — the size is the canvas's, the
   painting is offset and clipped to the canvas, the
   mouse is the desktop's pointer answered relative
   and signed, the keys are the guest's only while
   its window holds the room — and gained one service,
   the window standing, by which a guest learns that
   the kernel has laid its ground over the canvas (at
   the opening, at a change of the room, at a drag's
   end) and a repaint is owed; TERM and FACE both pay
   the owing whole, in frame and face together. The
   session's shape did not change — the shell still
   stands inside the launch — so the desktop is
   tended on the guest's own input knocks, the mouse
   bytes fed through the face's own hands, and clicks,
   drags and the close box answer while the guest
   stands. The feather's window stands over the
   elders for its whole session, having no launcher
   in the bar to raise it from burial; the elders'
   furniture waits the session out, the bar still
   answers, and the close box ends the session with
   Esc's own verdict. TERM wraps at last: its columns
   are reckoned from the measure it is given, and its
   lines break at their last fitting space as they
   join the scrollback, so its welcome prose stands
   whole inside a window and whole on the full screen
   alike. From the text shell the same feathers take
   the whole screen exactly as they always have —
   the face fits the room it was opened in. The
   stone's probe also caught the Welcome card's press
   hand answering for a card that did not stand — a
   ghost button painted, and its click counted, on
   the bare desktop; the standing check its younger
   siblings always kept stands in it now. Milestone
   26 — November 10, 2026 — taught the waking the
   wheel knock and the desktop to scroll: after the
   defaults, the mouse is knocked on with the
   IntelliMouse sample-rate sequence (200, 100, 80)
   and its name asked again, and the packet's length
   follows the answer for the whole session — four
   bytes from a wheel mouse, three from a plain one,
   the plain road kept exactly as it was, and the
   `mouse` command reporting the name it heard and
   the wheel's standing in plain words beside it.
   The wheel scrolls the window under the pointer,
   three lines to a notch, the window given the room
   first as a press gives it; the bar and the bare
   desktop let a turning go, and so does a drag in
   progress. The Terminal gained the scrollback it
   never had — 128 lines kept in the floor as they
   leave the screen — read back by the wheel and the
   page keys, its view a distance from the end that
   stands as new lines arrive and that any keypress
   first brings home; the Files list and the
   Reader's page turn the same scroll positions
   their buttons and keys already kept. And the
   turning crosses the door: the mouse poll's answer
   grew a fourth word carrying the wheel's sum since
   the guest last asked, spent by the asking —
   windowed, gathered by the face's assembly from
   turnings over the guest's canvas alone;
   full-screen, from the guest's own packets — and
   TERM scrolls its own scrollback by it, in its
   window and on the whole screen alike. A mouse
   that answers the plain name is handled exactly
   as before; the bench proved that branch with a
   throwaway build whose waking asks without
   knocking, and the same mouse answered 0 and was
   told of as having no wheel. Milestone 27 —
   November 11, 2026 — taught the machine the sound
   chip's language, and gave `sound` its routing
   rule. The controller is found by class alone —
   multimedia (04h), audio device (03h) — because a
   driver that hunts one maker's numbers has learned
   a machine, not a kind; its register ground is
   mapped and its memory and bus-master doors opened
   as the other drivers', and the raising is lazy —
   at the first `sound`, never at boot — with its
   verdict cached for the session either way, so a
   chipless machine pays the asking once and sings
   on the speaker thereafter. The conversation rides
   two rings laid in allocator frames proven below
   4 GiB, as the network rings were: the CORB, one
   way out, carrying verb words to the codec, and
   the RIRB carrying its answers back — interrupts
   off, the RIRB's write pointer polled against the
   kernel's kept reading with a deadline on the
   heartbeat, because a codec that never answers
   must cost fifty ticks, never the shell. The codec
   is walked, never assumed: from its root, its
   vendor and name; through its function groups to
   the audio one; through that group's widgets to
   the first converter and to a pin that can sound,
   preferring the pin whose own connection list
   names the converter — node numbers are whatever
   the walk finds, and none is written down here
   from any other machine's testimony. The path is
   then configured verb by verb, and the phrase
   itself is rendered once, at the raising, into
   fresh frames — the same Doxology opening the
   speaker sings, the same lengths on the same
   heartbeat reckoning, now as samples at 48,000 a
   second — and played whole through a
   buffer-descriptor list; the speaker and the chip
   sing one tune from one note table, which is why
   their proofs can be read against each other. Two
   defects stand as the stone's design lessons. A
   format word is a spelling, and a wrong one does
   not fail loudly: 0x0101 asked for 8-bit samples
   at a doubled rate and the chip would have
   honoured it exactly, so the word stands as one
   named constant spelled from the phrase's own
   facts — 48 kHz base rate, sixteen bits, two
   channels, 0x0011 — and the converter and the
   stream are taught that same word. And a watch
   window is part of the music: the stream watch's
   first margin stood thirty ticks past the phrase's
   reckoning, wide enough for the phrase's first
   note to begin again inside it, so the margin is
   two ticks — wide enough to see the stream stop,
   and no wider. The routing rule closes the stone:
   the chip when one answers, the speaker when none
   does, and one honest line in the Terminal saying
   which road was taken — the fallback is not a
   lesser silence but milestone 17's voice, kept
   whole. Milestone 28 — November 11, 2026 — closed
   the confession milestone 21 wrote onto every
   installed disk: a prepared disk now starts the
   computer by itself, behind the BIOS door. The
   design is three decisions, each taken for the
   honesty of the half-way states. First, the
   filesystem became home-relative: rather than
   teaching every disk hand two geometries, the
   kernel keeps one home — sector 0 on a plain disk,
   the start of the 0xCA partition on a prepared
   one — and every reckoning in the format is made
   from the home, so the superblock is sector 0 of
   its home wherever the home stands, and `format`
   on a prepared disk remakes the filesystem inside
   its partition and leaves the MBR, the boot image,
   and the partition entry untouched. Second, the
   preparation writes in the only safe order: the
   filesystem migrates first, byte for byte to
   sector 2048, copied top down so the copy cannot
   overwrite ground it has not yet read; the boot
   image is laid next at sector 4, its El Torito
   boot-info table patched for a home it was not
   burned for (the word at offset 12 becomes 1, the
   image's place in 2048-byte units; the word at
   offset 16 names its whole length, 14,150 bytes);
   and the MBR is written last of all, because the
   moment it stands the disk claims to boot, and a
   disk that claims to boot must already be whole.
   Third, every refusal precedes any write — the
   gate's near-miss, the unprepared or already
   prepared disk, the missing or misshapen boot
   image, the want of room — each is judged before
   the typed word is even asked for where the
   judging allows, and the bench proved the
   near-miss left the disk's host hash identical.
   The installer was widened to make the preparation
   possible: it now plants KERNEL.BIN and
   FILES.BUNDLE beside the thirteen, sixteen files
   standing with INSTALLED.TXT, whose text now says
   the disk carries Cardnull itself and names
   `bootable` — and still confesses the scope in the
   same breath: the UEFI door from an installed disk
   is not yet; this road is the BIOS door only.
   Behind that door the second stage learned the
   fork its header always promised: sector 16 is
   probed, CD001 means the ISO walk unchanged, and
   anything else means a prepared disk — the MBR
   read, the 0xCA partition found, the DISK 1
   superblock verified at its start, the flat
   directory walked in the disk's own 512-byte
   sectors, and KERNEL.BIN staged from the disk,
   the sign-on saying "read from the boot disk"
   where the disc road says "disc"; everything
   downstream of the finding — the ELF laying, the
   bundle behind the kernel's span, the screen, the
   Multiboot2 word — is one road again, and the
   kernel did not need to learn the loader's name.
   `disk` speaks the new standing in one plain line
   — "It can start the computer by itself." — the
   codes, as ever, living in the documents and the
   shell's reckonings, not on the desktop. One
   residual is recorded here, honestly and not as
   this stone's failure: on this bench, wheel-down
   over a feather's canvas does not return the view
   — visible identically in milestone 26's and 27's
   archived frames, a pre-existing behaviour of the
   guest's road, while the kernel Terminal's own
   scrollback round-trips by the wheel correctly,
   on the disk boot as elsewhere. It stands open
   for a later stone to hunt, at Tyler's word.)*
6. Chirpy Browser and the Catholic Bible at home on it.

## Principles

- **Honest.** No borrowed engine dressed as ours, no claimed capability we
  do not have — the same rule as Chirpy Browser.
- **Simple.** One thing done truly beats ten things done halfway.
- **Given away.** Public domain from the first commit. The software is a
  gift; Cardnull sells what is around it — the building, the setup, the
  support, the computers themselves.
- **At God's pace.** No debt, no rush that breaks things. As He provides.
