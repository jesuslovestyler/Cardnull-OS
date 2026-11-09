# COUNT.BIN - the counting guest (milestone 9).
#
# HELLO proves a guest can speak; COUNT proves a guest can work:
# the numbers 1 to 10 are reckoned here, digit by digit, out of a
# counter in a register - nothing about them is a canned string.
# Each number is divided by ten again and again, its remainders
# turned into digits in the scratch page, and the finished line
# handed to the kernel's door (int 0x80, service 1) to print.
#
# The guest's contract is the one written out in hello.s: entry
# at 0x40000000, the scratch page at 0x40010000, exit through
# service 0. Written by hand, in the open, in the public domain.

    .text
    .globl  _start
_start:
    mov     $0x40010000, %r12       # the scratch page is mine to write
    movb    $10, 32(%r12)           # the newline that ends every line
    mov     $1, %rbx                # the number to speak of, from 1
number:
    mov     %rbx, %rax              # the number, into the reckoning
    lea     31(%r12), %rcx          # digits laid backwards, ending here
    mov     $10, %r8                # the divisor: ten, always ten
digit:
    xor     %rdx, %rdx              # the division's high half: nothing
    div     %r8                     # rax = quotient, rdx = remainder
    add     $48, %dl                # a remainder, turned into its digit
    mov     %dl, (%rcx)             # and laid down
    dec     %rcx
    test    %rax, %rax              # anything left to divide?
    jnz     digit

    lea     1(%rcx), %rsi           # the string: first digit ...
    lea     33(%r12), %rdx          # ... to just past the newline
    sub     %rsi, %rdx              # its length
    mov     $1, %rax                # service 1: write a string
    int     $0x80

    inc     %rbx
    cmp     $11, %rbx               # 1 through 10, and no further
    jne     number

    mov     $0, %rdi                # exit code 0
    mov     $0, %rax                # service 0: exit
    int     $0x80

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b
