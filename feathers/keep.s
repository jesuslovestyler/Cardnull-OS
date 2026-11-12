# KEEP - the program inside KEEP.FEATHER (milestone 31).
#
# The keeping feather. Milestone 31 gives the service door
# two file services — 11 writes a file to the Cardnull
# disk, 10 reads one back — and this feather is their
# witness, standing on the door alone the way TERM stands
# on the drawing suite: it keeps one small file, NOTE.TXT,
# holding the words "kept by keep.feather", and then reads
# it back and speaks what it read, so the round trip can
# be witnessed, not merely believed.
#
# Its whole conversation, in order: it says it is writing;
# it knocks on service 11 with the name and the words; it
# speaks the answer plainly — written, or refused, and
# why, in the door's own all-ones family (all-ones a bad
# reach, one less no ready disk, two less the name already
# standing, four less no room); it knocks on service 10
# for the file, into its scratch page with room for the
# one sector the door will ever carry; it speaks how many
# bytes came back and speaks the bytes themselves; and it
# says it is done, and leaves by service 0. A refusal on
# the reading road is spoken the same way — the file not
# there, no disk, too long, a bad reach.
#
# It needs a ready Cardnull disk: without one, both roads
# answer "no disk", and the feather says so and leaves
# clean, its testimony honest either way. It writes the
# file fresh or not at all — the door has no overwrite,
# and a NOTE.TXT already standing is answered "name
# taken", not replaced.
#
# Its keeping, all in the one scratch page at 0x40010000:
#   0x000  the read-back field (512 bytes, the door's bound)
# The name and the kept words stand in its image, where the
# door reads them out of its own ground. The guest's
# contract is the one written out in programs/hello.s,
# widened by milestone 31's two services and published in
# docs/FEATHER.md. Written by hand, in the open, in the
# public domain.

    .text
    .globl  _start
_start:
    mov     $0x40010000, %r15       # the scratch page: my desk

    lea     writing(%rip), %rsi     # "KEEP: writing NOTE.TXT"
    mov     $writing_end - writing, %rdx
    call    print_str

    # Service 11: write NOTE.TXT, the kept words as its body.
    lea     name(%rip), %rsi        # the name's address
    mov     $name_end - name, %rdx  # its length: 8
    lea     kept(%rip), %rcx        # the words' address
    mov     $kept_end - kept, %r8   # their length
    mov     $11, %rax               # service 11: write a file
    int     $0x80                   # the door

    test    %rax, %rax
    je      w_written               # 0: written
    cmp     $-1, %rax
    je      w_bad                   # all-ones: a bad reach
    cmp     $-2, %rax
    je      w_nodisk                # one less: no disk
    cmp     $-3, %rax
    je      w_taken                 # two less: the name stands
    cmp     $-5, %rax
    je      w_noroom                # four less: no room
    lea     refused(%rip), %rsi     # any other word: refused
    mov     $refused_end - refused, %rdx
    call    print_str
    jmp     do_read
w_written:
    lea     written(%rip), %rsi
    mov     $written_end - written, %rdx
    call    print_str
    jmp     do_read
w_bad:
    lea     wbad(%rip), %rsi
    mov     $wbad_end - wbad, %rdx
    call    print_str
    jmp     do_read
w_nodisk:
    lea     rnodisk(%rip), %rsi
    mov     $rnodisk_end - rnodisk, %rdx
    call    print_str
    jmp     do_read
w_taken:
    lea     taken(%rip), %rsi
    mov     $taken_end - taken, %rdx
    call    print_str
    jmp     do_read
w_noroom:
    lea     noroom(%rip), %rsi
    mov     $noroom_end - noroom, %rdx
    call    print_str
    jmp     do_read

do_read:
    # Service 10: read NOTE.TXT back, into the scratch
    # page, with the door's whole room offered: 512.
    lea     name(%rip), %rsi        # the name's address
    mov     $name_end - name, %rdx  # its length: 8
    mov     %r15, %rcx              # the destination: my desk
    mov     $512, %r8               # the room there
    mov     $10, %rax               # service 10: read a file
    int     $0x80                   # the door

    cmp     $512, %rax
    jbe     r_have                  # a count: the bytes stand
    cmp     $-1, %rax
    je      r_bad                   # all-ones: a bad reach
    cmp     $-2, %rax
    je      r_nodisk                # one less: no disk
    cmp     $-3, %rax
    je      r_gone                  # two less: not there
    cmp     $-4, %rax
    je      r_toolong               # three less: too long
    lea     refused(%rip), %rsi     # any other word: refused
    mov     $refused_end - refused, %rdx
    call    print_str
    jmp     finish
