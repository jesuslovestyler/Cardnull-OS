# A.BIN - the first of the pair (milestone 10).
#
# A guest, not kernel: assembled into a flat binary, packed onto
# the ISO as /A.BIN, and existing nowhere in the kernel. Milestone
# 9's `run` could carry one guest at a time; milestone 10's `both`
# carries two, and A's work is to make the taking of turns
# visible: it prints one token - A1, A2, up to A5 - then yields
# the machine to its partner through the door's third service,
# and when its fifth token stands it leaves, with an exit code
# equal to its count, so the shell's report can be checked
# against the tokens on the screen.
#
# The guest's contract is the one written out in hello.s, with
# the door grown by one service (milestone 10):
#             3 = yield: hand the machine to the other guest;
#                 every register is kept across it, and the guest
#                 resumes at the next instruction when its turn
#                 comes back - or at once, if no partner stands
#                 (alone, a yield is a courtesy with no taker).
# Written by hand, in the open, in the public domain.

    .text
    .globl  _start
_start:
    mov     $1, %rbx                # my count, from 1
turn:
    mov     $65, %rsi               # 'A' - service 2 writes one character
    mov     $2, %rax
    int     $0x80
    mov     %rbx, %rsi              # the count, turned into its digit
    add     $48, %rsi
    mov     $2, %rax
    int     $0x80
    mov     $10, %rsi               # the newline that ends the token
    mov     $2, %rax
    int     $0x80

    cmp     $5, %rbx                # five tokens, and no more
    je      leave
    inc     %rbx
    mov     $3, %rax                # service 3: yield - your turn
    int     $0x80
    jmp     turn

leave:
    mov     %rbx, %rdi              # exit code 5: my count, spoken truly
    mov     $0, %rax                # service 0: exit
    int     $0x80

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b
