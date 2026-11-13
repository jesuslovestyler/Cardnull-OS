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
   Virtual Machine → Emulate → PC**; memory is yours to give it —
   4096 MB is the standing witness size, and since the loader
   repair of November 13, 2026 the house is proven to boot the
   same from 512 MB to 8192 MB, so no size needs lowering for
   its sake; no hard drive is needed yet — the OS lives
   entirely in the boot image).
2. Set the CD/DVD drive to `dist/cardnull.iso` (machine settings →
   Drives → the CD drive → Browse), and make sure the boot order puts
   the CD first. (Behind the BIOS door: or press Esc at the SeaBIOS
   screen and choose the CD-ROM. Behind the UEFI door — Edit → QEMU →
   **UEFI Boot** checked — the firmware finds the disc's UEFI entry
   on its own; give it some seconds on the TianoCore splash.)
3. Start the machine.
4. When the desktop stands, give it the mouse: click UTM's
   **Capture Input Devices** (the mouse-capture control in the
   VM window's toolbar). This is the door the host mouse walks
   through in UTM — without it the desktop draws perfectly and
   the boot report reads "Mouse: answering," yet the pointer
   never moves, because your mouse never reached the machine.
   (Milestone 13's lesson, learned on this very drill.) Press
   the capture key combination UTM shows you when you want
   your mouse back.

## What you should see

Our own bootloader signs its work first — quickly; on the BIOS door
the lines read "Cardnull Bootloader — Cardnull OS behind the BIOS
door, loaded by our own hand" (the UEFI door names itself so) — and
then a black screen with one word at the top left:

```
CARDNULL

> 
```

That is the Swift kernel running: the boot floor woke the processor,
walked it into 64-bit long mode, and handed control to `kmain`, which
cleared the screen, wrote the banner, and opened a prompt. Above the
prompt stand the boot's two reports: the disc's news (its name, or
the plain word that no drive answered) and — since milestone 13 —
the mouse's: two lines telling whether the mouse answered its
waking, and what each step of the waking heard. Read them; they are
the machine's own testimony. The desktop's bottom bar carries
the first of them in plain words — "Mouse ready" — and the
`mouse` command, below, speaks the whole report again whenever
you ask.

Then — since milestone 13 — the desktop opens on its own: the OS
wakes into its face now, and the shell's conversation continues
inside the Terminal window standing on it (the face is described
at the end of this walk). The text console above is never lost:
the desktop's Home button — or Esc, whenever the Terminal does
not hold the keyboard — brings it back exactly as it stood,
and `gui` opens the face again.
Click into the machine's window and type — the whole
keyboard answers: letters, digits, punctuation, Shift and Caps Lock
for capitals, Backspace to take back what you typed (never the
prompt). Fill the screen and it scrolls, like any terminal.

Press Enter and the prompt answers. Nineteen commands, for now:

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
- `files` — open the Files window on the desktop: the disc,
  browsable with the mouse
- `gui` — open the graphical desktop (Esc brings you home)
- `mouse` — the mouse's report: its waking transcript, and what
  the face has taken from it since
- `sound` — play a short melody on the PC speaker
- `net` — the network card: take a lease on the wire
  (DHCP, held for the session), answer ARP and ping,
  and report the whole account

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
so the kernel draws its letters as pixels, and our own BIOS
bootloader sets a graphics mode behind the BIOS door too
(milestone 24; GRUB set it before), so the letters are drawn
there as well — possibly larger than before, depending on the
mode offered. The words are the same.)

One more thing to try since milestone 8: watch the line under
the banner as the machine boots — "Disc: QEMU DVD-ROM, AHCI
port 2." (the drive's name and port will read as UTM's drive
reports them). That is the kernel finding the very disc it
booted from and reading its table of contents. `ls` shows the
disc's root — BOOT, EFI.IMG, and the system's own files,
WELCOME.TXT among them, a greeting that lives only on the
disc. `cat /welcome.txt` reads it back, sector by sector: a
welcome from Cardnull and John 1:1 in the Douay-Rheims. (The
disc once carried GRUB's own config to read the same way;
since milestone 24 there is no GRUB on it to read.) Paths do
not care about capitals, and asking for what is not there is
answered plainly. Reading is all the disc gets — nothing is
written, ever.

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
turns was cooperative when this milestone landed: a program
held the machine until it yielded, left, or fell — nothing
snatched it away. Milestone 15 changed the keeping, and its
own walk stands below; two programs is still the measure,
no more. The wall stands with
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

And since milestone 15, the disc carries one more guest —
SPIN.BIN — and turns are no longer a courtesy. SPIN never
yields and never leaves: it prints a token (S1, S2, S3,
and upward), burns a long stretch of the processor in a
tight loop, and prints again, forever. Try
`both /spin.bin /a.bin`. Every session now opens with a
guidance line — "Press Esc to stop the session." — and
then, where milestone 10's keeping would have let SPIN
hold the machine and starve A outright, A counts out all
five of its tokens among SPIN's (S1 A1 S2 A2 S3 A3 S4 A4
S5 A5) and leaves, on slices of a tenth of a second —
ten ticks of the 100 Hz heartbeat — that the timer cuts
out of SPIN's spinning whether SPIN knocks at the door
or not. SPIN runs on alone after A leaves; press Esc and
the session ends at your word: "/spin.bin was stopped.",
"/a.bin exited: 5", and a closing account of the turns
the machine took — "Switches: 5 by the door, 5 by the
timer." — the door's turns (yields, and the hand-over
when one guest ends and its partner runs on) beside the
timer's (slices spent while both guests lived; a guest
running alone takes fresh slices and no switch is
counted, there being no one to switch to), so the forcing
is a number and not an impression. The classic pair reads
as ever, and its account is all door and no timer (9 by
the door, 0 by the timer): courteous guests finish before
any slice runs out. A lone never-ending guest is bounded
by the same word — `run /spin.bin`, watch it count, and
Esc brings the shell home: "The guest was stopped. The
shell stands." What the timer never touches is the kernel
itself: turns are taken only out of a running guest's
hands, and the shell's and the desktop's own work is never
interrupted by the scheduling.

And since milestone 16, the shell has one more answer —
`mouse` — and the desktop has none of the codes left on
it. Type `mouse` (at the text console, or in the Terminal
on the face; the answer is the same): the shell prints
the mouse's whole report exactly as the boot screen
spoke it — whether it answered, and the wake line with
what each step of the waking heard — and then what the
face has taken from the mouse since: the bytes it has
read from it, the packets it has made whole from those
bytes (three bytes to a packet from a plain mouse;
four from a wheel mouse, since milestone 26 — the
waking now knocks with the sample-rate sequence and
asks the mouse's name a second time, and the report's
first line tells what it heard in plain words beside
the name: "Its wheel turns." or "It has no wheel.",
with the knock's own answer kept in the wake line),
and the presses of its button it has answered. The
numbers grow as you use the mouse; run the command,
move and click a while on the desktop, come home, and
run it again. The desktop itself, meanwhile, keeps
only the plain word of it, as the bar's walk below
tells.

And since milestone 17, the machine has a voice — and
since milestone 27 it has two roads to sing by. Boot
this image, open the Terminal, and try `sound`. The
machine looks first for a high-definition sound chip —
UTM's sound device is an intel-hda chip, and Cardnull
drives it now. If the chip answers, you should *hear*
the tune: the Doxology's opening, on Old Hundredth, in
G major, coming through UTM's intel-hda device as a
true stream of sound — eight notes, G4 392 Hz, B4 494,
D5 587, D5 again, C5 523, B4 494, A4 440, and a last B4
held twice as long, some three and a half seconds in
all. The Terminal tells the story as it goes: first
the chip's own report — "Sound chip - controller
8086:2668, codec 1AF4:0022." on the builders' bench,
where QEMU's chip wears those numbers; yours will
read as your own chip and codec report themselves —
and the path the walk chose, "Path: converter node 2
sings through pin node 3." on the bench, the numbers
again being whatever your codec declares. Then the
shell names the tune and prints each note with its
name, its frequency, and its length, and waits while
the phrase plays (it says so, in as many words). Then
the closing line: "The sound chip is silent again." —
and it is; the stream is stopped and reset, and no
tone is ever left standing. On the bench the chip's
stream was captured to a file and measured, note by
note, at exactly the frequencies the screen prints,
with nothing sounding after the phrase's end — the
bench proves the stream; your ears are the witness
for the last leg, through UTM's speakers, and whether
you hear it is the finding this walk most wants back.
Two honest fallbacks. If your UTM presents a different
codec than the bench's, nothing above changes: the
driver finds the controller by its class alone and
asks the codec its own map, so the walk is generic —
the report's numbers will simply be your machine's
own. And if no high-definition chip answers at all,
the Terminal says so in one line — "No high-definition
sound chip answered; the speaker will sing." — and the
machine sings the same phrase on the PC speaker, as it
has since milestone 17: the speaker's gate closed at
every note's end and at the phrase's, the playing the
timer's second channel singing behind its gate, the
100 Hz heartbeat a different channel and never touched
(try `uptime` before and after, and the count has
advanced by just the wait, the song inside it). UTM
has no PC speaker, so on that road your machine may
sing in silence — and then the Terminal's report is
the finding: it tells us exactly what your machine
answered, so tell us what it said. Guests cannot sing
yet: the interrupt-0x80 door has no sound service, and
a feather's voice is a later stone.

And since milestone 20 the machine can speak to a
neighbour — and since milestone 29 it takes the
address and answers back. Try `net`. The shell finds
the network card on the PCI bus (an Intel e1000 — the
82540EM in UTM's keeping), names it, and reads the
hardware address out of the card itself: on the
builders' bench it reads 52:54:00:12:34:56, the
address of the card QEMU provides; yours will read
as your own card reports it. Then the link's word —
"Link: up." — and the whole conversation: a DHCP
discover (291 bytes), an offer, a request (303
bytes), and an acknowledgement — and this time the
lease is **taken and held**, not merely reported.
In UTM, set the machine's network to **Shared
Network**: its server also answers DHCP, so expect
the full lease report on your screen — an address of
your own, its mask, the server it came from, the
gateway, the DNS server, and the lease's length —
followed by the lease block itself standing in the
report. On the builders' bench (QEMU's slirp) that
lease read 10.0.2.15/24, from server 10.0.2.2,
gateway 10.0.2.2, DNS 10.0.2.3, for 86,400 seconds;
your Shared network will give different addresses,
and the difference is expected, not a fault. With
the lease held, `net` goes on to originate its own
exchanges: the gateway's ARP answer and the gateway
ping answered, each reported in its line. Then the
counters line — the session's whole account in one
reckoning: ARP answers given, ping answers given,
gateway pings answered, DNS answers received. Run
`net` a second time in the same sitting and you
should see the standing lease instead of a new
asking, in its own words: *"The lease stands; no
new asking was made."* — no new DHCP leaves the
card, and the report is the books already kept.
The machine also answers while it idles: a
neighbour who asks by ARP who holds our address
gets our answer, and a neighbour's ping gets its
echo back, identifier, sequence and payload intact
— that citizenship was proven on the bench against
a controlled neighbour peer, frame for frame (the
idle ARP reply came after a slower 500.7 ms pass;
the echo reply in 4.67 ms). UTM's Shared network
gives no neighbour a road in to your machine, so
there is no neighbour witness to ask for there:
**your witness is the report your own screen
shows** — the lease, the gateway lines, and the
counters. Two honest notes ride with the command.
DNS: the bench's controlled neighbour answered the
lookup of cardnull.com (with 203.0.113.29, an
address of its own choosing), but the bench's own
slirp did **not** answer the DNS query to its
10.0.2.3 — an ICMP unreachable came back instead,
and the Terminal said so. So if your `net` reports
*"DNS: no answer came for cardnull.com."*, that is
your network's answer, honestly reported — not a
failure of this stone. And silence is honest too:
on a network that never answers, `net` ends *"No
answer came back on the wire."* / *"We hold no
address."*, and a machine with no network card at
all is answered with the plain absence — "No
network card was found on the PCI bus." — and the
shell stands.

And the OS has a face — since milestone 12 a drawn one,
and since milestone 13 the front door itself: when the
boot's news is spoken, the desktop opens on its own. A
deep-cardinal field, the Cardnull OS name standing in
gold — and, since milestone 14 rearranged the room
around the window the work is done in, one large window
standing open: the Terminal, filling the work area
between the name and the bottom bar, its text grid
reckoned from its size (76 columns by 37 rows at
1280 x 800). The Terminal is the kernel's own shell in a
window — the built-in shell, honestly, not a feather.
(The true terminal feather it waited for arrived with
milestone 18 — TERM.FEATHER, in the walk at the end of
this page.) Every command in this
walk runs there, guests included: `run`, `both`, and
`feather` print inside the window, and the conversation
scrolls inside its own grid and is kept when the window
closes and opens again.

The second window, Welcome, starts closed now: a compact
card carrying the greeting, John 1:1 in the Douay-Rheims
(in four shorter lines — the words are the verse's own;
only the wrapping changed), and the counting button of
milestone 12: open it from the bar, click the button —
really click, with the machine's mouse — and the count
beside it rises ("Clicks: 1"), the button wearing its
pressed face while you hold it down.

Across the screen's foot stands the bottom bar, drawn
last so no window ever covers it. Since milestone 16 the
bar lays itself out from the screen's own width, so
every part of it stands at its full size with air around
it — nothing is squeezed, whatever the screen's width:
the parts are given their honest sizes first, and if a
row ever cannot hold them, the spaces between them
narrow before anything else gives. At its left, the
mouse's standing in plain words — "Mouse ready" when it
answered, "Mouse not answering" when it did not — the
short truth on the face itself; the long truth, with
its codes, is the `mouse` command's answer, in the
Terminal where codes belong. Then a launcher for each
window, at its full label: press one to open its window
or give it the room; a cardinal stripe under a launcher
says its window stands. Then the session's clock,
labelled "Uptime" and counting the machine's age off
the same ticks the `uptime` command reads — it is an
uptime, not a wall clock, and says so. At the right
end, the Home button: the face's labelled road back to
the text shell, working from every standing of the
room.

The pointer opens at the screen's centre; move the mouse
and it follows, and the painting beneath it is left
exactly as it was — the pointer lifts its ground into
safekeeping before it is drawn and lays it back when it
moves, so it never leaves a trail.

Which window the keyboard speaks to is told by the title
bars: the window holding the room wears the bright
cardinal, the other rests dimmed — and stands on top.
Click a window to give it the room. Windows can be
carried: press in a title bar and move, and the title
bar wears its held, lit look for the whole carry while
an outline travels with the pointer; release, and the
window stands where the outline promised, painted
whole. The carry is clamped by a plain rule: the title
bar always keeps a reachable strip on the screen — a
good hand's width of it sideways, the close box never
past the screen's edge — and the whole title bar stays
inside the work area up and down, never sinking under
the bar; carry a window hard into a corner and it stops
where you can still take it back (its close box stays
clickable there, too). The two title bars keep the same
geometry for their boxes — same size, same padding from
the right edge, same gap between them — and a box's
reach is exactly the square you see painted. The
Terminal's title bar carries a second box beside its
close box: maximize, which gives the window the whole
work area (its grid grows with it), and restore, which
returns it to its own place and size — the conversation
stands through both. A double-click on the Terminal's
title bar does the same trade, the way people already
expect: double-click to maximize, double-click again to
restore.
Each window's close box closes only that window — the
desktop stands, and the bar's launcher calls the window
back with its conversation intact. `gui` typed at the
text console opens the face again; typed inside the
Terminal it answers plainly that you are already here.

The ways home are two, and both are plain. The bar's
Home button works from any standing — no one is ever
trapped. And Esc keeps its standing rule: while the
Terminal holds the room, Esc is the shell's own key and
does nothing special — exactly as on the text console;
whenever the Terminal does not hold it (the Welcome card
clicked, the Terminal closed, bare desktop), Esc brings
the whole face home. If Esc does not answer, the room is
the Terminal's: click the card, the desktop, the
Terminal's close box, or the Home button, and you are
out. One Esc rule stands above those while a guest
session runs, in the Terminal or at the text console
alike: Esc is the session's key and stops it, as the
session's own opening line says — the room rulings
resume when the session ends.

Milestone 13 also re-made the mouse's waking, after
milestone 12's first UTM witness came back partial: the
desktop drew perfectly, but the pointer never answered.
The waking is now the full standard ceremony — the mouse
itself is reset and its self-test word and name are
heard, every wait is bounded by the timer rather than a
spin count, the controller's configuration byte is
re-read after the waking and again at the desktop's
opening and healed if anything undid it, a silent first
attempt is tried once more whole, and the face also
polls the mouse's port directly, so an interrupt road
gone silent cannot starve it. If the mouse still does
not answer, the boot report's second line says what each
step heard — that transcript is the diagnosis, printed by
the machine itself. The drill needs nothing new for any
of this: the mouse is a PS/2 device, spoken to through
the same controller the settings already force on (USB
stays off). The face is still deliberately small, and
says so in the kernel: two windows, carried by an
outline rather than a live repaint; no window manager;
no program but the kernel draws. Graphical programs are
a later era. And the visit costs the machine nothing it
was not already spending — the face paints the
framebuffer the boot already owned and its grids are
the floor's lendings, not the allocator's: `mem` reads
the same numbers before a visit and after it. (The
kernel's own image grows a little with each milestone's
code, so the standing "used" count at 4096 MB behind
the UEFI door reads 1,271 where milestone 15 read
1,270 — the one frame is this milestone's grown image;
the visit itself spends nothing.)

And since milestone 18 the guests have faces. In the
Terminal, run:

    feather /face.feather

and the whole screen becomes the feather's own painting: a
parchment panel on a deep-cardinal field, the OS's name,
"Welcome to Cardnull OS.", John 1:1 drawn as text, and a
small cardinal the guest drew out of rectangles — honest
rectangles, no borrowed art. Any key sends it home, and the
desktop and the Terminal's conversation stand exactly as
they were. Then the stone the Terminal's label always
promised:

    feather /term.feather

A terminal that is a feather. It draws its own framed
screen, keeps its own scrollback, and answers its own small
set of words — try `help` (which also tells you the truth
about Esc), `verse`, `about`, `clear`, and `exit` to go
back. While it runs the kernel's shell is not involved at
all: everything it shows arrived through the service door.
Two more witnesses ride the disc:

    run /wildrect.bin

paints the whole screen gold with one too-large rectangle
— the kernel clips it to the screen rather than writing
wide — and waits for a key before leaving cleanly; and

    run /badgfx.bin

paints a small panel, then asks the kernel to draw text
from an address in the kernel's own ground. The door
refuses and stops it: a short report names the address and
the service at the top of the screen, the desktop comes
back whole, and the shell answers "The guest was stopped."
Esc works throughout, as always: pressed during any of
these, it stops the session and gives the screen back — a
guest never receives Esc as its own key; the feather
terminal's `help` says so in its own words.

## The Files window: the disc, browsable

Since milestone 19 the disc has a face. Click **Files** in
the desktop's bottom bar — or type `files` in the Terminal —
and the Files window opens: the disc's contents as a list,
the same list `ls` prints, each file with a small drawn
mark of its kind, its name, and its size in plain words. A
line at the window's foot says how many files the disc
holds. The list is longer than the window: use the arrow
buttons at its right edge, or the arrow and Page Up / Page
Down keys while the window is the one you're working in.

Double-click a file to open it, by kind:

- **A text file** (WELCOME.TXT is the one to try) opens in
  the **Reader**: a window titled with the file's name,
  showing the file's own words, wrapped to the window. Its
  close box returns you to the desktop with Files still
  standing.
- **A feather** runs — through the Terminal, exactly as if
  you had typed the command: the Terminal comes forward
  and you see the card, the checksum's proof, and the run.
  A feather with a face (try FACE.FEATHER) takes the whole
  screen and gives the desktop back as it was; a text
  feather (HELLO.FEATHER) prints its words in the Terminal.
- **A program** (a .BIN) runs the same way, as `run` —
  including SPIN.BIN, which still answers your Esc.
- **The system files and folders** do not open. The
  window's foot says so in plain words — "…is part of
  Cardnull itself and doesn't open." They are listed
  honestly, never hidden.

The window itself behaves like its siblings: drag it by
its title bar, use its corner boxes to maximize and
restore (a double-click on the title does the same), close
it with the X. The list is read fresh each time the window
opens — the disc cannot change under it, so opening is the
refresh.

## The hard disk: writing, saving, installing

Since milestone 21 the OS can write — to the VM's **hard
disk**, never to the CD (the CD cannot be written at all;
the commands say so on screen). Ten commands in the
Terminal work the disk: `disk`, `format`, `dsave`, `dls`,
`dcat`, `install`, the three that came with milestone
30 — `rename`, `copy`, `delete` — and — since milestone
28 — `bootable`, which prepares an installed disk to
start the computer by itself (its own walk stands at
the end of this page).

> **Read this first, before you witness:** `format` and
> `install` **erase the hard disk completely**, after a
> typed confirmation. Witness with a **new throwaway disk
> added to the VM for this walk** — in UTM, stop the VM,
> open its settings, add a new drive (a small one, 64 MB
> is plenty), and let it be the disk this walk uses.
> **Never point these commands at a disk holding anything
> you keep.** The walk below assumes a fresh, empty disk
> you are willing to lose.

With the VM running and a fresh disk attached, type:

    disk

It reports the CD ("read-only, as ever") and the hard
disk: its model and size in plain words, and its state —
a fresh disk reads *"It is blank: nothing on it is
Cardnull's yet."* (No disk attached at all is answered
just as plainly: "No hard disk is attached.")

    format

The command states that everything on the disk will be
erased, and asks for a word: type **FORMAT** and press
Enter. Anything else — a wrong word, a bare Enter —
writes nothing, and the command says so. Then:

    dsave greeting hello from cardnull on its own disk
    dcat greeting
    dls

The greeting is saved (36 bytes: the words and a closing
newline), read back, and listed. Saving under a name that
already stands is refused — while a name stands it is
never reused or overwritten — and saving to an
unformatted disk is refused in plain words too. Now the
proof that matters: **shut the VM fully down, start it
again, and type `dcat greeting`** — the words come back
from the disk, word for word. What you save now *does*
persist, on that disk, between boots.

Since milestone 30 the files have manners — they can be
renamed, copied, and deleted, all in the Terminal (the
Files window lists the CD, not the hard disk, so these
live here):

    rename greeting salutation
    dcat salutation
    copy salutation keepsake
    dls

The rename answers "Renamed greeting to salutation.",
the file reads back word for word under its new name,
and the copy stands beside it as its own file — from
here the two share nothing. The name `greeting` is free
again at once; a rename or copy onto a name that stands
is refused in plain words, and nothing is overwritten,
ever. Deleting is gated, like `format`:

    delete keepsake

It names the file and its size, warns that nothing can
bring it back, and asks for a word: type **DELETE** and
press Enter. Anything else writes nothing, and the
command says so. One honest limit to witness: `disk`
before and after a delete reports the **same** room —
a deleted file's name and place in the list are freed,
but its bytes' room is not reclaimed until a `format`.
Deleting removes a file; it does not make room.

Since milestone 31 the desktop has a writing window,
and feathers can keep files. Click **Write** in the
bottom bar (or type `write` in the Terminal): a window
opens with New, Open, and Save at its head. Type a few
lines — letters, backspace, Enter, and the arrow keys
all work as you would expect — then click **Save**:
the window asks for a name in its own strip; type one
(say, `letter`) and press Enter. The words at the
strip's head give the name and "- saved". **Shut the
VM fully down, start it again,** open Write, click
**Open**, and choose the file: your words come back
from the disk, and you can keep writing and save
again — saving the file you have open writes back
into its own place. A name that already stands is
refused in plain words, and nothing is ever
overwritten. With no Cardnull disk in the machine,
Save answers "No Cardnull disk yet. Your words are
still here." and the words stay on the screen. One
honest bound: a page here holds 8,192 bytes, and a
longer file opens as its first page, saying so.

The same stone gave feathers hands for the disk. With
the prepared disk in the machine, type:

    feather /keep.feather

It answers in the Terminal: "KEEP: written", then
"KEEP: read back 20 bytes: kept by keep.feather" — it
wrote NOTE.TXT through the service door and read it
back and said what it read. Run it a second time and
the writing is refused — "KEEP: refused - name
taken" — because the door never overwrites either;
the standing file still reads back whole, and
`dcat note.txt` in the Terminal, or Open in the Write
window, shows the same words.

Finally, the installer:

    install

It names the disk, warns that installing erases it, and
asks for its word: type **INSTALL** and press Enter. It
formats the disk and copies the disc's own files onto it
— the welcome, every program, every feather, and, since
milestone 28, Cardnull itself: the kernel and the file
bundle from the disc's BOOT folder, fifteen files copied
in all — and writes one more, INSTALLED.TXT, sixteen
files standing, which `dcat installed.txt` reads back
from the disk. Its text now says the disk carries
Cardnull itself, and names the next step: **type
`bootable` to make this disk start the computer by
itself, behind the BIOS door** — with the honest scope
in the same breath: the UEFI door from an installed
disk is not yet. Installing alone still boots nothing;
the machine boots from the CD until `bootable` prepares
the disk, in the walk at the end of this page. The
format itself is defined in `docs/DISK.md`.

Shut the VM down whenever you like. The CD's world is as
it ever was — nothing on it persists or can break — and
now the hard disk keeps what you saved on it, exactly as
long as you keep the disk.

## The ownboot image: the second pressing

Since milestone 22 there is a second image to try:
`dist/cardnull-ownboot.iso`, built by
`tools/build-ownboot-iso.sh`. It began as the
experimental disc whose UEFI door was rebuilt around
our own bootloader while its BIOS door was still
GRUB's. Since milestone 24 the standard build writes
both doors with our own chains, and the ownboot image
is simply the second pressing of the same disc — a
separately built twin, kept because the stick
experiments ride it. The standard image remains the
daily one; either witnesses the same system.

The drill is the same: point the machine's CD drive at
`cardnull-ownboot.iso`, leave **UEFI Boot** checked,
and start it. What differs is the first screen: instead
of GRUB flashing past, the loader signs its work in
plain text —

    Cardnull Bootloader
    Cardnull OS behind the UEFI door, loaded by our own hand.
    The kernel is in hand: 242552 bytes, read from the boot volume.
    The file bundle rides in memory: 7147 bytes.
    The kernel stands at 1 MiB, ELF segments laid, the unwritten zeroed.
    Screen: 1280 by 800, 32 bits to a pixel.
    Memory map: ... regions, translated from the firmware's own.
    Handing the machine to Cardnull OS...

— and hands over quickly; the desktop that follows is
the same desktop, by the same kernel, which did not
change by a line. If the loader cannot do its work it
says so on that screen and rests, rather than handing
over a broken world. The design is kept in
`docs/BOOTLOADER.md`.

## The bundle: the files ride in memory

Since milestone 23, both images carry the system's
own files a second way: as one **bundle** that rides
the boot into memory (the format is `docs/BUNDLE.md`).
Both images boot from the disc through our own
bootloaders — the BIOS chain (milestone 24) behind
the legacy door, our loader (milestone 22) behind
UEFI — and each carries the bundle in its own way:
the BIOS stage lays it behind the kernel, the UEFI
loader reads it from beside the kernel; both name
its span in the same module tag.
What the witness should see, on either image: type
`about` in the Terminal and the last line names the
files' home — "Files: carried in memory - 13 files in
the bundle." `ls` heads its list "Bundle /:", the
Files window's foot says the files are carried in
memory, and `install` copies from the bundle and its
note on the disk says so. If a bundle ever failed to
prove itself at boot, the same places would say the
files are read from the disc, and the disc would
serve them exactly as it always has — nothing about
the drill changes either way.

## Feathers in windows

Since milestone 25, a graphical feather launched from
the desktop opens **in a window** instead of taking
the screen. The drill, on either image: in the
Terminal, type `feather /term.feather`. A window
titled **Feather Terminal** — the card's own title —
opens over the desktop, and the feather's welcome
prose wraps inside it ("I stand on the service door
alone: I / knock, and / the kernel draws; your keys
reach me by / the door."). Type `verse` and John 1:1
answers, wrapped the same way.

The window keeps the desktop's manners. Drag it by
its title bar: it travels, and where it stood, the
Terminal's conversation stands whole again; the
feather's own face is whole at the new place. Give
the room away and take it back: open the Welcome card
from the bar first if it is closed, launch TERM, then
click **Welcome** in the bottom bar — the feather
window's title bar dims, and words you type now go
nowhere (they are let go, not saved up). Click the
feather's window and its bar brightens; type `about`
and it answers. End it three ways, each honest:
`exit` typed inside it ("Program exited: 0"), Esc
("The guest was stopped. The shell stands."), or the
window's own close box — the same stopped verdict, by
the mouse. `feather /face.feather` opens the greeting
face in a window the same way, its panel centred in
the smaller room; drag it and the cardinal travels
whole.

The Files window launches them too: scroll to
TERM.FEATHER and double-click — the command is typed
into the Terminal by the window's own road, the card
is read aloud there, and the window opens.

One contrast worth witnessing, because it is the
rule: go Home to the text console and type the same
`feather /term.feather` there. The feather takes the
**whole screen**, as it always has, and its lines
stand whole at the wider measure — "In the beginning
was the Word, and the Word was with God, and" on one
line. The face fits the room it was opened in;
Esc brings the shell back.

## The wheel

Since milestone 26, the mouse's wheel turns. The
waking asks the mouse for it by name (the sample-rate
knock), and the drill is simple: put the pointer over
a window and turn the wheel — that window scrolls,
and takes the room as it does, the way a click would
give it. Three lines to a notch. The Terminal's
conversation now keeps a past (128 lines of it):
fill it with `help`, `verse`, `about`, `help` again,
then turn the wheel up over it and the older lines
come back; turn down and you are home at the live
tail. PageUp and PageDown leap a windowful, and the
first key you type while reading back brings the
view home before the key is answered. The Files
list and the Reader's page scroll by the same wheel.
Over a feather's window the turning is the feather's
own: open TERM, fill it past its room (`help`,
`verse`, `about`, `verse`), put the pointer over its
face and turn up — its own scrollback reads back,
three lines to a notch, and no further than its
eldest line.

One question this page cannot settle, stated open:
**whether UTM's mouse answers the knock.** The
bench's mouse answers with the wheel's name (the
`mouse` command reads "answering (id 0x03). Its
wheel turns."), and UTM's mouse is near kin — but
near kin is not the same mouse, and the witness is
yours. If your mouse answers the plain name instead,
the report will read "It has no wheel." and the
desktop will behave exactly as it did before this
stone: nothing is lost, and nothing pretends.

## Bootable: the disk starts the computer by itself

Since milestone 28, an installed disk can be
prepared to boot Cardnull on its own — behind the
**BIOS door only**, so this walk runs with **UEFI
Boot** unchecked (Edit → QEMU → **UEFI Boot** off
is the BIOS door, as this page has framed the doors
from the start). The UEFI door from an installed
disk is not yet, and nothing in this walk pretends
otherwise.

> **The warning from the hard-disk walk stands,
> doubled:** `format`, `install`, and `bootable`
> remake the hard disk. Witness with the same kind
> of **new throwaway disk** that walk asks for —
> never a disk holding anything you keep.

The walk, in order:

1. **Boot from an ISO with a hard disk attached.**
   Point the VM's CD drive at either image (the
   standard `cardnull.iso` is the daily one), leave
   the fresh hard disk attached, make sure **UEFI
   Boot** is off, and start the VM. The desktop
   rises behind the BIOS door, by our own chain.
2. **Plant Cardnull, then prepare it.** In the
   Terminal, on the throwaway disk:

       format
       install
       bootable

   Each asks for its own typed word — **FORMAT**,
   then **INSTALL**, then **BOOTABLE** — and
   anything else writes nothing and says so.
   `install` leaves sixteen files standing (the
   thirteen, KERNEL.BIN, FILES.BUNDLE, and
   INSTALLED.TXT; `dls` counts them, and `dcat
   installed.txt` reads the new note back).
   `bootable` warns that it will move everything
   behind a partition and lay Cardnull's own boot
   image and partition table at the disk's head,
   and its success is one plain sentence: *"The
   disk is prepared: it can start the computer by
   itself behind the BIOS door."* Run `disk` and
   its account gains the same truth in one line:
   *"It can start the computer by itself."* Run
   `bootable` a second time and it answers, just as
   plainly, *"This disk already starts the computer
   by itself."* — and changes nothing.
3. **Take the CD away.** Shut the VM fully down.
   In UTM's settings, remove the CD drive from the
   VM (or set the hard disk first in the boot
   order, so the disk is what the firmware boots).
   What matters: no CD stands in the machine for
   the next start.
4. **Boot from the disk alone.** Start the VM. The
   BIOS boots the hard disk, our MBR hands over to
   the boot image the disk itself carries, and the
   loader signs the new road in its own words —
   quickly, on the text screen before the desktop:

       Cardnull Bootloader
       Cardnull OS behind the BIOS door, loaded by our own hand.
       The kernel is in hand: 281248 bytes, read from the boot disk, laid at 1 MiB.
       The file bundle rides in memory: 7680 bytes.

   — "boot **disk**", not "disc": that one word is
   the witness that the kernel came off the hard
   disk, not off any CD. The desktop that follows
   is the whole system, living off the disk:
   `about`, `dls` (the sixteen files), `dcat
   installed.txt`, `mem`, `sound` — and what you
   `dsave` now comes back after a full shutdown
   and a cold start from the disk again, word for
   word, because the disk is home now in both
   senses.

The bench proved this whole walk in QEMU — the
preparation with its gate and its hashes, the
disk-alone boot with no CD device attached, the
persistence, and the regressions — on
November 11, 2026. But the bench is not your
machine, and this page does not claim your witness
for you: **whether it stands in UTM is yours to
see, and your screen is the final word.** If any
step answers differently there, that is a finding
to record, not a failure to hide.

## The USB stick: seeing what is plugged in

Milestone 32 teaches Cardnull to see a USB stick —
to name it, measure it, and read a Cardnull stick's
files. The recipe at the top of this page turns USB
off; this witness turns it on.

1. **Switch USB on.** Shut the VM fully down. In
   UTM's settings for the VM, set **USB Support** to
   enabled (the recipe's standing setting is
   Disabled — this witness is the one that changes
   it). Start the VM from either image and let the
   desktop come up.
2. **Ask with nothing plugged in.** Open the
   Terminal and type `usb`. The answer should be
   the plain absence:

       USB stick: no stick is plugged in.

   `uls` and `ucat greeting.txt` answer the same
   way. An absence is an answer, not an error.
3. **Share a stick with the VM.** Plug a USB stick
   into the Mac, then pass it to the running VM
   from UTM's USB menu (the USB icon in the VM
   window's toolbar — share the stick with the
   guest). Back in the Terminal, type `usb` again.
   Cardnull looks afresh at every asking, so no
   restart is needed: the report names the stick in
   its own words (the name its maker gave it), its
   measure, and what stands on it.
4. **Read a Cardnull stick.** On a stick carrying
   the Cardnull disk format, the report counts its
   files; `uls` lists them, and `ucat NAME` reads
   one back, word for word. A stick a `bootable`
   preparation has touched is reported as able to
   start the computer by itself. A stick carrying
   some other format is reported as seen and
   measured — and *not one Cardnull reads yet*:
   that is the truth about it, not a failure.

Two honest bounds. Cardnull speaks the plainest
USB host design (UHCI, the USB 1.1 companion the
chipset presents when its USB is switched on), and
it reads only — nothing in this stone can write to
a stick, and the Files window does not show the
stick yet; its face there rides a later stone.

The bench proved this walk in QEMU — the report,
the listing, the reading, the prepared stick, the
foreign stick named unread, the blank stick, and
the absence answered plainly — on November 12,
2026. But the bench is not your machine, and this
page does not claim your witness for you:
**whether it stands in UTM is yours to see, and
your screen is the final word.** If any step
answers differently there, that is a finding to
record, not a failure to hide.

## The clock and the Power button

Milestone 33 gives the desktop its wall clock and
its leaving. Both are witnessed by eye, in a
minute or two.

1. **Read the clock.** Start the VM from either
   image and let the desktop come up. The bottom
   bar now tells the time — plain digits and the
   small word, "3:07 PM" — standing between the
   Welcome button and the new Power button. The
   time is the machine's own: UTM shows the Mac's
   clock, so the bar should agree with the clock
   on the Mac's own menu bar, to the minute.
   Watch it a moment; the minute turns over as
   the wall clock's does.
2. **Open the Power card, and put it back.** Click
   **Power** in the bar. A card stands at the
   centre asking "What would you like to do?",
   with **Shut Down**, **Restart**, and **Not
   now**. Click **Not now**: the card goes, and
   nothing has happened. Open it again and press
   Escape: the same.
3. **Meet the second asking.** Open the card and
   click **Shut Down**. The card does *not* shut
   anything down; it asks "Are you sure?" and
   says "The computer will shut down." Click
   **No, go back** — you are returned to the
   choosing, and the machine stands untouched.
   The same second asking stands behind
   **Restart**.
4. **Restart, when you are ready to see it.**
   Open the card, click **Restart**, then **Yes,
   restart**. A plain "Restarting..." screen
   stands for a moment, and the machine comes
   back up on its own to the desktop — the same
   road it took when it was first started.
5. **Shut Down, last.** Open the card, click
   **Shut Down**, then **Yes, shut down**. The
   "Shutting down..." screen stands, and the VM
   powers off — UTM's window closes or shows the
   machine stopped, as a real computer turning
   off would leave it. Nothing is left running.

Two honest bounds. The clock keeps no timezone
of its own: it shows the time the machine itself
keeps, exactly as set. And the shut-down asks by
the machine's own ACPI tables; if a machine ever
declined them, the screen would say "You can
turn the computer off now." and rest — that
screen, if you ever see it, is a finding to
record.

The bench proved this walk in QEMU — the clock
set by hand and watched across noon and
midnight, every road back from the card, a
confirmed Restart returning to a fresh desktop,
and a confirmed Shut Down ending the bench
process itself — on November 13, 2026. But the
bench is not your machine, and this page does
not claim your witness for you: **whether it
stands in UTM is yours to see, and your screen
is the final word.** If any step answers
differently there, that is a finding to record,
not a failure to hide.

## The Bible window

Milestone 34 gives the desktop its book: the
whole Douay-Rheims Bible, in a window of its
own. The witness is a reading.

1. **Open it from the Welcome card.** Start the
   VM from either image. Click **Welcome** in
   the bottom bar: the greeting card stands a
   row taller than it used to, and beneath the
   verse from John it carries a wide button,
   **Read the Bible**. Click it. A window titled
   **Bible** opens on the list of books — Genesis
   first, the names in the Catholic order (Josue,
   Paralipomenon, Esdras, Tobias, Judith among
   them) — with the line "The Douay-Rheims Bible
   (Challoner, 1899)" at its foot.
2. **Read a book.** Click **Genesis**. The title
   becomes "Genesis", a "< All books" button
   stands at the page's head, and the text opens
   at "In the beginning God created heaven, and
   earth." Scroll with the mouse wheel or the
   arrow keys; Page Down turns a page. Press
   **Escape** once: you are back at the list of
   books (Escape again would head home, as it
   always has).
3. **Find John.** Scroll the list of books with
   the wheel until **John** stands in it, and
   click it: "In the beginning was the Word, and
   the Word was with God, and the Word was God."
4. **The Terminal's road.** Close the Bible
   window by its X box. In the Terminal, type
   `bible` and press Enter: the window opens
   again. (`help` names the command, with the
   others.)

Two honest bounds. The Psalms stand in the
Vulgate numbering the Douay-Rheims keeps, so
the twenty-third Psalm of the Protestant
counting is Psalm 22 here — "The Lord ruleth
me: and I shall want nothing." That is the
translation's own order, not a misprint. And
the text is read from memory, off the bundle
the disc carries; a copy of the system with no
bundle would open the window onto one plain
line saying the Bible did not ride — on these
images, it rides.

The bench proved this walk in QEMU — the list
whole, Genesis, John and Hebrews read on the
screen, the wheel and the keys scrolling, the
same Genesis behind the BIOS bootloader — on
November 13, 2026. But the bench is not your
machine, and this page does not claim your
witness for you: **whether it stands in UTM is
yours to see, and your screen is the final
word.** If any step answers differently there,
that is a finding to record, not a failure to
hide.

## The Shield window

Milestone 35 gives the Shield — the family
filter that is system law, on with no off
switch and no telemetry, settled November 7,
2026 — a window of its own that states the
standing in plain words. The witness is a
reading, and one number that must be true.

1. **Open it from the Welcome card.** Start
   the VM from either image. Click **Welcome**
   in the bottom bar: the greeting card stands
   a row taller again, and beneath **Read the
   Bible** it carries a second wide button,
   **The Shield**. Click it. A window titled
   **The Shield** opens: "The Shield is on
   guard." — the filter on, no way to turn it
   off, nothing sent anywhere, the wire
   answering only the errands you began — and
   one live line, "Times spoken on the
   network: 0", because nothing has been asked
   of the wire yet.
