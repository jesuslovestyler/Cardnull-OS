# WILDRECT.BIN - the guest that asks for too much screen (milestone 18).
#
# The rectangle service's other proof. Where BADGFX tests the
# wall, WILDRECT tests the clip: it knocks twice on service 5.
#
# First, a degenerate ask — a rectangle of no width. The door
# must refuse it (the answer 1), draw nothing, and let the
# guest walk on. If the answer is anything else, WILDRECT
# leaves with code 8 to confess that the refusal failed.
#
# Second, a wild ask: a rectangle beginning off the screen's
# top-left corner (x = -64, y = -32) and reaching 128 pixels
# past the screen's right edge and 64 past its bottom. The
# door must draw exactly the part that stands on the screen —
# the whole screen, in gold — answer 0, and let the guest walk
# on: which it proves by drawing a line of text over the gold
# and then waiting for a key like any well-mannered face, and
# leaving cleanly by the exit door with code 0.
#
# The guest's contract is the one written out in hello.s,
# widened by milestone 18's suite, published in docs/FEATHER.md:
# service 4 takes the screen's size (the answer's low half is
# the width, the high half the height), 5 fills a rectangle
# (rsi = x, rdx = y, rcx = width, r8 = height, r9 = colour
# 0x00RRGGBB; the answer 0 drawn, 1 refused), 6 draws text
# (rsi = x, rdx = y, rcx = the words' address, r8 = length,
# r9 = colour), 7 reads a key (0 when none waits), 3 yields.
# Written by hand, in the open, in the public domain.

    .text
    .globl  _start
_start:
    # The screen's measure, kept in the scratch page: the
    # width at its head, the height after it.
    mov     $4, %rax                # service 4: screen size
    int     $0x80                   # the door
    mov     %eax, %ebx              # the width (a 32-bit move clears the top)
    shr     $32, %rax
    mov     %rax, %r12              # the height
    mov     %rbx, %r13              # the width, kept whole

    # The degenerate ask: no width at all.
    mov     $10, %rsi               # x
    mov     $10, %rdx               # y
    xor     %ecx, %ecx              # width: none
    mov     $50, %r8                # height
    mov     $0xB01E28, %r9          # cardinal red
    mov     $5, %rax                # service 5: fill a rectangle
    int     $0x80                   # the door
    cmp     $1, %rax                # refused, as it must be?
    jne     confess                 # no: leave and confess

    # The wild ask: off the top-left, past the bottom-right.
    mov     $-64, %rsi              # x: off the left edge
    mov     $-32, %rdx              # y: off the top edge
    mov     %r13, %rcx
    add     $128, %rcx              # width: the screen's, and 128 more
    mov     %r12, %r8
    add     $64, %r8                # height: the screen's, and 64 more
    mov     $0xD9B36A, %r9          # gold
    mov     $5, %rax                # service 5: fill a rectangle
    int     $0x80                   # the door
    test    %rax, %rax              # drawn (clipped), as it must be?
    jne     confess                 # no: leave and confess

    # Still standing: a line of ink over the gold.
    mov     $48, %rsi               # x
    mov     $48, %rdx               # y
    lea     msg(%rip), %rcx         # the words, from my own image
    mov     $msg_end - msg, %r8     # their length
    mov     $0x241A12, %r9          # ink
    mov     $6, %rax                # service 6: draw text
    int     $0x80                   # the door

    # Wait for a key, politely: knock, hear nothing, yield.
wait:
    mov     $7, %rax                # service 7: read a key
    int     $0x80                   # the door
    test    %rax, %rax
    jne     leave                   # a key: go home
    mov     $3, %rax                # service 3: yield
    int     $0x80                   # the door
    jmp     wait

leave:
    mov     $0, %rdi                # exit code 0: a clean leaving
    mov     $0, %rax                # service 0: exit
    int     $0x80

confess:
    mov     $8, %rdi                # exit code 8: a refusal failed
    mov     $0, %rax                # service 0: exit
    int     $0x80

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b

msg:
    .ascii  "Clipped to the screen, and still standing."
msg_end:
