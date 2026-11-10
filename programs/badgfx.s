# BADGFX.BIN - the guest that reaches through the door (milestone 18).
#
# BAD.BIN's cousin. BAD reaches with its own hand — a load from
# the kernel's first byte at 0x100000 — and the page fault stops
# it. BADGFX never touches the address itself: it asks the
# kernel to do the reaching, knocking on the door's draw-text
# service (service 6) with a pointer aimed at that same byte,
# hoping the kernel will read its own memory at a guest's word.
#
# The door's law is the write-string discipline, sharpened: the
# reach is proven against the guest's estate before a byte is
# read, and a reach that leaves the estate is refused AND stops
# the guest, under the door's own protection report. BADGFX
# first paints a small panel through the drawing services, so
# the screen can show whose face it was, and then makes the
# ask. Under honest separation the kernel reports the address,
# stops this program, restores the screen it covered, and the
# shell answers the next command unharmed.
#
# If the text were ever drawn — if the door read where it was
# pointed — BADGFX would arrive below and exit with code 9 to
# confess it. The guest's contract is the one written out in
# hello.s, widened by milestone 18's suite, published in
# docs/FEATHER.md: service 4 takes the screen's size, 5 fills
# a rectangle (rsi = x, rdx = y, rcx = width, r8 = height,
# r9 = colour 0x00RRGGBB), 6 draws text (rsi = x, rdx = y,
# rcx = the words' address, r8 = their length, r9 = colour).
# Written by hand, in the open, in the public domain.

    .text
    .globl  _start
_start:
    # Take the screen's measure first (service 4), so the
    # panel's painting is honest work through the suite and
    # not a text-door trick.
    mov     $4, %rax                # service 4: screen size
    int     $0x80                   # the door

    # Paint a small parchment panel: my face, before the ask.
    mov     $80, %rsi               # x
    mov     $80, %rdx               # y
    mov     $320, %rcx              # width
    mov     $120, %r8               # height
    mov     $0xF4EDDE, %r9          # parchment
    mov     $5, %rax                # service 5: fill a rectangle
    int     $0x80                   # the door

    # One honest line on the panel, from my own ground.
    mov     $96, %rsi               # x
    mov     $96, %rdx               # y
    lea     msg(%rip), %rcx         # the words, from my own image
    mov     $msg_end - msg, %r8     # their length
    mov     $0x241A12, %r9          # ink
    mov     $6, %rax                # service 6: draw text
    int     $0x80                   # the door

    # THE ASK: draw text from the kernel's first byte.
    mov     $96, %rsi               # x
    mov     $128, %rdx              # y
    mov     $0x100000, %rcx         # the kernel's first byte - not mine
    mov     $8, %r8                 # read me eight of them
    mov     $0x241A12, %r9          # ink
    mov     $6, %rax                # service 6: draw text
    int     $0x80                   # the door - which stops me here

    # Only a broken wall lets the program arrive here.
    mov     $9, %rdi                # exit code 9: the wall was not there
    mov     $0, %rax                # service 0: exit
    int     $0x80

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b

msg:
    .ascii  "BADGFX: this panel is mine."
msg_end:
