# FACE - the program inside FACE.FEATHER (milestone 18).
#
# The first feather with a face. Where GREET could only speak
# through the text door, FACE paints: it takes the screen's
# measure through service 4, lays a deep-cardinal field over
# the whole screen, stands a parchment panel on it with a
# cardinal title bar, writes its greeting and the house verse
# as drawn text, draws a small cardinal out of honest
# rectangles — body, wing, crest, beak, eye, legs, branch;
# no borrowed art, nothing but service 5's filled rectangles —
# and then waits for a key. Any key it receives (service 7)
# sends it home cleanly by the exit door; Esc it never
# receives, for Esc is the user's key, and the kernel keeps
# the session's stop armed while a face stands.
#
# The whole screen is FACE's for the session — there is no
# windowing of guests — and when it leaves, the kernel
# repaints the world it covered: the desktop and the
# Terminal's conversation, or the text shell's grid, exactly
# as they stood. The guest's contract is the one written out
# in programs/hello.s, widened by milestone 18's suite and
# published in docs/FEATHER.md: service 4 the screen's size
# (width in the answer's low half, height in the high), 5 a
# filled rectangle, 6 drawn text, 7 a key (0 when none waits),
# 3 a yield, 0 the leaving. Written by hand, in the open, in
# the public domain.

    .text
    .globl  _start
_start:
    # The screen's measure, kept in registers the door
    # preserves: r12 the width, r13 the height.
    mov     $4, %rax                # service 4: screen size
    int     $0x80                   # the door
    test    %rax, %rax
    je      hopeless                # no screen is mine to paint
    mov     %eax, %r12d             # the width (a 32-bit move clears the top)
    shr     $32, %rax
    mov     %rax, %r13              # the height

    # The panel's shape, reckoned from the measure (r14 its
    # left, r15 its top, rbx its width, rbp its height):
    # a generous card on a wide screen, a humbler one that
    # still fits on a narrow one.
    cmp     $960, %r12
    jbe     narrow
    mov     $880, %rbx
    jmp     width_done
narrow:
    mov     %r12, %rbx
    sub     $80, %rbx
width_done:
    mov     %r12, %r14
    sub     %rbx, %r14
    shr     $1, %r14                # centred
    cmp     $560, %r13
    jbe     short
    mov     $440, %rbp
    jmp     height_done
short:
    mov     %r13, %rbp
    sub     $120, %rbp
height_done:
    mov     %r13, %r15
    sub     %rbp, %r15
    shr     $1, %r15                # centred

    # The field: the whole screen, deep cardinal.
    xor     %esi, %esi              # x = 0
    xor     %edx, %edx              # y = 0
    mov     %r12, %rcx              # the screen's own width
    mov     %r13, %r8               # and height
    mov     $0x3D0D1A, %r9          # deep cardinal
    call    fill

    # The panel's shadow, then the panel, then its title bar,
    # then the border drawn last so it stands over both.
    mov     %r14, %rsi
    add     $10, %rsi
    mov     %r15, %rdx
    add     $12, %rdx
    mov     %rbx, %rcx
    mov     %rbp, %r8
    mov     $0x0A0206, %r9          # the shadow's near-black
    call    fill
    mov     %r14, %rsi
    mov     %r15, %rdx
    mov     %rbx, %rcx
    mov     %rbp, %r8
    mov     $0xF4EDDE, %r9          # parchment
    call    fill
    mov     %r14, %rsi
    mov     %r15, %rdx
    mov     %rbx, %rcx
    mov     $52, %r8
    mov     $0x7A1220, %r9          # cardinal, for the title bar
    call    fill
    mov     %r14, %rsi              # the border: top
    mov     %r15, %rdx
    mov     %rbx, %rcx
    mov     $2, %r8
    mov     $0x2A1A12, %r9
    call    fill
    mov     %r14, %rsi              # bottom
    mov     %r15, %rdx
    add     %rbp, %rdx
    sub     $2, %rdx
    mov     %rbx, %rcx
    mov     $2, %r8
    mov     $0x2A1A12, %r9
    call    fill
    mov     %r14, %rsi              # left
    mov     %r15, %rdx
    mov     $2, %rcx
    mov     %rbp, %r8
    mov     $0x2A1A12, %r9
    call    fill
    mov     %r14, %rsi              # right
    add     %rbx, %rsi
    sub     $2, %rsi
    mov     %r15, %rdx
    mov     $2, %rcx
    mov     %rbp, %r8
    mov     $0x2A1A12, %r9
    call    fill

    # The title, in the bar.
    mov     %r14, %rsi
    add     $20, %rsi
    mov     %r15, %rdx
    add     $18, %rdx
    lea     title(%rip), %rcx
    mov     $title_end - title, %r8
    mov     $0xFFFFFF, %r9          # white
    call    draw

    # The greeting and the house verse, in ink on parchment.
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     $80, %rdx
    lea     greet(%rip), %rcx
    mov     $greet_end - greet, %r8
    mov     $0x241A12, %r9          # ink
    call    draw
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     $120, %rdx
    lea     verse1(%rip), %rcx
    mov     $verse1_end - verse1, %r8
    mov     $0x241A12, %r9
    call    draw
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     $144, %rdx
    lea     verse2(%rip), %rcx
    mov     $verse2_end - verse2, %r8
    mov     $0x241A12, %r9
    call    draw
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     $168, %rdx
    lea     verse3(%rip), %rcx
    mov     $verse3_end - verse3, %r8
    mov     $0x241A12, %r9
    call    draw
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     $192, %rdx
    lea     verse4(%rip), %rcx
    mov     $verse4_end - verse4, %r8
    mov     $0x241A12, %r9
    call    draw
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     $224, %rdx
    lea     attrib(%rip), %rcx
    mov     $attrib_end - attrib, %r8
    mov     $0x241A12, %r9
    call    draw

    # The cardinal, out of rectangles. Its ground: r10 the
    # left, r11 the top of the bird's own small field, at the
    # panel's right hand.
    mov     %r14, %r10
    add     %rbx, %r10
    sub     $236, %r10
    mov     %r15, %r11
    add     $104, %r11
    mov     %r10, %rsi              # tail, lower
    mov     %r11, %rdx
    add     $128, %rdx
    mov     $64, %rcx
    mov     $13, %r8
    mov     $0x7A1220, %r9
    call    fill
    mov     %r10, %rsi              # tail, upper
    add     $14, %rsi
    mov     %r11, %rdx
    add     $112, %rdx
    mov     $66, %rcx
    mov     $13, %r8
    mov     $0x8E1626, %r9
    call    fill
    mov     %r10, %rsi              # body
    add     $52, %rsi
    mov     %r11, %rdx
    add     $46, %rdx
    mov     $108, %rcx
    mov     $88, %r8
    mov     $0xB01E28, %r9          # the bird's bright cardinal
    call    fill
    mov     %r10, %rsi              # wing
    add     $72, %rsi
    mov     %r11, %rdx
    add     $68, %rdx
    mov     $58, %rcx
    mov     $38, %r8
    mov     $0x7A1220, %r9
    call    fill
    mov     %r10, %rsi              # head
    add     $128, %rsi
    mov     %r11, %rdx
    add     $8, %rdx
    mov     $54, %rcx
    mov     $54, %r8
    mov     $0xB01E28, %r9
    call    fill
    mov     %r10, %rsi              # crest, back point
    add     $128, %rsi
    mov     %r11, %rdx
    sub     $10, %rdx
    mov     $11, %rcx
    mov     $24, %r8
    mov     $0xB01E28, %r9
    call    fill
    mov     %r10, %rsi              # crest, front point
    add     $143, %rsi
    mov     %r11, %rdx
    sub     $4, %rdx
    mov     $11, %rcx
    mov     $20, %r8
    mov     $0xB01E28, %r9
    call    fill
    mov     %r10, %rsi              # beak, upper
    add     $182, %rsi
    mov     %r11, %rdx
    add     $26, %rdx
    mov     $24, %rcx
    mov     $9, %r8
    mov     $0xD9B36A, %r9          # gold
    call    fill
    mov     %r10, %rsi              # beak, lower
    add     $182, %rsi
    mov     %r11, %rdx
    add     $37, %rdx
    mov     $17, %rcx
    mov     $8, %r8
    mov     $0xC9A24B, %r9
    call    fill
    mov     %r10, %rsi              # eye
    add     $152, %rsi
    mov     %r11, %rdx
    add     $24, %rdx
    mov     $8, %rcx
    mov     $8, %r8
    mov     $0x241A12, %r9          # ink
    call    fill
    mov     %r10, %rsi              # legs
    add     $86, %rsi
    mov     %r11, %rdx
    add     $134, %rdx
    mov     $6, %rcx
    mov     $24, %r8
    mov     $0x2A1A12, %r9
    call    fill
    mov     %r10, %rsi
    add     $116, %rsi
    mov     %r11, %rdx
    add     $134, %rdx
    mov     $6, %rcx
    mov     $24, %r8
    mov     $0x2A1A12, %r9
    call    fill
    mov     %r10, %rsi              # the branch it stands on
    add     $40, %rsi
    mov     %r11, %rdx
    add     $158, %rdx
    mov     $140, %rcx
    mov     $8, %r8
    mov     $0x2A1A12, %r9
    call    fill

    # The invitation, at the panel's foot.
    mov     %r14, %rsi
    add     $36, %rsi
    mov     %r15, %rdx
    add     %rbp, %rdx
    sub     $36, %rdx
    lea     hint(%rip), %rcx
    mov     $hint_end - hint, %r8
    mov     $0x241A12, %r9
    call    draw

    # Wait for a key: knock, hear nothing, yield, knock again.
wait:
    mov     $7, %rax                # service 7: read a key
    int     $0x80                   # the door
    test    %rax, %rax
    jne     leave                   # any key that is mine: go home
    mov     $3, %rax                # service 3: yield
    int     $0x80                   # the door
    jmp     wait

leave:
    mov     $0, %rdi                # exit code 0: a clean leaving
    mov     $0, %rax                # service 0: exit
    int     $0x80

hopeless:
    mov     $3, %rdi                # no screen was mine to paint
    mov     $0, %rax                # service 0: exit
    int     $0x80

    # fill: one knock on service 5 with the caller's five
    # words standing in rsi, rdx, rcx, r8, r9.
fill:
    mov     $5, %rax
    int     $0x80
    ret

    # draw: one knock on service 6, the same five words.
draw:
    mov     $6, %rax
    int     $0x80
    ret

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b

title:
    .ascii  "Cardnull OS"
title_end:
greet:
    .ascii  "Welcome to Cardnull OS."
greet_end:
verse1:
    .ascii  "In the beginning was"
verse1_end:
verse2:
    .ascii  "the Word, and the Word"
verse2_end:
verse3:
    .ascii  "was with God, and the"
verse3_end:
verse4:
    .ascii  "Word was God."
verse4_end:
attrib:
    .ascii  "- John 1:1 (Douay-Rheims)"
attrib_end:
hint:
    .ascii  "Press any key to go back."
hint_end:
