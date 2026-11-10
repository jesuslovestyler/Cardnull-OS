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
gives a guest a face.

| # | service | the words | the answer |
| --- | --- | --- | --- |
| 0 | exit | `rdi` = the exit code | never returns |
| 1 | write string | address, length | the count written, or all-ones when the reach leaves the guest's estate |
| 2 | write character | the character in `rsi`'s low byte | 1 |
| 3 | yield | — | — (the machine goes to the partner, or the guest simply resumes) |
| 4 | screen size | — | the width in the low half, the height in the high half; 0 when no graphical screen is the guest's |
| 5 | fill rectangle | x, y, width, height, colour (0x00RRGGBB) | 0 when drawn (clipped to the screen), 1 when refused whole — degenerate, or off the screen entirely — with nothing drawn |
| 6 | draw text | x, y, address, length, colour | the count drawn, at most 256 |
| 7 | read key | — | the key as a character (Enter = 0x0A, Backspace = 0x08), or 0 when no key waits |
| 8 | poll mouse | x, y, buttons | the pointer's place in the low words and its buttons above them (bit 0 left, 1 right, 2 middle); all-ones when it is not the guest's to ask |

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
- **The screen is the guest's, whole.** A guest that uses
  the graphical suite takes the whole screen for its
  session; there is no windowing of guests yet. When the
  session ends — by leaving, by a fault, by the user's
  Esc — the world it covered is repainted exactly: the
  desktop and the Terminal's conversation, or the text
  shell's grid, as they stood.
- **One guest only.** Graphical services belong to a
  session of one guest (`run` or `feather`). In a pair
  session (`both`) a graphical knock is refused — the
  reason spoken on the screen once, and the service's
  nothing answered (0, or 1 for a rectangle, or all-ones
  for the mouse) — because a face cannot be shared by
  turns.
- **Esc is the user's key.** While any session stands,
  Esc ends it — the guest is stopped and the shell
  reports the stopping — and a guest never receives Esc
  through read key. A guest that wants to wait for a key
  knocks on read key, hears 0, and yields (service 3)
  until a key answers.
- **Text is the kernel's font at twofold size** — the
  measure of the desktop's windows, 16 pixels a letter —
  clipped at the screen's edge. Keys are read with the
  kernel's own translation (Shift and Caps Lock as the
  shell reads them), under typing state the guest keeps
  for itself. The mouse answer is the session's own
  reckoning — it opens at the screen's centre and is fed
  by the guest's polls; the kernel draws no pointer for a
  guest.
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
coming.

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
