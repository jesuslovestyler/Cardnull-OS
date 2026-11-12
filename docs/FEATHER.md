# The Feather Format

*Written November 9, 2026, with milestone 11 — the day the OS
learned its own package format. This document is the format's
definition; the kernel's handler and the tree's packer both
answer to what is written here.*

## What a feather is

A **feather** is the package a program travels in on Cardnull
OS — one file, carrying two things:

1. a **card** — plain text, readable by anyone, that names the
   program honestly before it runs; and
2. the **program** itself — a flat guest image of exactly the
   kind `run` loads (milestone 9): bytes laid at 0x40000000 and
   entered in ring 3, speaking through the door at interrupt
   0x80.

A feather is a citizen, not a sample: where the disc's bare
`.BIN` files are the kernel's own teaching guests, a feather is
how real programs — Chirpy first among them, one day — arrive
with their names on them.

## The layout

Byte for byte, in order:

```
CARDNULL FEATHER 1
title: Hello, the First Feather
maker: Cardnull
version: 1
support: If this feather serves you, ...
program-size: 234
program-fnva: 0123456789abcdef
---
<the program's bytes, program-size of them, and nothing after>
```

- **The magic line.** The file's first line is exactly
  `CARDNULL FEATHER 1` — the format's name and its version.
  A file that does not open with it is not a feather, and the
  `feather` command says so and goes no further. `run`, pointed
  at a feather, recognises the same line and refuses: a raw
  loader must never execute a package's card as if it were
  code — the format exists to prevent exactly that.
- **The card.** Lines of `key: value`, one to a line, ended by
  the separator. Keys are matched without caring about case;
  a value is everything after the colon, trimmed of the spaces
  at its edges. A card may carry more keys than these — the
  handler reads the ones it knows and lets the rest stand.
  The card must end within the file's first 4 KiB; a card that
  cannot find its separator in that reach is not read further.
- **The separator.** A line of exactly three dashes, `---`.
  The program begins at the byte after its newline.
- **The program.** Exactly `program-size` bytes, and the file
  ends there: a feather carries nothing after its program, so
  a short file is a truncated feather and a long one is
  carrying something it does not declare. Either is refused.

Lines end with a single line feed (0x0A); a carriage return at
a line's end is forgiven when the card is read.

## The card's keys

| key | meaning |
| --- | --- |
| `title` | the program's name, as its maker gives it |
| `maker` | the maker's name — the name the maker stands behind |
| `version` | the maker's version for this program |
| `support` | how a reader may support the maker, in the maker's words |
| `program-size` | the program's length in bytes, reckoned by the packer |
| `program-fnva` | the program's checksum (below), reckoned by the packer |

The first four are the maker's own words, and all four are
required: a package that will not say what it is, who made
it, which version it is, and how its maker may be supported
does not run. The handler prints those four to the screen
before the program runs — the honest label, read first.

The `support` line carries the house rule in its words:
support for a maker is **voluntary income for the maker**. It
is not a tax-deductible donation, and a card must never claim
otherwise.

The last two keys are not the maker's words but the packer's
reckoning, added at pack time from the program's real bytes.

## The checksum — an integrity check, not a signature

`program-fnva` is the program's **FNV-1a 64-bit** checksum:
begin at 14695981039346656037 (0xcbf29ce484222325); for each
byte, in order, xor the byte into the hash and multiply by
1099511628211 (0x100000001b3), keeping 64 bits. It is written
as sixteen lowercase hex digits.

Before a feather's program runs, the handler reckons the
checksum again over the bytes the disc actually delivered and
compares it against the card. **A feather whose program does
not match its card is refused and not run** — it may be
damaged, or it may have been altered after packing; either
way, what would run is not what the card describes, and the
card is the only promise the reader was given.

Honesty about what this is: a checksum is an **integrity
check against corruption**, nothing more. It is not a
signature. Anyone can recompute it after changing the bytes,
so it proves the program matches *this card* — never that
Cardnull reviewed, approved, or vouches for either. The day
every feather is reviewed and cryptographically signed by
Cardnull before it may run — the Feather store's day — a true
signature will stand in the format beside or above this
field, and this document will be amended to say so. Until
then, nothing in the format claims or imitates signing, and
the checksum's modesty is part of the format.

## The door's services — what a program may ask

A feather's program speaks to the kernel through one door,
interrupt 0x80 — the same door `run`'s bare guests use. The
guest names the service in `rax`; the words ride in `rsi`,
`rdx`, `rcx`, `r8`, `r9`, in that order; the answer comes
home in `rax`. Every other register is kept across the door.
Services 0–3 are the first suite (milestones 9, 10 and 15);
services 4–8 are the graphical suite (milestone 18), which
gives a guest a face; service 9 (milestone 25) is the
window standing, the guest's news of its window. Services
10 and 11 (milestone 31) are the file services: a guest
may read a named file off the Cardnull disk into its own
memory, and write its memory out as a named file — the
disk keeps its laws on both sides of the door.

| # | service | the words | the answer |
| --- | --- | --- | --- |
| 0 | exit | `rdi` = the exit code | never returns |
| 1 | write string | address, length | the count written, or all-ones when the reach leaves the guest's estate |
| 2 | write character | the character in `rsi`'s low byte | 1 |
| 3 | yield | — | — (the machine goes to the partner, or the guest simply resumes) |
| 4 | screen size | — | the width in the low half, the height in the high half; 0 when no graphical screen is the guest's. Windowed, the answer is the window's canvas (below) |
| 5 | fill rectangle | x, y, width, height, colour (0x00RRGGBB) | 0 when drawn (clipped to the screen — windowed, to the canvas), 1 when refused whole — degenerate, or off the ground entirely — with nothing drawn |
| 6 | draw text | x, y, address, length, colour | the count drawn, at most 256 |
| 7 | read key | — | the key as a character (Enter = 0x0A, Backspace = 0x08), or 0 when no key waits — windowed, also 0 while another window holds the room |
| 8 | poll mouse | — | the pointer's place in the low words and its buttons above them (bit 0 left, 1 right, 2 middle), and — since milestone 26 — the wheel's turning in the byte above them (bits 40–47): the signed sum since the guest last asked, positive turned up toward older lines, spent by the asking; all-ones when it is not the guest's to ask. Windowed, the place is the desktop pointer's, relative to the canvas and signed, and the buttons answer only while the pointer stands over the canvas |
| 9 | window standing | — | bits of one word: bit 0 a repaint is owed, bit 1 your face holds the room, bit 2 the pointer stands over your ground; all-ones in a pair |
| 10 | read a file | name address, name length, destination address, room offered | the byte count copied; all-ones for a bad reach or a name the disk cannot hold, one less when no Cardnull disk stands ready, two less when the name does not stand, three less when the file is longer than one sector (512 bytes) or longer than the room offered — refused whole, nothing copied |
| 11 | write a file | name address, name length, source address, byte count (at most 512) | 0 when written; all-ones for a bad reach, a bad name, or a count past the bound, one less when no Cardnull disk stands ready, two less when the name already stands, four less when the disk has no room |

The laws that bind the suite:

- **The estate is the whole world.** Draw text proves its
  pointer and length against the guest's own ground with
  exactly the write-string discipline — the whole reach
  inside the estate before a byte is read. Where write
  string answers a bad reach with all-ones and lets the
  guest walk on, draw text **stops the guest**: the kernel
  reports the address at the top of the screen (the door's
  protection report), the launching screen is restored,
  and the shell answers with the stopping's words.
  BADGFX.BIN walks this road on purpose. A guest never
  touches the framebuffer itself: it names places, shapes
  and colours, and the kernel's own hand draws — a wild
  rectangle is clipped, never written wide (WILDRECT.BIN
  is the witness).
- **The face fits the room it was opened in.** Launched
  from the text shell, a guest that uses the graphical
  suite takes the whole screen for its session, as it
  always has. Launched while the desktop stands — typed
  in the Terminal window, or double-clicked in the Files
  window, which types through the same Terminal — a
  *feather's* face opens in a **window** on the desktop
  (milestone 25): titled with the card's own title, with
  the desktop's chrome, a close box, drag-by-title
  movement and focus by click, standing over the desktop's
  own windows for the whole session (a guest's face has
  no launcher in the bar to raise it from burial, so it
  is never buried; its focus is told by its title bar's
  colour, as the other windows' is). Bare guests (`run`,
  `both`) always keep the whole screen. The window's size
  is **fixed at the opening** — a feather reckons its
  face from service 4's answer once, and a size that
  moved under it would make its own reckoning a lie; a
  different size means closing and reopening the feather.
  There is no resize furniture and no maximize box.
  Inside the window, the door's words keep their numbers
  and take the window's meanings: service 4 answers the
  canvas's measure; services 5 and 6 are reckoned in
  canvas coordinates, offset by the canvas's origin and
  clipped to the canvas (and never into the bottom bar);
  service 8 answers the desktop's own pointer relative
  to the canvas — signed sixteen-bit words, so a pointer
  outside answers honestly negative — with the buttons
  the guest's only while the pointer stands over the
  canvas, and (milestone 26) the wheel's turning in its
  fourth word, gathered from turnings over the canvas
  alone; service 7 delivers keys only while the
  feather's window holds the room (while another window
  holds it, gathered keys are let go, the way the
  desktop's own faces let go of keys that are not
  theirs). The close box ends the session with the
  mouse, with Esc's own verdict. When the session ends —
  by leaving, by a fault, by the user's Esc, by the close
  box — the world it stood on is repainted exactly: the
  desktop and the Terminal's conversation, or the text
  shell's grid, as they stood.
- **The repaint duty (service 9).** The kernel paints
  its side of a window — the frame, the title, and the
  canvas laid with its ground — when the window opens,
  when the room changes hands, and when the window is
  set down from a drag. That ground-laying is the
  kernel's invalidation of the guest's canvas, and the
  guest learns of it by knocking on service 9: bit 0
  answers "a repaint is owed" until the guest asks, and
  a well-mannered feather paints its **whole face** again
  the moment the owing stands, before it goes on — its
  poll loop is where the knock belongs (TERM.FEATHER and
  FACE.FEATHER both keep this law). Bits 1 and 2 answer
  whether the guest's face holds the room and whether
  the pointer stands over its ground. A full-screen
  session answers bits 1 and 2 standing and bit 0 owed
  once, at the claim — one contract for both roads. A
  feather that never knocks on service 9 will simply
  wear the kernel's ground where its face was painted
  over; the owing is the contract, and keeping it is
  the feather's part.
- **The wheel's word (service 8).** Since milestone 26
  the mouse poll's answer carries a fourth word, at
  bits 40–47: the signed sum of the wheel's turnings
  since the guest last asked — positive turned up,
  away from the hand, toward older lines; negative
  turned down, toward the present — and the asking
  spends it, so the next answer hears only what has
  turned since. (The mouse's own byte counts the
  other way; the kernel reckons turnings, not bytes.)
  A plain mouse with no wheel simply never turns it:
  the word stands 0, as it did before the word
  existed. Windowed, the turnings are gathered by the
  face's own packet assembly, and only turnings while
  the pointer stands over the guest's canvas are the
  guest's — over its frame or another window they are
  the desktop's, as a click there would be.
  Full-screen, the guest's own packets feed the sum.
  TERM.FEATHER is the demonstrating guest: it asks on
  every turn of its loop and lifts its view through
  its scrollback by the answer, three lines to a
  notch, clamped at its eldest line.
- **One guest only.** Graphical services belong to a
  session of one guest (`run` or `feather`) — windowed or
  full-screen alike. In a pair session (`both`) a
  graphical knock is refused — the reason spoken on the
  screen once, and the service's nothing answered (0, or
  1 for a rectangle, or all-ones for the mouse and the
  window standing) — because a face cannot be shared by
  turns.
- **Esc is the user's key.** While any session stands,
  Esc ends it — the guest is stopped and the shell
  reports the stopping — and a guest never receives Esc
  through read key. A guest that wants to wait for a key
  knocks on read key, hears 0, and yields (service 3)
  until a key answers.
- **Text is the kernel's font at twofold size** — the
  measure of the desktop's windows, 16 pixels a letter —
  clipped at the screen's edge (windowed, at the canvas's
  edge). Keys are read with the kernel's own translation
  (Shift and Caps Lock as the shell reads them), under
  typing state the guest keeps for itself. Full-screen,
  the mouse answer is the session's own reckoning — it
  opens at the screen's centre and is fed by the guest's
  polls; the kernel draws no pointer for a guest.
  Windowed, the pointer is the desktop's own and the
  kernel does draw it — the guest reads its standing
  through services 8 and 9 and paints nothing of it.
- **The file services keep the disk's laws (services
  10 and 11).** One file at a time, named as the disk
  names files, and at most one sector — 512 bytes — in
  either direction: the keeping is one sector honest,
  and a longer file is refused whole rather than read
  in part. Writing never overwrites: a name that
  stands is refused, as it is at the Terminal and in
  the Write window, because it is the same filesystem
  down all three roads — a file a feather writes is a
  file `dcat` and the editor read, and the other way
  around. The disk is judged fresh at every knock, as
  the shell judges it; no disk at all, or a disk not
  Cardnull's, hears one less than all-ones, and no
  refusal writes anything. Every reach — the name,
  the source, the destination — is proven against the
  guest's estate before a byte of it is read or
  written, with exactly the write-string discipline.
  KEEP.FEATHER is the standing witness: it writes
  NOTE.TXT, reads it back, and speaks the bytes.
- **There is no sound service.** The speaker is the
  kernel's own voice (milestone 17's `sound` command); a
  feather cannot yet sing, and a guest asking for a
  service the door does not have hears all-ones.

Two feathers on every disc since milestone 18 stand on
this suite alone: FACE.FEATHER, a greeting painted by its
guest (a cardinal drawn from honest rectangles), and
TERM.FEATHER — a terminal that *is* a feather, with its
own framed screen, prompt, scrollback and small command
set (`help`, `verse`, `about`, `clear`, `exit`), the
stone the kernel's Terminal window always said was
coming. Since milestone 25 both live the windowed life
from the desktop: FACE's panel simply comes humbler and
still centred at the canvas's measure, and TERM reckons
its text columns from the width it is given and **wraps
its lines** at that measure as they join its scrollback
(a long line breaks at its last fitting space, or is cut
plainly when it has none) — its welcome prose no longer
runs off any edge. Both knock on service 9 in their wait
loops and repaint whole when a repaint is owed.

## Foreign packages

The OS does not try to run what is not a feather: `.exe`,
`.dmg`, tarballs, and every other foreign shape are refused
rather than interpreted — `feather` answers "not a feather"
to anything that does not open with the magic line, and no
other command loads packages at all. A program arrives as a
feather, with its card, or it does not arrive.

## Packing

`tools/pack-feather.py` is the packer:

```
pack-feather.py pack <card> <program> <out.feather>
```

It reads a card source (the magic line and the maker's keys,
as kept under `feathers/`), refuses a card that lacks title,
maker, version, or support, reckons the program's size and
checksum, and writes the finished feather. The build
(`tools/build-iso.sh`) packs the first feather —
HELLO.FEATHER, maker Cardnull, its program the greeting guest
in `feathers/greet.s` — onto every disc it makes, and packs
TAMPERED.FEATHER beside it: the same feather with one program
byte flipped after packing, its checksum left stale on
purpose, so the handler's refusal can be witnessed rather
than believed.
