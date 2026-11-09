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

GRUB flashes past (its timeout is zero), and then a black screen with
one word at the top left:

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
the machine's own testimony, and the desktop's bottom bar
repeats the first of them.

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

Press Enter and the prompt answers. Fourteen commands, for now:

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
- `gui` — open the graphical desktop (Esc brings you home)

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
window — the built-in shell, honestly, not a feather; a
true terminal feather still waits on guest drawing and
keyboard services, a later stone. Every command in this
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
last so no window ever covers it. At its left, the
mouse's standing, in the boot report's own words —
"Mouse: answering (id 0x00)." when it answered, "Mouse:
not answering." when it did not — so the truth about the
mouse is on the face itself, not only in the boot lines
behind it. Then a launcher for each window: press one to
open its window or give it the room; a cardinal stripe
under a launcher says its window stands. Then the
session's clock, labelled "Uptime" and counting the
machine's age off the same ticks the `uptime` command
reads — it is an uptime, not a wall clock, and says so.
At the right end, the Home button: the face's labelled
road back to the text shell, working from every standing
of the room.

The pointer opens at the screen's centre; move the mouse
and it follows, and the painting beneath it is left
exactly as it was — the pointer lifts its ground into
safekeeping before it is drawn and lays it back when it
moves, so it never leaves a trail.

Which window the keyboard speaks to is told by the title
bars: the window holding the room wears the bright
cardinal, the other rests dimmed — and stands on top.
Click a window to give it the room. Windows can be
carried: press in a title bar and move, and an outline
travels with the pointer; release, and the window stands
where the outline promised, painted whole — clamped so
its title bar always keeps a hold on the screen, and it
can never sink under the bar. The Terminal's title bar
carries a second box beside its close box: maximize,
which gives the window the whole work area (its grid
grows with it), and restore, which returns it to its own
place and size — the conversation stands through both.
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
kernel's own image is a few frames larger than
milestone 13's — this milestone's code, and the grid
keeping's growth from 1,240 to 7,680 bytes of it — so
the standing "used" count at 4096 MB behind the UEFI
door reads 1,270 where milestone 13 read 1,265; the
visit itself spends nothing.)

Shut the VM down whenever you like; nothing persists, nothing can break.