r_have:
    mov     %rax, %r14              # the count, kept — in a
                                    # register no speech hand
                                    # touches (print_num spends
                                    # rbx on its digits)
    lea     readpre(%rip), %rsi     # "KEEP: read back "
    mov     $readpre_end - readpre, %rdx
    call    print_str
    mov     %r14, %rax
    call    print_num               # the count, in decimal
    lea     readmid(%rip), %rsi     # " bytes:"
    mov     $readmid_end - readmid, %rdx
    call    print_str
    mov     %r15, %rsi              # the bytes themselves
    mov     %r14, %rdx
    call    print_str
    mov     $0x0A, %rsi             # and the line's ending
    call    print_chr
    jmp     finish
r_bad:
    lea     rbad(%rip), %rsi
    mov     $rbad_end - rbad, %rdx
    call    print_str
    jmp     finish
r_nodisk:
    lea     rnodisk(%rip), %rsi
    mov     $rnodisk_end - rnodisk, %rdx
    call    print_str
    jmp     finish
r_gone:
    lea     gone(%rip), %rsi
    mov     $gone_end - gone, %rdx
    call    print_str
    jmp     finish
r_toolong:
    lea     toolong(%rip), %rsi
    mov     $toolong_end - toolong, %rdx
    call    print_str
    jmp     finish

finish:
    lea     done(%rip), %rsi        # "KEEP: done"
    mov     $done_end - done, %rdx
    call    print_str
    mov     $0, %rdi                # a clean leaving
    mov     $0, %rax                # service 0: exit
    int     $0x80

    # The exit door never returns. If it somehow did, rest
    # here rather than wander, as hello.s rests.
1:
    hlt
    jmp     1b

# ------------------------------------------------------------------
# The door's speech hands. Every register is kept across
# the door except rax, the answer's home — the hands lean
# on exactly that contract and no more.
# ------------------------------------------------------------------

# print_str: rsi a string's place, rdx its length. Service
# 1 writes it through the door.
print_str:
    mov     $1, %rax                # service 1: write a string
    int     $0x80
    ret

# print_chr: rsi's low byte, one character. Service 2.
print_chr:
    mov     $2, %rax                # service 2: write a character
    int     $0x80
    ret

# print_num: rax a count, spoken in decimal by service 2,
# one digit at a time — the count divided by ten again and
# again, its remainders kept on the stack and spoken back
# in their true order. Zero speaks as zero.
print_num:
    xor     %ebx, %ebx              # the digits kept so far
    mov     $10, %rcx               # the divisor
pn_digit:
    xor     %edx, %edx              # the division's high half
    div     %rcx                    # rax the quotient, rdx the rest
    push    %rdx                    # the digit, kept
    inc     %rbx
    test    %rax, %rax
    jne     pn_digit
pn_speak:
    pop     %rsi                    # the eldest digit first
    add     $0x30, %rsi             # its letter: '0' and on
    call    print_chr
    dec     %rbx
    jne     pn_speak
    ret

writing:
    .ascii  "KEEP: writing NOTE.TXT\n"
writing_end:
written:
    .ascii  "KEEP: written\n"
written_end:
wbad:
    .ascii  "KEEP: refused - bad reach\n"
wbad_end:
rnodisk:
    .ascii  "KEEP: refused - no disk\n"
rnodisk_end:
taken:
    .ascii  "KEEP: refused - name taken\n"
taken_end:
noroom:
    .ascii  "KEEP: refused - no room\n"
noroom_end:
refused:
    .ascii  "KEEP: refused\n"
refused_end:
readpre:
    .ascii  "KEEP: read back "
readpre_end:
readmid:
    .ascii  " bytes:"
readmid_end:
gone:
    .ascii  "KEEP: the file is not there\n"
gone_end:
toolong:
    .ascii  "KEEP: refused - too long\n"
toolong_end:
rbad:
    .ascii  "KEEP: refused - bad reach\n"
rbad_end:
done:
    .ascii  "KEEP: done\n"
done_end:
name:
    .ascii  "NOTE.TXT"
name_end:
kept:
    .ascii  "kept by keep.feather"
kept_end:
