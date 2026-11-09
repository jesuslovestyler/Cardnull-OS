# BAD.BIN - the guest that reaches where it may not (milestone 9).
#
# The crown proof of the milestone is not that good guests run,
# but that a bad one can be stopped. BAD's whole work is a single
# reach: it tries to read the kernel's first byte, at 0x100000 -
# ground every guest's map shows but no guest's privilege may
# touch. Under honest separation the reach faults, the kernel
# reports the address and the reason, stops this program, and
# the shell answers the next command unharmed.
#
# If the byte were ever read - if the wall were a rumour - BAD
# would exit with code 9 to confess it, and the milestone's own
# report would have to say so. The guest's contract is the one
# written out in hello.s. Written by hand, in the open, in the
# public domain.

    .text
    .globl  _start
_start:
    mov     0x100000, %rax          # THE REACH: the kernel's first byte

    # Only a broken wall lets the program arrive here.
    mov     $9, %rdi                # exit code 9: the wall was not there
    mov     $0, %rax                # service 0: exit
    int     $0x80

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b