2. **Open it from the Terminal.** The command
   `shield` opens the same window. There is
   nothing in the window to click but its own
   manners — it can be moved by its title bar,
   maximized by its box, and closed by its
   close box — because there is nothing in the
   standing to change. That is not a missing
   feature; it is the feature.
3. **Watch the count tell the truth.** Give
   the Terminal the room (click its title bar),
   run `net`, and when the errand's report has
   printed, run `shield` again. The line now
   reads "Times spoken on the network: 5" —
   the address lease's discover and request,
   the gateway ARP, the DNS question, and the
   ping: every packet the errand spoke, counted
   at the one door every packet leaves by.
   Leave the machine sitting and the number
   does not grow on its own; the system begins
   no errands of its own.

The bench proved this walk in QEMU — the page
whole from both doors on both boot doors, the
count at rest and after one errand — on
November 13, 2026. But the bench is not your
machine, and this page does not claim your
witness for you: **whether it stands in UTM is
yours to see, and your screen is the final
word.** If any step answers differently there,
that is a finding to record, not a failure to
hide.

## The Help window

Milestone 36 gives the desktop its plain
answers: a window of "How do I..." questions,
each answered in plain words. The witness is
a reading, and a little scrolling.

1. **Open it from the Welcome card.** Start
   the VM from either image. Click **Welcome**
   in the bottom bar: the greeting card stands
   a row taller again, and beneath **Read the
   Bible** and **The Shield** it carries a
   third wide button, **How do I...**. Click
   it. A window titled **How do I...** opens:
   "Plain answers, in plain words." — and the
   first questions, their questions in red,
   their answers in black.
2. **Open it from the Terminal.** The command
   `howdoi` opens the same window, and the
   Terminal's own `help` listing now names it
   too, in its plain order.
3. **Read down the page.** The mouse wheel
   turns it (three notches, nine lines), the
   Page Down key turns a page, and the little
   arrows at the page's right edge step it a
   line at a time. The last questions are how
   to shut down and restart, and how to get
   back to the start; the page ends, "That is
   the whole of it. The house is small, and it
   is yours." Every answer names a door that
   really stands — try one: the Write answer
   says **Save**, and the Write window's own
   button says Save.
4. **Its manners are the family's.** It can
   be moved by its title bar, maximized by its
   box, and closed by its close box — as can
   the Bible and Shield windows, whose
   title-bar drags this milestone also set
   right (the bench had found them borrowing
   the Terminal's outline; drag each one a
   little way and watch it land where you
   carried it).

The bench proved this walk in QEMU — the page
whole from both doors on both boot doors, the
scrolling counted line by line, the drags
measured — on November 13, 2026. But the bench
is not your machine, and this page does not
claim your witness for you: **whether it
stands in UTM is yours to see, and your screen
is the final word.** If any step answers
differently there, that is a finding to
record, not a failure to hide.

## The second screen

Milestone 37 proves the desktop whole at
other display sizes. Your UTM window gives
the machine 1280×800, and at that size
nothing changes — this section is for the
day Cardnull meets a different screen, and
there is nothing you must do to witness it
unless a screen of another size comes to
hand.

What to expect wherever it does:

1. **The desktop stands whole.** The name
   centred, the windows within the work
   area, the bottom bar's buttons all
   standing with ground between them —
   never overlapping, never cut off.
2. **On a narrower screen, the reports
   rest before the controls give.** The
   clock steps aside first (its standing
   rule), then the bar's gaps narrow, then
   the little status word at the bar's left
   rests. Every button — Terminal, Files,
   Write, Welcome, Power, Home — stands at
   any width that can hold them in a row.
3. **The Welcome card keeps the doors that
   fit.** On a short screen its tallest
   buttons rest in their standing order;
   whatever rests is still reachable from
   the Terminal (`bible`, `shield`,
   `howdoi`), as the Help window's own
   section tells.

The bench proved this in QEMU on
November 13, 2026 — at 1024×768 and
800×600, through the BIOS image's own
fallback to the best mode each display
offered — and found and mended one fault
on the way: at 1024 wide the Welcome and
Power buttons had overlapped by eight
pixels, and now stand clear. **Your screen
remains the final word** for any size your
own machine may one day offer.

## The Settings window

Milestone 38 gives the desktop its
settings: a window of the house's choices,
each in plain words. The witness is a few
choosings, and one restart.

1. **Open it from the Welcome card.** Start
   the VM from either image. Click
   **Welcome** in the bottom bar: the
   greeting card stands a row taller again,
   and beneath **How do I...** it carries a
   fourth wide button, **Settings**. Click
   it. A window titled **Settings** opens:
   "Your choices, in plain words."
2. **Open it from the Terminal.** The
   command `settings` opens the same
   window, and the Terminal's own `help`
   listing names it too.
3. **Choose the clock's form.** Two
   buttons stand as the shapes themselves:
   **3:45 PM** and **15:45**. The standing
   choice is the red one. Click the other,
   and the bar's clock takes its new form
   at once.
4. **Choose the mouse's pace.** **Slower**,
   **Steady**, or **Faster** — move the
   pointer after each and feel the
   difference. Slower never swallows a
   small movement; it keeps the halves.
5. **Choose the start.** Under "Show the
   Welcome card at the start?", **Show it**
   makes the greeting card the first thing
   standing at the next start; the page
   tells you it takes hold then, not now.
6. **Read the foot line.** With your
   Cardnull disk in, it says, "Your choices
   are kept on your disk." — and they are:
   they live in a little file named
   SETTINGS.TXT, which the Files window
   will show you and the Reader will read
   aloud in three short lines. Start the
   machine again and your choices stand as
   you left them.
7. **Its manners are the family's.** It
   can be moved by its title bar, maximized
   by its box, and closed by its close box.

The bench proved this walk in QEMU — both
doors, every choice, the pointer's
landings measured at both paces, the
keeping read back after a Restart, and
the honest diskless word kept — on
November 13, 2026. But the bench is not
your machine: **whether it stands in UTM
is yours to see, and your screen is the
final word.**
