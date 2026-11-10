# Cardnull OS

A Christian operating system, written from scratch in **Swift** — public domain.

Cardnull OS is the operating system of [Cardnull](https://cardnull.com), a Christian
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
   *(Done — November 9, 2026: milestone 6 brought the frame
   allocator and the `mem` command, milestone 7 the kernel's own
   page tables and heap, and milestone 8 the disc itself — a
   CD-ROM driver, an ISO9660 reader, and the `ls` and `cat`
   commands to prove them.)*
4. **Work** — run programs; one thing at a time, then many.
5. **Dress** — a simple graphical face.
   *(Done with milestone 12 — November 9, 2026: a drawn desktop
   and one window, a PS/2 mouse pointer, a button that counts
   its clicks, and the close box or Esc home to the shell.
   Milestone 13 woke the mouse properly, moved the front door
   into the face, and added the Terminal window; milestone 14
   rearranged the desktop around the Terminal — it opens
   large, the Welcome window is a compact card, a bottom bar
   carries the launchers, the uptime, and the Home button,
   and windows can be dragged and the Terminal maximized.
   Milestone 16 polished the face at Tyler's word: the bar
   lays itself out from the screen's width so nothing is
   ever squeezed, the desktop speaks plain words only (the
   mouse's codes moved into a `mouse` command in the
   shell), and the carrying was made sure — a held title
   bar through a drag, an honest clamp, and a double-click
   on the Terminal's title bar to maximize or restore.)*
6. **Carry** — Chirpy Browser and the Catholic Bible, at home.

## Building

The build does not use Xcode's templates — Xcode is the workshop (the editor
and the Swift compiler), but the kernel is stitched together by the build
script in `tools/`, linked with a custom linker script, and tested in UTM
(emulated x86-64 PC) before it ever touches real hardware.

## License

Public domain. See [LICENSE](LICENSE) — the Unlicense.
Freely you have received; freely give. (Matthew 10:8)

One accounting, kept honest: the standard image still
boots through GRUB (GPL) on both of its doors, for now.
On the UEFI door, the experimental ownboot image
(`tools/build-ownboot-iso.sh`, milestone 22) contains
no GRUB code at all — its loader is our own, public
domain like everything else here. Its BIOS door is
still GRUB's; that door is the next stone.

## Status

Milestone 22 stands (November 10, 2026): **our own
bootloader — the UEFI door is ours.** A second image
now stands beside the daily one: `dist/cardnull.iso`
is unchanged in behavior, GRUB-booted on both doors as
ever; `dist/cardnull-ownboot.iso` carries the same
disc, but its UEFI boot path is a small public-domain
loader of our own (`Sources/bootloader/`), standing at the
fallback path in an EFI system image that holds
nothing else but the kernel itself. The loader signs
its work on screen ("Cardnull Bootloader — Cardnull OS
behind the UEFI door, loaded by our own hand"), opens
its own boot volume by the firmware's file protocol,
reads `/boot/kernel.bin` — the very file GRUB loads —
lays its ELF segments at their addresses and zeroes
the unwritten honestly, chooses the screen through the
Graphics Output Protocol, builds the Multiboot2
information the kernel already reads (two tags, no
more: the framebuffer tag from the chosen mode, and
the memory map translated region by region from the
firmware's own), leaves by ExitBootServices, and drops
through a small trampoline into the processor state
`boot.S` has always expected — paging off, the magic
in EAX, the word in EBX. (The loader's C is 670 lines;
with its hand-written EFI header and the trampoline
the whole door-keeper is 1,096 lines.) **The kernel
did not change by one line: the Multiboot2 agreement
is the whole point — our loader speaks what GRUB
spoke.** The QEMU
bench (OVMF, UTM's own shape, 512 MB) witnessed the
whole regression chain through the new door: the
desktop whole at the true 1280×800, `verse`, `sound`
(the Doxology phrase, measured in the captured audio),
TERM.FEATHER standing on the door's services alone,
`net` answered, and `disk` reading the disk milestone
21 installed. `mem` tells the handoff's truth: 129,475
frames total and **1,552 used** behind our loader
against the standard image's **1,551** in the same
session — one frame of loader keeping, the memory map
otherwise the same in kind. GRUB's EFI binary appears
nowhere in the ownboot image (proven by byte search,
not by trust), and its UEFI module tree is struck;
what the fresh build does not re-create is the
standard image's HFS+ blessing for old Macs and its
GRUB-stamped hybrid MBR — a plain protective MBR and
a true GPT stand in their place. The BIOS door of the
ownboot image is still GRUB's eltorito image: mixed
doors are a waypoint, stated plainly, not a claim.
Two faults were found and fixed on the way, and are
recorded here because they are the kind that teach:
the loader first reckoned a pixel's size from its
color channels alone and read this firmware's
BlueGreenRedReserved screen — 32 bits by definition,
reserved byte and all — as 24, handing the kernel a
pitch of 3840 against the screen's true 5120; the
desktop came up squeezed and tiled until the loader's
own sign-on ("1280 by 800, 24 bits to a pixel") named
the error, and the reckoning now counts the whole
pixel. And the first ownboot tree was written at
strict ISO 9660 naming, which truncates TERM.FEATHER
to TERM.FEA — the kernel answered "Not on the disc" to
a feather standing right there; the image is now
written at ISO level 3, the standard image's own
naming, entry for entry. The design, the tags, and the
lessons are kept in `docs/BOOTLOADER.md`. Tyler
witnesses the whole of today's building at his own
checking; the UTM run of the ownboot image rides his
word like every stone's last proof.

Milestone 21 stands (November 10, 2026): **the writable
disk, and the installer — a visiting stick becomes a
home.** Six new commands (the shell now answers
twenty-five): `disk`, `format`, `dsave`, `dls`, `dcat`,
`install`. The bus was settled by evidence, not by the
expectation carried in: Tyler's UTM declares both of
its drives IDE, and on the q35 machine those drives
stand on the ICH9 AHCI controller milestone 8 found —
the CD on its port 2, exactly where milestone 8 put it,
and the hard disk on another port of the same
controller (the bench proved it with QEMU's own device
tree: a scratch drive attached as IDE index 0 signs in
on port 0). So the hard-disk driver speaks **AHCI DMA**
to a plain ATA disk — IDENTIFY first, its model and
measure read from the device itself: "QEMU HARDDISK",
64 MiB (67108864 bytes) on the bench — with READ/WRITE
DMA EXT where the disk's reach passes the 28-bit line,
the classic forms below it, a flush after every making,
and its own command list, table, and data frame. **The
floor did not move**: AHCI needs no programmed-I/O data
road, and the CD's ATAPI path is untouched — it has no
write road at all, and cannot gain one by accident,
the new driver addressing only the hard disk's port.
On the disk stands a format of our own, **CARDNULL
DISK 1**, defined in `docs/DISK.md`: a superblock in
sector 0 carrying the signature, the geometry, and an
FNV-1a-64 checksum (an integrity check, the feather's
own reckoning — not a signature); a flat directory of
128 entries in sectors 1..16; file data from sector 17
in unbroken runs, written data first, entry second,
superblock last, so the disk never claims what is not
there. Every command re-reads the superblock and judges
the disk afresh — blank, foreign, damaged, ready — and
`disk` speaks the judgment in plain words, reckoning
the file count and the room from the directory itself,
never from a remembered mirror. `format` and `install`
are gated by a typed word at their own sub-prompt
(FORMAT, INSTALL; capitals folded, the whole word
demanded): the bench proved the gate is real by typing
a near miss — "Nothing was written. The disk stands
exactly as it was." — and the host's own sha256 of the
scratch image stood **identical before and after the
aborted format** (3b6a07d0…c421351). Persistence is the
proof, and it was witnessed, not inferred: a greeting
saved in one boot ("hello from cardnull on its own
disk", 36 bytes) was read back word for word after a
full shutdown and a cold boot, a second file beside it
in the second boot, both listed by `dls`. The
installer is v1 and honest: it names the disk, warns
that installing erases it, demands its word, formats,
and copies the disc's own files through the real disc
path — WELCOME.TXT and every .BIN and .FEATHER the
disc carries, thirteen files — then writes
INSTALLED.TXT saying what was done and what was not:
"Booting from this disk waits for Cardnull's own
bootloader; the machine still boots from the disc or
stick." After a reboot the installed disk still stands,
all fourteen files, read from the disk. The boundary
is the stone's own, stated on screen and here:
**installing makes the disk a Cardnull home for files;
booting from it waits for Cardnull's own bootloader**,
the next stone — and the Files window keeps its disc
face this stone, a disk face riding a later one. The
accounting: `mem` at the bench's 512 MB reads 1,554
frames used after the disk driver has raised and
worked (its keeping is three frames, taken once), and
the standing count at 4096 MB is 1,293 — milestone
20's 1,285 and eight frames of grown kernel (the
kernel grew from 10,486 to 12,253 lines; its image
193,040 → 228,384 bytes). At 4096 MB this bench's
firmware parks the AHCI bar beyond the kernel's reach,
as it has since milestone 8, so the disk sessions ran
at 512 MB; in UTM, where the bar stands in reach, the
same commands answer at 4096 MB — Tyler's witness of
the day's stones together stands at the run's end, and
his disk walk in `tools/run-utm.md` begins, as it
must, with a warning: witness with a new throwaway
disk, never one holding anything he keeps. Proven in
QEMU (TCG, the UTM shape) on both firmware doors:
absence answered plainly with no disk attached; the
refusals — unformatted `dsave`, a taken name — each in
their plain words; and the regressions whole — the
desktop, `ls` and the Files list agreeing, FACE from
Files, the classic pair (9 by the door, 0 by the
timer), `net` answered once, the tampered feather
refused, the song's note list, faulttest's halt, and
`disk` behind SeaBIOS reading the installed disk.

Milestone 20 stands (November 10, 2026): **first network
packet — the e1000 driver, and one honest conversation.**
A new command, `net` (the shell now answers nineteen),
finds the machine's network card the way milestone 8
found its disc controller: walking the PCI bus, asking
every function of every device — and on this bench, as
in UTM, the answer is Intel's e1000, the 82540EM
(8086:100e), at bus 0, device 2, its register base at
0x80840000, comfortably below the 4 GiB line. The driver
maps the first 0x6000 bytes of that ground through the
kernel's tables, as the disc driver maps its own, and
raises the card from silence at every asking: its
interrupts masked (the stone polls; it takes no
interrupt), a reset waited out on the card's own word,
the multicast table cleared word by word, and the
hardware address read out of the card's own filter
registers — 52:54:00:12:34:56 on this bench, the card
QEMU provides, never a number invented here — and
written back with its valid mark, so answers addressed
to us are let in. The link is asked up, and its truth
spoken ("Link: up."). Two descriptor rings stand in
frames the allocator hands over — sixteen receive
descriptors, each naming its own 2048-byte buffer
frame, and a transmit ring of sixteen with one buffer,
twenty frames in all — and every address the card is
told is proven below 4 GiB before the rings stand, the
card being a DMA engine of 32-bit reach: the taking
asserts the line address by address, though the
allocator's own estate ends exactly there. The
conversation is one question: a DHCP discover built by
hand in the transmit buffer — Ethernet broadcast, IPv4
with its checksum honestly reckoned, UDP, BOOTP
carrying our address and a transaction number fresh
from the heartbeat, the broadcast flag standing — 291
bytes, sent through the ring, the card's own completion
word waited for. Then the listening, five seconds of
heartbeat at most: each arrived frame length-checked
before any field is read, and judged — the answer's
port, a reply, this asking's transaction number, our
own address named in it, the offer mark in its options.
On this bench the network's built-in server answers at
once, and the account closes: "Answer: the network
offers us 10.0.2.15; the offer comes from 10.0.2.2." —
followed by the stone's own confession, spoken on
screen: "We did not take the address - asking was this
stone's whole errand." No lease is kept. A second `net`
in the same session runs the whole raising again —
rings rebuilt fresh in the same frames — and is
answered the same. The accounting stays truthful:
`mem` at the bench's 512 MB reads 1,543 frames used
before the first asking and 1,563 after it (the twenty
frames are the driver's keeping, taken once), and the
standing count at 4096 MB is 1,285 — milestone 19's
1,283 and two frames of grown kernel (193,040 bytes).
The wire itself is the second witness: QEMU's capture
of it stands in the evidence beside the screenshots —
four packets for the main session's two askings, two
for the BIOS door's one, each discover ours byte for
byte and each offer carrying the asking's own
transaction number. (The offer arrived addressed to
the broadcast, as a machine holding no address should
expect: the filter law's broadcast half earned its
keep.) The bounds are stated, not hidden: one exchange
only — no DHCP request, no lease, no ARP, no ping, no
address of our own; reception polled on the heartbeat,
not interrupt-driven; guests gain no network service,
and the packet fields never stand where a guest can
reach. The receive discipline's other-traffic count
stood ready and never printed: this bench's wire
carried nothing but the conversation itself. Absence
is proven as the house proves it — the same ISO on a
machine with no network device answers "No network
card was found on the PCI bus." and the shell stands.
Proven in QEMU (TCG, the UTM shape) on both firmware
doors: the exchange twice on the UEFI door and once
behind SeaBIOS, the absence, and the regressions
whole — the desktop with its three launchers, `ls` and
the Files list agreeing, FACE from the Terminal, the
classic pair with milestone 15's own account (9 by the
door, 0 by the timer), the tampered feather refused,
the song's note list, faulttest's halt. In UTM the
counterpart network is Shared, and its server will
offer different addresses than the bench's 10.0.2.15 —
the conversation is the same, and the difference is
expected. Tyler's witness of the day's stones together
stands at the run's end, as he chose this morning.

Milestone 19 stands (November 10, 2026): **the desktop
file manager — the disc gets a face.** A third window
stands on the desktop: **Files**, opened from a new
Files button in the bottom bar — the bar's layout
reckoned again for three launchers, the gaps giving
way first and the furniture never, as the law of
milestone 16 demands — or by a new `files` command
(the shell now answers eighteen). The window lists
the disc's root through the same machinery `ls` uses,
so the two can never disagree: every entry wears a
small drawn mark of its kind — a folder in gold and
parchment, a white page for a text file, a cardinal
square for a program, a gold quill for a feather, a
grey chip for the files that are Cardnull itself —
its true name, and its size in plain words
("2,949,120 bytes"); a folder is named Folder, as
`ls` names it <DIR>. A status line at the window's
foot says how many files the disc holds, and the
list scrolls when it outgrows the window: buttons on
a rail at its right, and the arrow and Page keys
while the window holds the keyboard — the mouse this
house woke reports no wheel, and none is pretended.
A double-click opens, by kind. A text file opens the
**Reader**, a second new window titled with the
file's name: the file's own words, read off the disc
sector by sector as `cat` reads them, wrapped to the
window's width and scrollable the same way; closing
it leaves Files standing. A feather or a bare
program **runs through the Terminal, as if typed**:
the window gives the Terminal the room, types
`feather /NAME` or `run /NAME` into it letter by
letter through the shell's own typing hand and
submits the line, so the card, the checksum's proof,
the run and the report are the commands' own work,
not a likeness of it — a text feather prints there
(HELLO.FEATHER, proven), a graphical feather takes
the whole screen and gives the desktop back as it
stood (FACE.FEATHER, proven), and a program that
never yields still answers the user's Esc
(SPIN.BIN, proven). A command line the user has
half-typed is never typed over: the window says so
in its status line instead, and opens nothing.
Anything else does not open, and the status line
says why in words — "EFI.IMG is part of Cardnull
itself and doesn't open." — the system files listed
honestly, never hidden, and a folder answered with
its own plain sentence. The list is read when the
window opens; the disc is read-only, so reopening is
the refresh — stated, rather than refresh machinery
being pretended. Both windows keep the house
manners: drag by the title with the rest-state
repaint, the shared 40×28 close and maximize boxes,
maximize and restore by the box and by the title's
double-click, true standing among the windows, the
drag clamp — and the desktop's law holds on every
new pixel: plain words only, no hex, no codes. The
bounds are stated, not hidden: the window's keeping
holds 48 entries of up to 31 letters, and the Reader
holds a file's first 9,760 bytes — a longer file is
read to there, and the page's last line says the
file goes on past what the window can hold. No file
on today's disc reaches either bound, and
WELCOME.TXT's page fits the Reader whole, so the
Reader's scroll stands proven as machinery — the
same buttons and keys, exercised on the Files list,
which does overflow — and waits for a longer text to
exercise it. `mem`'s in-use count at 4096 MB rises
twelve frames over milestone 18's (1,271 → 1,283):
the stone's one floor keeping — 12,288 bytes lent by
support.c for the list, the status line and the
Reader's page — is three of them, and the new kernel
code is the rest; the windows spend no frames and no
heap as they stand, scroll and open, their state
living in that keeping and the kernel's statics, as
the Terminal's grid has since milestone 13. The
floor otherwise did not change — the one keeping is
the whole of it, owned as milestone 18 owned its
widening. Proven in QEMU (TCG, the UTM shape) on the
UEFI door at the bench's 512 MB disc shape and on
the SeaBIOS door: the list against the same
session's `ls`, entry for entry; the Reader against
`cat`; both launches and the round trips; the
classic pair, the tampered feather refused, the
song's note list, and faulttest's halt, all as
before. The day's stones are witnessed together in
UTM at the run's end, as Tyler chose this morning.

Milestone 18 stands (November 10, 2026): **feathers with
faces — the door learns to draw, and a terminal becomes
a feather.** Seventeen milestones the kernel's hand was
the only one that drew; this stone opens the face to
guests, through the same door and behind the same walls.
The service door (interrupt 0x80) keeps its first suite
exactly — 0 exit, 1 write string, 2 write character,
3 yield — and gains a second: **4 screen size** (the
width home in the answer's low half, the height in its
high half, 0 when no graphical screen is the guest's),
**5 fill rectangle** (place, shape and colour named by
the guest; 0 when drawn, clipped to the screen; 1 when
refused whole — degenerate, or off the screen entirely —
with nothing drawn), **6 draw text** (the kernel's own
GUI letters at twofold size; at most 256 letters a
knock; the count drawn comes home), **7 read key** (the
next key as a character, Enter as 0x0A and Backspace as
0x08, or 0 when none waits — a guest waits by knocking
and yielding), and **8 poll mouse** (the pointer's place
and buttons, a reckoning the session itself keeps; the
kernel draws no pointer for a guest). A guest never
touches the framebuffer: it names places, shapes,
colours and words, and the kernel's hand draws. Draw
text proves its address and length against the guest's
own estate with exactly the write-string discipline —
and where service 1 has always answered a bad reach
with all-ones and let the guest walk on, draw text
stops the guest: a short protection report names the
address and the service at the screen's top, the
launching screen is restored, and the shell answers
with the stopping's words. The sharpening is
deliberate: a string mis-aimed is a guest's own loss,
but a face is painted in the user's sight, and the
door guards what it paints. The face rules stand as
law in the kernel and in docs/FEATHER.md: a graphical
guest takes the whole screen for its session (no
windowing of guests yet); on every road home — leaving,
fault, the door's stop, or the user's Esc — the covered
world is restored exactly, the desktop and the
Terminal's conversation repainted from their keepings
or the text shell blackened whole and its grid painted
back; graphical services belong to a session of one
guest, a pair's knocks refused with the reason spoken
once on the shared screen; and **Esc is always the
user's key** — milestone 15's stop stands armed through
graphical sessions, and a guest never receives Esc as
its own input. One floor change, owned plainly: the
door's stub now lifts the guest's saved rcx, r8 and r9
beside the first three words, three added moves, so the
wider knocks reach Swift whole; the first suite
observes nothing new. Two feathers ride the disc on
the new suite alone. FACE.FEATHER paints a greeting: a
parchment panel on a deep-cardinal field, the OS's
name, "Welcome to Cardnull OS.", John 1:1
(Douay-Rheims) drawn as text, and a small cardinal made
of thirteen honest rectangles — any key (but Esc, per
the law) sends it home. TERM.FEATHER is the stone
milestone 13 promised when it labelled the kernel's
Terminal window honestly: a terminal that *is* a
feather, standing on the door alone — its own framed
screen, prompt, echo with backspace, scrollback, and a
small command set of its own (`help`, which carries the
Esc law in its own words; `verse`, John 1:1 from its
own pages; `about`; `clear`; `exit`). While it runs,
the kernel's shell is not involved at all. Two bare
guests witness the walls: WILDRECT.BIN, refused its
degenerate rectangle and granted its too-large one
clipped to the whole screen, leaves cleanly; and
BADGFX.BIN, which paints its little panel and then
asks the door to draw text from the kernel's own
address 0x100000, is stopped under the report, the
screen restored and the shell standing. The proof is
three QEMU sessions (this bench, 512 MB, TCG as ever):
FACE and TERM from the desktop Terminal, TERM from the
text shell (its "versx" backspaced to "verse" on its
own prompt line; its wrapped verse and the shell's
one-line verse standing one screen apart), Esc during
TERM answered with the stopping's words and the
desktop whole, the classic pair and the spin pair with
milestone 15's own counts (9 by the door for the one;
5 and 5 for the other), the tampered feather refused,
`sound` singing its printed account, and the BIOS door
walked whole — boot to desktop, TERM, home, the shell
answering `verse`. `mem` read 1,530 frames used before
the graphical sessions and 1,530 after them on this
bench: a graphical session spends no frames and no
heap, claiming ground the boot already reserved. The
honest edges: the suite was witnessed at one
framebuffer size (1280 x 800) — its reckonings are
made from the size the door reports, and FACE and TERM
both ask before they paint, but a second width remains
unproven on this bench, as it has since milestone 16;
the mouse answer is data only, no guest-drawn pointer
was attempted; guests cannot sing (milestone 17's
absence stands); and Tyler's witness — the whole of
today's building, checked once at his word — is still
to come.

Milestone 17 stands (November 10, 2026): **first sound —
the PC speaker learns to sing.** Sixteen milestones the
machine was silent; this stone gives it the smallest
honest voice there is: the classic PC speaker, needing
no sound chip and no driver stack — the programmable
timer's second channel, gated to the speaker through
the two low bits of port 0x61. The kernel's tone is
three moves: reckon the channel's divisor from the
wanted frequency (the timer's clock, 1,193,182 Hz, over
the frequency — the same division the heartbeat's own
divisor 11932 came from), speak it to channel 2 under
the command word 0xB6, and open the gate for a duration
reckoned on the heartbeat itself, the kernel resting in
`hlt` between ticks. Then close the gate — and that
closing is the primitive's whole law: every note ends
with it, the phrase ends with it again, and no road out
of the playing leaves a tone standing. Channel 0, the
100 Hz heartbeat, is never written by the singing:
uptime, the scheduler's 100 ms slices, and the bar's
clock keep their beat through a song and after it. The
new command is `sound` (the help list grows to
seventeen): it plays one short phrase — the Doxology's
opening, "Praise God, from whom all blessings flow," on
the tune Old Hundredth (Louis Bourgeois, 1551, the
Genevan Psalter; public domain, as everything here is),
in G major: G4, B4, D5, D5, C5, B4, A4, and B4 held —
eight notes, some three and a half seconds — and prints
each note before it sounds, its name, its frequency,
and its length, so the playing is accountable on the
screen exactly where it cannot be heard. The shell
waits while the phrase plays; there is no background
music machinery, and none is pretended. The command
answers identically at the text console and in the
desktop Terminal, behind both firmware doors. The proof
on this bench is measured, not impressionistic: QEMU
routed the speaker to WAV captures, and the captures
were read sample by sample. Every note stands in the
recording at the frequency the screen printed —
392.0, 494.0, 587.0, 587.0, 523.0, 494.0, 440.0, and
494.0 Hz, measured against the same numbers printed —
each some 0.35 seconds long and the last some 0.70, in
the tune's order. Silence after the phrase is proven
two ways: the captures hold only the phrase's own
~3.08 seconds of tone even in the session that ran a
spin-pair of guests for a quarter of a minute after
the song (a stuck gate would have filled the file),
and a whole regression session's capture — feathers
opened, a fault taken — came back an empty header:
the speaker speaks only when `sound` asks it to. The
beat kept: `uptime` read 28 seconds before the song
and 45 after, the whole wall interval between the
readings with the song inside it, and the bar's clock
agreed at every screenshot. A spin pair run after the
melody in the same Terminal interleaved, A left with
its 5, Esc stopped the spinner, and the closing
account was milestone 15's own — "Switches: 5 by the
door, 5 by the timer." Feathers stand as ever (the
good one ran; the tampered one was refused and not
run), `faulttest` halts on 0xDEAD0000, and `mem` reads
1,271 frames used at 4096 MB — unchanged from
milestone 16: the kernel image grew 152 bytes
(140,744 to 140,896) and the growth was absorbed
inside frames already counted, so the honest delta
is zero. Two absences are part of the stone, stated
plainly: guests cannot sing — the door gains no sound
service, and a feather's voice is future work — and
no audio chip is driven; the intel-hda in the test
machine sits silent still. The final witness is
Tyler's, and for this stone it is his ears: his UTM
configuration carries intel-hda for sound, and
whether UTM sounds the PC speaker at all is itself
part of what his run will tell us. If he hears
nothing, that is a finding to record, not a failure
to hide — the printed account and the bench's
captures are what the stone claims, and no more.

Milestone 16 stands (November 9, 2026): **desktop polish —
the bar never crunches, the desktop speaks plain words,
and the windows carry surely.** This stone is Tyler's own
witness of milestone 14, taken as a specification: "do you
see how the screen buttons get crunched, it moves windows
like an OS but its still a little wonky, i want it to be
intuitive, no codes at the bottom, only in the terminal."
The face itself is unchanged — same deep cardinal, same
gold name, same parchment card; what changed is its fit
and its manners. **The bar has a layout now, reckoned
from the framebuffer's own width** instead of offsets
fixed for one screen: a sixteen-pixel margin at each end;
the mouse's standing word at its full width; then the
Terminal and Welcome launchers, each sized from its own
label (160 and 144 pixels) with the standing stripe that
says its window stands; open ground; the uptime, its
patch right-anchored to end one gap before the Home
button (96 pixels, one margin from the right edge),
painted only when the whole patch stands clear of the
Welcome launcher with a gap to spare. At 1280 x 800 the
row stands thus: standing 16..192, Terminal 216..376,
Welcome 392..536, the clock ending at 1152, Home
1168..1264 — every element whole, with air around it.
If a narrower screen ever asks more than the row holds,
the gaps give first (the standing's 24 becomes 12, the
launchers' 16 becomes 8); the furniture never shrinks,
nothing overlaps, and a word that cannot stand whole is
shortened in plain language or left off — never
squeezed into a sliver, which is how milestone 14's bar
wore the Welcome launcher on Tyler's screen and crowded
the uptime off entirely. One honest limit: the proof
stands at 1280 x 800. Four attempts to make this bench
offer a second width — a GRUB gfxmode line, gfxpayload
behind the BIOS door's VBE, the virtio-vga's own
resolution properties, and the adapter's EDID switched
off — were all answered with the same 1280 x 800; every
chooser on this bench takes the adapter's preferred
mode and no hint we are willing to ship moved it. The
reckoning itself is width-parametric in the code and
stated here, so a screen of another width — UTM's own
resizable window among them — meets a bar composed for
it, and Tyler's witness there is the test, as ever.
**The desktop speaks plain words only.** The bar's mouse
line, which wore the boot report's diagnostic sentence
("Mouse: answering (id 0x00).") through milestone 15,
now reads "Mouse ready" when the mouse answers and
"Mouse not answering" when it does not. Every string
the desktop paints was swept — title bars, launchers,
the card, the bar, the clock ("Uptime 0:00:11") — and
nothing technical remains on the face. The codes were
not deleted; they were given their proper home. A new
shell command, `mouse` (the help list grows to sixteen
command words, counting `memory`, `mem`'s other name),
prints the mouse's full report exactly as the boot
screen speaks it — "Mouse: answering (id 0x00)." and
the wake line with its config, reset, self-test,
defaults, and reporting values and its tries — followed
by the answers the face has honestly taken from it
since: bytes, packets made whole, and presses of its
button. In the witnessed run, after a full desktop
visit, the text shell's `mouse` read 204 bytes, 68
packets, 12 presses — the bytes exactly three to a
packet, as the protocol promises. The command answers
identically in the Terminal window and at the text
console, and the boot screen's own transcript is
untouched: it is the machine's console face, spoken
before any desktop exists. **The windows carry
surely.** The title-bar controls now keep one geometry
on both windows, reckoned once and shared: boxes 40 by
28, four pixels below the strip's top, eight from the
window's right edge, eight apart — the Terminal's
maximize box widened from 36 to 40 to stand equal with
the close box, its glyph recentred — and a press is
judged by the very rectangle that is painted, so a
control's reach is exactly what its face promises. A
dragged window's title bar wears its held look — a lit
cardinal — for the whole carry, so the hand knows what
it holds; the outline travels as ever, and on release
the window is painted whole, once. The clamp is a
stated rule, not a hope: sideways, the title bar always
keeps a reachable strip on the screen — at least 120
pixels of it, with the close box inside the screen's
edge — and up and down, the whole title bar stays
inside the work area, its foot four pixels above the
bar's head, so no window can be carried where it cannot
be taken back. The proof carried the Welcome card by
its title toward the bottom-left corner, past the edge:
it landed at (-224, 724) with its close box standing
at (196, 742), and was closed from there. And the
convention people already know arrived: a second plain
press in the Terminal's title bar within half a second
of the first — fifty ticks of the heartbeat — trades
the window between its own place and the whole work
area, down the maximize box's own road, the
conversation standing through both; any other press
puts the pairing down, so two honest drags never marry
into a resize. Focus stays unmistakable — the window
holding the room wears the bright title, the other
dimmed, and a press on any visible part raises it —
re-proven across the card and the Terminal. Nothing
else moved, and the regressions were run to prove it:
the card's counter still counts; a spin pair in the
Terminal stops on Esc with its accounts whole —
"/spin.bin was stopped.", "/a.bin exited: 5",
"Switches: 5 by the door, 5 by the timer." — and
`verse` answers after; behind the BIOS door the whole
road stands (desktop, verse in the Terminal, Home, the
shell answering verse; the wake transcript reading
config 41 to port 43, as that door has always honestly
differed). The accounting stays truthful: `mem` behind
the UEFI door at 4096 MB reads 521,420 frames free of
522,691 (1,271 used) — one frame more than milestone
15's 1,270, and the reason is the kernel's own growth
(140,744 bytes of image against 135,704); the visit
itself, as ever, spends nothing, the face painting
ground the boot already owned. Two bench notes ride
with the record, stated plainly. At the bench's 512 MB
shape — the size at which this bench's firmware keeps
the disc reachable — a pair session's first visible
output lags the typed command by some seconds while
its disc reads land; the session runs throughout, and
its tokens, endings, and accounts arrive whole, as
milestone 15's own mid-session shot caught the same
frame before the same session. And this build's first
draft taught the old Embedded Swift lesson again: a
nested helper inside the bar's layout faulted the
kernel before the desktop opened ("Exception -
halting." over the boot lines), and the reckoning was
inlined to plain statements, after which the tree
rebuilt clean. (The build recipe itself stands proven
against the unmodified milestone-15 sources, whose
kernel it reproduced byte for byte before this
milestone's edits began.) Verified in QEMU under UTM's
own conditions (q35, TCG, virtio-vga, QEMU 10.0,
front-end input delivery): the composed bar, the
`mouse` command in both its homes, the word sweep over
the open card, drags witnessed mid-carry and at rest,
the corner clamp and its retrieval, the double-click
in both directions, and the regressions above.
Tyler's own UTM witness from the home-folder copy
stands as the final word, as with every milestone.

Before that, milestone 15 (November 9, 2026): **the timer takes
turns by force — preemptive scheduling.** Milestone 10's
guests held the machine by courtesy, each keeping it until
it yielded at the door, and a guest that never yielded was
never interrupted; that limit is retired. While a pair
session stands, the PIT's heartbeat now counts against the
running guest's slice — ten ticks, a tenth of a second at
its 100 Hz — and a spent slice ends the turn whether the
guest knocks or not: the floor's timer stub writes the
guest's whole state out of the interrupt's own frame (all
fifteen registers, its place, its flags, its stack's top)
into its book, and the shared entering hand resumes the
partner from the partner's book, the paused guest unable
to tell it was ever stopped. The kernel's own work is
never preempted — a tick that finds the kernel running
only counts, as it always has. The witness is a new guest
on the disc, SPIN.BIN, which never yields and never
leaves: it prints a token, burns a long stretch of the
processor in a tight loop, and prints again, forever.
Paired with A (`both /spin.bin /a.bin`), A counts out all
five of its tokens among SPIN's — in the witnessed run,
S1 A1 S2 A2 S3 A3 S4 A4 S5 A5 down the screen — and
leaves, on slices the timer cut out of SPIN's spinning;
SPIN runs on alone (to S71 in the Terminal's witnessed
run) until Esc, which every session's opening line now
names — "Press Esc to stop the session." — stops it, the
report reading "/spin.bin was stopped." beside
"/a.bin exited: 5". The same word ends a lone
`run /spin.bin`. The pair's report closes with the
session's own accounting, so the forcing is a number and
not an impression: "Switches: 5 by the door, 5 by the
timer." — the door's turns (yields, and the hand-over
when one guest ends and its partner runs on) beside the
timer's (slices spent while both guests lived; a guest
running alone takes fresh slices and no switch is counted,
because there is no one to switch to). The courteous pair
reads exactly as it did in milestone 10 — A1 B1 A2 B2 A3
B3 A4 B4 A5 B5 B6 B7, exits 5 and 7 — and its account is
all door and no timer (9 by the door, 0 by the timer),
because courteous guests finish before any slice runs
out; the wall stands as ever (`both /bad.bin /a.bin`: BAD
stopped, A counting out undisturbed, one door switch —
the fault road's hand-over). The milestone's proof also
caught a hazard older than itself, and the record keeps
it plainly: the floor's C was keeping its locals in the
red zone below the stack pointer, where an interrupt's
frame lands when it arrives, and a timer frame overwriting
memset's own count — caught in the act by an emulator
trace, mid-launch, the count replaced by the interrupted
address itself — sent memset marching into the kernel's
own text before the fault stopped it. The hazard is as
old as milestone 4's first interrupt stub; the longer
sessions merely dealt it enough chances, and its usual
price before today was silent — a table page zeroed short
or long, in ground teardown later freed. The floor's C is
now compiled with the red zone off (-mno-red-zone), as
kernel code must be, and the traced soak that caught the
fault runs clean. The accounting stays truthful:
`mem` behind the UEFI door at 4096 MB reads 521,421
frames free of 522,691 (1,270 used) — milestone 14's
figure unchanged, scheduling keeping its books in the
floor's own storage and taking no frames and no heap —
and at the bench's 512 MB a spin session leaves `mem`
byte-identical before and after (127,947 free of
129,475), its estates handed back whole. The supervisor
road is untouched: `faulttest` still reports 0xDEAD0000
with error 0x0000 and halts. Verified in QEMU under UTM's
own conditions (q35, TCG, virtio-vga, QEMU 10.0, front-end
input delivery): the spin pair in the Terminal and at the
text console, mid-session and stopped; the lone spin and
its stopping; the classic and the bad pairs in both
consoles; faulttest in its own boot; and the whole road
again behind the BIOS door — desktop, spin pair in the
Terminal, Esc, Home, and the text shell answering verse.
Tyler's own UTM witness from the home-folder copy stands
as the final word, as with every milestone.

Before that, milestone 14 (November 9, 2026): **room to breathe —
the desktop is rearranged around the Terminal.** Tyler's
word on the milestone-13 face was that the GUI "looks a
little off like not enough space for a terminal," and he
was right: the window he works in was squeezed beside an
equal. Now the Terminal opens large — at 1280 x 800, a
1248 x 664 window over the whole work area between the
desktop's name and a new bottom bar — and its grid is
reckoned from its window: 76 columns by 37 rows (2,812
cells) where the fixed 40 x 31 (1,240) stood. The grid's
floor keeping became a capacity — a stride of 120 columns
and room for 64 rows (7,680 bytes) — and the visible shape
moves within it, scrubbed and clamped honest at every
change, so resizing never garbles the conversation. The
Welcome window is demoted, not deleted: a compact
448 x 320 card carrying the same greeting, the same John
1:1 (Douay-Rheims) with its line breaks rewrapped to four
shorter lines, and the same counting button — closed at
the opening, called up from the bar. The bottom bar
stands across the screen's foot, painted last so no
window covers it: the mouse's standing line in its old
words, a launcher for each window (a cardinal stripe
under a launcher says its window stands), the session's
uptime counted off the timer's own ticks and labelled
"Uptime" because that is what it is, and a Home button.
The windows can be carried by their title bars — an
outline follows the pointer, drawn in pixels opposite to
the ground so it erases itself exactly, and the window is
painted whole at rest — and the Terminal carries a
maximize control: maximized it fills the work area
(1280 x 676, a 78 x 38 grid), restored it returns to its
own place, the conversation standing through both. The
ways home were re-decided plainly: both windows' close
boxes now close only their window; the face's roads home
are the bar's Home button, which works from every
standing of the room, and Esc under its standing rule
(the shell's key while the Terminal holds the room, the
way home whenever it does not — and closing the Terminal
or pressing the card, the other window, or bare desktop
arms it again, so no one is ever trapped). The accounting
stays truthful: the face still takes no frames and no
heap at runtime, and `mem` behind the UEFI door at
4096 MB after a desktop visit reads 521,421 frames free
of 522,691 (1,270 used) — five frames more than
milestone 13's 1,265, the whole difference being the
kernel's own larger image (this milestone's code, and
the grid keeping's growth from 1,240 to 7,680 bytes of
it); the boot mouse transcript reads exactly as before.
Verified in QEMU under UTM's own conditions (q35, TCG,
virtio-vga, QEMU 10.0, front-end input delivery): a cold
boot into the desktop with the large Terminal standing
and the bar beneath it; `help`'s full list unwrapped at
76 columns and three helps scrolling clean through the
37 rows; the card opened from its launcher, "Clicks: 1"
counted at its new size, dragged by its title bar to a
visibly new place with the screen clean after, and
closed; the Terminal maximized and restored with its
conversation intact; the Terminal closed and reopened
from the bar with its conversation kept; home by the
Home button to a shell that answered `mem`; `ls` and
`both /a.bin /b.bin` (turns interleaved, exits 5 and 7)
inside the large Terminal at 512 MB, this bench's
disc-reachable size, as in milestone 13; and the BIOS
door regressed whole — boot into the new desktop,
`verse` in the Terminal, home by Esc. The final witness,
as ever, is Tyler's own UTM — where the one step the
screen cannot take for him stands as milestone 13 left
it: click UTM's "Capture Input Devices," and the mouse
walks through.

Milestone 13 stands (November 9, 2026): **the OS wakes into
its face — and the mouse's silence is answered.** Three
stones. First, the mouse, re-woken properly: milestone 12's
UTM witness came back partial — the desktop drew perfectly
on Tyler's Mac, but the pointer never answered, not one
packet from birth. The waking is now the full standard
ceremony, in the standard's order — the controller's
auxiliary port enabled, its configuration byte read,
amended and written back, the mouse itself reset (0xFF)
with its acknowledgment, its self-test word (0xAA) and its
device ID all heard, defaults set, reporting enabled —
every wait bounded by the 100 Hz heartbeat rather than a
spin count, so a slow emulator's late answer is waited for
in wall-clock; one whole retry if the first attempt hears
silence; the configuration byte re-read after the waking
and again at the desktop's opening, and healed if anything
undid it; and the face polls the mouse's port directly as
well as listening to IRQ12, so a silent interrupt road
cannot starve the pointer. Every answer is kept and
spoken: the boot report gains two lines — "Mouse:
answering (id 0x00)." and the waking's transcript in short
("wake: config 47, reset FA, self-test AA, defaults FA,
reporting FA, port now 47, tries 1" behind the UEFI door;
behind BIOS the firmware leaves the byte at 41 and the
amendment stands at 43) — and the desktop's bottom edge
carries the standing line in the same words, so the truth
about the mouse is readable on Tyler's own screen either
way. Second, the front door moved: when the boot's news is
spoken, the desktop opens on its own. The text shell is
one Esc — or one close-box click — away, `gui` re-opens
the face, and nothing is lost by the move. Third, a second
window stands on the desktop: the Terminal, hosting the
kernel's own shell (the built-in shell in a window,
honestly — not a feather; a true terminal feather still
waits on guest drawing and keyboard services). It keeps
its own 40 x 31 grid in a floor lending, so the console's
conversation stands untouched behind the desktop; all
fourteen commands run in it, and `run`, `both`, and
`feather` print inside the window — the output door simply
opens onto whichever grid is home. Clicking a window
gives it the keyboard (its title bar wears the bright
cardinal; the other rests dimmed); the Terminal's close
box closes only the window, and a launcher on the desktop
calls it back with its conversation intact; `gui` typed
inside it answers plainly that you are already here. Esc
is predictable and documented: the shell's own key while
the Terminal holds the room, the way home whenever it
does not. The face remains frugal: `mem` behind the UEFI
door at 4096 MB reads 521,426 frames free of 522,691
(1,265 used) at the console after a desktop visit and
inside the Terminal alike — the desktop and its windows
take no frames and no heap. Verified in QEMU under UTM's
own conditions (q35, TCG, virtio-vga, 4096 MB, front-end
input delivery) on QEMU 8.2 and 10.0 alike: a cold boot
straight into the desktop with the standing line reading
answering, the pointer moved and "Clicks: 1" counted,
`verse` and `help` answered inside the Terminal, the
Terminal closed and reopened with its conversation kept,
Esc's two standings both witnessed, and the shell home
again by Esc and by the close box with `mem` unchanged;
the disc commands (`ls`, `run /count.bin`,
`feather /hello.feather`, `both /a.bin /b.bin`) witnessed
inside the Terminal in the UTM shape at a memory size
this bench's firmware keeps the disc in reach of (at
4096 MB the bench's OVMF parks the AHCI controller beyond
the kernel's 4 GiB reach — the milestone-12 kernel reads
the same "No CD-ROM drive answered" there, so it is the
bench's firmware, not this milestone's change; Tyler's
UTM read the disc at 4096 MB through milestones 8-11);
and the BIOS door regressed whole — boot into the
desktop, `verse` in the Terminal, home to the shell. The
final witness, as ever, is Tyler's own UTM.

Milestone 12 stands (November 9, 2026): **the OS gets a
face — and with it, the original ladder is complete.** A
fourteenth command, `gui`, leaves the text console and draws
a desktop on the framebuffer the boot provided: a
deep-cardinal gradient, the Cardnull OS name standing in
gold, and one window — Welcome — with a cardinal title bar,
a parchment body, the greeting, and John 1:1 in the
Douay-Rheims, in three lines with its attribution. The
mouse is a citizen now: woken once at boot (the PS/2
controller's ceremony, spoken with the interrupt gate still
closed, because it shares a data port with the keyboard),
it reports by IRQ12 — the slave PIC's fourth child, its
gate and masks raised with the rest — into a ring the face
drains, three bytes to a packet. The pointer is a
twelve-by-sixteen arrow that opens at the screen's centre;
the pixels beneath it are lifted into a cushion the floor
lends before it is drawn and laid back when it moves, so
it leaves no trail. There is one honest interaction: a
button in the window that counts its clicks — "Clicks: 1"
stands witnessed — wearing its pressed face exactly while
the packet's own button bit says the real button is held.
And there are two ways home, both always open: the
window's close box, a drawn square carrying an X, clicked;
and Esc. Either restores the text console exactly — the
grid was never touched, so the conversation stands as it
was — and the shell answers the next command in the same
session. The face is frugal by construction: it paints
the framebuffer the boot already owned and keeps no back
buffer, so it takes no frames and no heap: behind the UEFI
door, `mem` reads 29,831 frames free of 31,176 before a
visit and 29,831 after it (1,345 used — four more than
milestone 11's count, the grown kernel and its tables
alone). What the face is not is stated in its own section
of the kernel: one window, in one place, that cannot be
dragged or resized; no window manager; and no program but
the kernel draws — graphical feathers are a later era.
Verified in QEMU behind both doors — the desktop, the
moved pointer, the counted click, `help`'s fourteen
commands, and both roads home under UEFI (`verse` answered
after the close box, `mem` after Esc); the desktop, a
counted click, and the Esc road home behind BIOS, whose
GRUB hands over the same kind of framebuffer.

Before that, milestone 11 (November 9, 2026): **the OS learns its
own package format — the feather.** The format is written
down in `docs/FEATHER.md`: one file holding a plain-text card
and, behind a line of three dashes, the program itself — a
flat guest image of exactly the kind `run` loads. The card
names the program before it runs — title, maker, version,
and the maker's support line (support being voluntary income
for the maker, never a tax-deductible donation) — and
carries the packer's reckoning: the program's size and its
FNV-1a 64-bit checksum. A thirteenth command, `feather`,
reads the file whole into a heap block, parses and proves
the card, prints it — the honest label, read first — and
only then lays the program into an estate and runs it down
milestone 9's road: same tables, same door, same reports.
The first feather stands on the disc: HELLO.FEATHER
(493 bytes), maker Cardnull, its program the greeting guest
in `feathers/greet.s`, packed by `tools/pack-feather.py`
from the card source in `feathers/` — "Hello! I am the first
feather Cardnull OS ever opened." The refusals are proven
beside it. TAMPERED.FEATHER — the same package with one
program byte flipped after packing, its checksum left stale
on purpose — is refused and not run: "That feather's
program does not match its card's checksum - it may be
damaged or altered. It was not run." `feather /hello.bin`
answers "/hello.bin is not a feather.", and foreign shapes
meet the same word — the OS does not interpret what is not
a feather. And `run /hello.feather` refuses in its turn —
"/hello.feather is a feather - a package with a card. Open
it with: feather /hello.feather" — because a raw loader
executing a card as code is exactly what the format exists
to prevent. The checksum's modesty is spoken on screen
beneath every card — "Integrity: checksum verified - an
integrity check, not a signature." — and in the format's
document: the reviewed, cryptographically signed feather
belongs to the store era, and nothing here claims or
imitates it. The teardown is the old honesty: `mem` reads
the same numbers before a feather run and after it (behind
the UEFI door, 29,835 frames free of 31,176 both times),
and `heap` stands at its resting books. One building note,
because the disc changed shape to make room: the ISO is
now written at ISO 9660 level 3, so names longer than the
old 8.3 stand whole in the disc's tree — HELLO.FEATHER, not
HELLO.FEA; every older name on the disc keeps its exact
shape. Verified in QEMU behind both doors — the opening,
the three refusals, and the identical `mem` under UEFI;
`feather`, `mem`, and `heap` as the BIOS regression.

Before that, milestone 10 (November 9, 2026): **two programs at
once, taking turns.** The disc carries two more guests beside
milestone 9's three — A.BIN and B.BIN, 90 bytes each, from
assembly sources in `programs/` — and a twelfth command,
`both`, loads two guests the way `run` loads one: two files
resolved off the disc, two estates built on the same fixed
ground under two roots, two images laid in. The floor's pair
launch then enters the first, keeping each guest's whole state
— its page tables, its stack pointer, its place, its flags,
its registers — in one of two books in the floor's own storage.
The door has a third service now, yield: a guest that knocks
with it has its state written into its book and its partner
woken exactly where the partner last yielded, in the partner's
own ground; a guest that leaves or falls hands the machine to
its partner the same way, and the pair comes home only when
both books say finished. A.BIN prints five tokens, yielding
between; B.BIN prints seven — `both /a.bin /b.bin` reads
A1 B1 A2 B2 A3 B3 A4 B4 A5 B5 B6 B7 down the screen, B's last
two alone after A has left — and the reports speak each ending
truly beside its name: "/a.bin exited: 5", "/b.bin exited: 7"
(the guests leave with their counts, so the report can be
checked against the screen). The wall stands under company:
`both /bad.bin /a.bin` stops BAD at the kernel's first byte —
the report, "protection violation, user mode" — writes it down
as stopped ("/bad.bin was stopped."), and carries the machine
to A, which counts out its five tokens undisturbed in the same
session, after which the shell answers `verse`. When a session
ends, both estates are taken back frame by frame: `mem` reads
the same numbers before it and after it (behind the UEFI door,
29,838 frames free of 31,176 both times; behind the BIOS door,
1,337 used of 32,638). The keeping is cooperative, stated
plainly: a guest that never yields keeps the machine — nothing
in this milestone takes it by force — and two guests is the
measure, not a process table in disguise. `run` is untouched:
one guest, start to finish, exactly as milestone 9 left it.
Verified in QEMU behind both doors — the interleave, the
stopping under company, and the identical `mem` under UEFI;
`both`, `mem`, and `heap` as the BIOS regression.

Before that, milestone 9 (November 9, 2026): **the OS runs something
that is not itself.** Three small programs live on the disc as
files — HELLO.BIN (234 bytes), COUNT.BIN (103), BAD.BIN (27) —
assembled from assembly sources kept in `programs/` and packed
beside WELCOME.TXT; none of their bytes is in the kernel. A new
command, `run`, loads one through the milestone-8 reader into
ground built for it alone: page tables cloned from the kernel's
with a single private branch toward the guest, so the image's
pages stand read-and-execute and never writable (W^X holds for
guests too), beside a scratch page and a four-page stack, all on
a fixed estate at 0x40000000. The guest runs in **ring 3**,
entered through `iretq`, with the kernel's whole map present in
its tables but stamped supervisor along every branch — shown
the wall, never able to climb it. Its one door back is
interrupt 0x80, the only IDT gate stamped for ring 3: write a
string, write a character, or exit with a code, which the shell
then reports truly ("Program exited: 0"). HELLO greets in its
own words — "the first program Cardnull OS ever ran"; COUNT
reckons 1 to 10, digit by digit, in its scratch page. And BAD,
the crown proof, reaches for the kernel's first byte at
0x100000 and is stopped: "Page fault in a guest program - the
guest was stopped.", address 0x0000000000100000, error code
0x0005 — "read, protection violation, user mode" — after which
the shell answered `verse` in the same session, unharmed. When
a guest leaves or is stopped, its estate is taken back frame by
frame: `mem` reads the same numbers before a run and after it
(behind the BIOS door, 1,321 frames used of 32,638 — five more
than milestone 8's count, the grown kernel and its tables
alone). `faulttest` keeps its old road: a supervisor fault
still reports and halts. Verified in QEMU behind both doors —
`ls` of the three guests, both good runs, and the stopping
under UEFI; `run`, `mem`, and `heap` as the BIOS regression.

Before that, milestone 8 (November 9, 2026): **the OS reads its own
disc.** The boot now speaks one more line beneath the banner —
"Disc: QEMU DVD-ROM, AHCI port 2." — because the kernel carries
a driver for the drive it booted from. The machines this kernel
boots on hang their CD-ROM off an AHCI controller — an IDE
device on one of the controller's buses, with no legacy IDE
port hardware anywhere in the machine — so the driver finds the
controller in PCI configuration space by its class (asking
every function of every device: the controller is the second
function of its slot), maps the controller's registers into
the kernel's own page tables, and takes the first port whose
device signs itself ATAPI and answers IDENTIFY PACKET DEVICE.
Above the driver stands a read-only ISO9660 reader: the Primary
Volume Descriptor at sector 16 must carry its CD001 signature,
directory records are walked as the format lays them, and paths
are matched letter for letter without caring about case, the
disc's ";1" version suffixes forgiven. The disc carries a file
the kernel was never told about: WELCOME.TXT, packed into the
ISO at build time — a greeting from Cardnull and John 1:1 in
the Douay-Rheims — which exists nowhere in the kernel and can
only be read off the disc itself. Two commands join the shell:
`ls` lists a directory with sizes (`ls /boot` shows GRUB and
KERNEL.BIN — 80,448 bytes as the kernel stands after milestone
9), and `cat` prints a file from the
disc — `cat /welcome.txt` prints the greeting and the verse,
and `cat /boot/grub/grub.cfg` prints GRUB's own config, read
back off the disc that booted it. Errors are plain and true:
"Not on the disc: /nope.txt"; "/boot is a directory, not a
file." Sectors are asked for one at a time with the READ (10)
packet over the ATA PACKET command, the controller's engine
walking each into memory — nothing is written, nothing is
cached past the sector in hand. `mem`'s books grew honestly
again: behind the BIOS door, 1,316 frames used of 32,638
(milestone 7's 1,308, plus the driver's two DMA frames, the
controller's mapping tables, and the grown kernel). Verified
in QEMU behind both doors — `ls`, both `cat`s, and the errors
under UEFI; `ls`, `cat`, and `mem` as the BIOS regression.

Before that, milestone 7 (November 9, 2026): **the kernel keeps its
own house.** The kernel no longer runs on the boot floor's
borrowed page tables — one wide identity map where every page
stood writable and executable. It builds tables of its own, out
of the frame allocator's pages: four levels of 4 KiB leaves,
identity-mapped over the usable RAM, the kernel image, the
framebuffer, the VGA text page, and the bootloader's own
information — and nothing else; the holes and the PCI dark are
simply not there, and reaching for them faults. In the leaves,
the hardening road's first law is laid down — W^X: the kernel's
text pages executable and not writable, its read-only data
neither writable nor executable, everything else mapped
writable and never executable. The page fault grew up with the
tables: vector 14 has a hand-written stub that carries the
faulting address (CR2) and the error code up to a handler that
reports both, in hex and in words, and halts the machine
cleanly. A new command, `faulttest`, reaches for an address no
page covers (0xDEAD0000) so the report can be witnessed rather
than believed: behind both doors it answers "Page fault -
halting." with the address 0x00000000DEAD0000 and the error code
0x0000 — "read, page not present, supervisor mode" — and rests,
with no reboot loop. And the kernel has a heap: 4 MiB of frames
in one unbroken run, a chain of first-fit blocks with splitting
and coalescing, its books reckoned by walking the chain; a boot
self-test takes blocks, writes patterns, reads them back byte
for byte, frees the middle one and takes a smaller block into
the freed chair, and passes only on exact verification. A
seventh command, `heap`, speaks those books — after the
self-test, "Used: 0 bytes in 0 blocks / Free: 4194304 bytes in
1 block". `mem` still tells the map's truth, and its used count
has honestly grown by the new buildings: in QEMU with 128 MiB,
the BIOS door reports 32,638 frames with 1,308 used (milestone
6's 212, plus 72 pages of tables and the heap's 1,024), the
UEFI door 31,176 frames with 1,309 used. Verified in QEMU
behind both doors: the shell alive and answering on the far
side of the CR3 switch — help, verse, mem, heap — and the fault
report standing under `faulttest`.

Before that, milestone 6 (November 9, 2026): **the kernel knows its
memory.** The Multiboot2 information GRUB hands over carries a
memory map, and the kernel now reads it — every region's base,
length, and kind — and raises a page-frame allocator over the RAM
the map calls available: one bit per 4 KiB frame in storage the
boot floor lends, every frame spoken for until the map expressly
frees it, and reservations laid back over the pool for the first
megabyte, the kernel image itself, the framebuffer, the
bootloader's own information, and anything the map does not call
RAM. A boot-time self-test takes and returns frames and passes
only if the free count comes home exactly. A sixth command joins
the shell: `mem` (or `memory`) speaks the machine's true numbers —
usable RAM in bytes, total frames, free frames, used frames —
reckoned at runtime from the real map, so the same kernel answers
differently behind the two doors, because the two firmwares' maps
honestly differ: in QEMU with 128 MiB, the BIOS door reported
133,688,320 usable bytes and 32,638 frames (32,426 free), the
UEFI door 127,696,896 bytes and 31,176 frames (30,963 free), the
self-test passing behind both. Nothing is paged and there is no
heap yet — handing frames out, one by one, is this milestone's
whole work.

Before that, milestone 5 (November 6, 2026): **one ISO, two doors.** The
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
door it came through: the same commands answer behind both,
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

Not yet, honestly — the later doors, now that the ladder
stands climbed: a writable disc and an installer — the OS
still lives on a read-only CD, read by its own driver;
a hard drive it can write to, and an installer that lays
it there, are the road to a machine of its own; more
than two programs alive at once — milestone 15's timer
enforces the turns between them, but the floor keeps two
guest books, no wider table; the signed feather and its
store — milestone 11's checksum proves a program matches
its card, and no more; the reviewed, cryptographically
signed feather of the store era, the only kind that will
one day be allowed to carry real programs as citizens, is
a stone still ahead; networking — no driver, no stack, no
wire spoken to yet; Little Cardnull, the small local model
that is to live on Cardinal computers, which waits on
everything above having somewhere to live; the face's own
growing — milestone 12's window stands in one place,
undragged, and no program but the kernel draws; more
windows, a window manager, and graphical feathers are
their own era; USB input — under either firmware, a
USB-only keyboard or mouse is beyond us still, which is
why the UTM drill keeps the PS/2 controller forced on and
USB input off; and a native EFI entry of our own — the
UEFI door today is GRUB's EFI build loading the same
Multiboot2 kernel, so it is GRUB that speaks to the
firmware and calls ExitBootServices on that road.
Those are the milestones onward, taken one at a time.
