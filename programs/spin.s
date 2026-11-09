# SPIN.BIN - the guest that never gives the machine back (milestone 15).
#
# A guest, not kernel: assembled into a flat binary, packed onto
# the ISO as /SPIN.BIN, and existing nowhere in the kernel. Its
# whole work is a refusal: it prints one token - S1, S2, S3, and
# upward, the numbers reckoned digit by digit like COUNT's - then
# burns a long stretch of the processor in a tight loop, and does
# it again, forever. It never calls the door's yield service and
# never calls its exit: under milestone 10's cooperative keeping
# it would hold the machine until the power went out, starving
# any partner it was paired with. Milestone 15 exists to take
# turns by force, and SPIN is the witness the force is real: pair
# it with A (`both /SPIN.BIN /A.BIN`) and A still counts out its
# five tokens and leaves, on slices the timer cuts out of SPIN's
# spinning; alone (`run /SPIN.BIN`) it spins until the user's Esc
# stops the session and the shell stands again.
#
# The guest's contract is the one written out in hello.s: entry
# at 0x40000000, the scratch page at 0x40010000, speech through
# the door (int 0x80, services 1 and 2). Services 0 and 3 exist
# and are simply never called - that is the point of the program.
# Written by hand, in the open, in the public domain.

    .text
    .globl  _start
_start:
    mov     $0x40010000, %r12       # the scratch page is mine to write
    movb    $10, 32(%r12)           # the newline that ends every token
    mov     $1, %rbx                # the token's number, from 1
token:
    mov     $83, %rsi               # 'S' - service 2 writes one character
    mov     $2, %rax
    int     $0x80

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

    inc     %rbx                    # the next token's number

    # The burning: a countdown in a register, long enough that a
    # token is an event and not a flood - and spent entirely in
    # ring 3, in the open, where the timer can see it and cut in.
    # No door is knocked on here; that silence is the testimony.
    mov     $30000000, %rcx
burn:
    dec     %rcx
    jne     burn

    jmp     token

    hlt                             # never reached: SPIN does not end
    jmp     .-1
