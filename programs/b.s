# B.BIN - the second of the pair (milestone 10).
#
# A's partner, and deliberately the longer-lived: where A prints
# five tokens and leaves, B prints seven - B1 to B7 - yielding
# after each but the last. Run together by `both`, the two
# interleave (A1 B1 A2 B2 ... A5 B5), and when A leaves after
# its fifth token, B's last two tokens print alone, which is
# the visible proof that a survivor runs on when its partner
# is done. B leaves with an exit code equal to its count, 7,
# for the same reason A leaves with 5: the report can be
# checked against the screen.
#
# The guest's contract is the one written out in hello.s, with
# the door grown by one service (milestone 10): 3 yields the
# machine to the other guest, every register kept across it.
# Written by hand, in the open, in the public domain.

    .text
    .globl  _start
_start:
    mov     $1, %rbx                # my count, from 1
turn:
    mov     $66, %rsi               # 'B' - service 2 writes one character
    mov     $2, %rax
    int     $0x80
    mov     %rbx, %rsi              # the count, turned into its digit
    add     $48, %rsi
    mov     $2, %rax
    int     $0x80
    mov     $10, %rsi               # the newline that ends the token
    mov     $2, %rax
    int     $0x80

    cmp     $7, %rbx                # seven tokens, and no more
    je      leave
    inc     %rbx
    mov     $3, %rax                # service 3: yield - your turn
    int     $0x80
    jmp     turn

leave:
    mov     %rbx, %rdi              # exit code 7: my count, spoken truly
    mov     $0, %rax                # service 0: exit
    int     $0x80

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b
