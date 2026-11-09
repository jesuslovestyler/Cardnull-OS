# HELLO.BIN - the first program Cardnull OS ever ran (milestone 9).
#
# A guest, not kernel: this file is assembled into a flat binary,
# packed onto the ISO as /HELLO.BIN, and exists nowhere in the
# kernel. The kernel reads it off the disc, lays it on ground of
# its own, and drops into ring 3 at its first byte.
#
# The guest's contract with the kernel (the service door):
#   entry   RIP = 0x40000000 (the file's first byte),
#           RSP = the top of the guest stack (0x40015000).
#   ground  these pages are the guest's whole world:
#             0x40000000  its own image - read and execute, never write
#             0x40010000  one scratch page - read and write
#             0x40011000  its stack, four pages - read and write
#   door    int 0x80, with rax naming the service:
#             1 = write a string: rsi = its address (in the guest's
#                 own ground), rdx = its length; rax returns the
#                 count written, or -1 if the kernel refused.
#             2 = write one character: rsi's low byte.
#             0 = exit: rdi = the exit code. Never returns.
#   Every other register is kept across the door, except rax.
#
# HELLO's whole work: say who it is, through the door, and leave
# by it. Written by hand, in the open, in the public domain.

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
    # rather than wander: hlt in ring 3 faults, and the kernel's
    # report of that fault is a more honest end than silence.
1:
    hlt
    jmp     1b

msg:
    .ascii  "Hello! I am HELLO.BIN, the first program Cardnull OS ever ran.\n"
    .ascii  "I was read off the disc, given ground of my own, and I ran in ring 3.\n"
    .ascii  "The kernel lent me its voice. It did not lend me its keys.\n"
msg_end:
