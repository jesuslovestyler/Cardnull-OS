# GREET - the program inside the first feather (milestone 11).
#
# A guest, like the programs in programs/, but this one does not
# travel bare: it is packed inside HELLO.FEATHER, behind a card
# that names its title, its maker, its version, and its support
# line, and beside a checksum the handler in the kernel reckons
# again before a byte of it is run (see docs/FEATHER.md). The
# card is the label; this is what the label speaks of.
#
# The guest's contract with the kernel is the one written out
# in programs/hello.s — the service door at interrupt 0x80:
# entry at 0x40000000 in ring 3, the image read and execute and
# never writable, service 1 writes a string, service 0 leaves
# with a code. Nothing here knows it travelled in a package;
# the packaging is the kernel's and the packer's business, and
# the guest simply greets, as it was made to. Written by hand,
# in the open, in the public domain.

    .text
    .globl  _start
_start:
    lea     msg(%rip), %rsi         # the words, from my own image
    mov     $msg_end - msg, %rdx    # their length
    mov     $1, %rax                # service 1: write a string
    int     $0x80                   # the door

    mov     $0, %rdi                # exit code 0: a clean leaving
    mov     $0, %rax                # service 0: exit
    int     $0x80

    # The exit door never returns. If it somehow did, rest here
    # rather than wander, as the guests before me were taught.
1:
    hlt
    jmp     1b

msg:
    .ascii  "Hello! I am the first feather Cardnull OS ever opened.\n"
    .ascii  "I travelled in a package: a card that names my maker,\n"
    .ascii  "and a checksum the kernel checked before it let me run.\n"
msg_end:
