# TERM - the program inside TERM.FEATHER (milestone 18).
#
# The terminal that is a feather. Milestone 13 built the
# kernel a Terminal window and labelled it honestly — the
# kernel's own shell in a window, not a feather — because a
# true terminal feather had to wait for guest drawing and
# keyboard services. This is that feather, standing on
# milestone 18's suite alone: every letter on its screen is
# drawn by knocking on service 6, every key it reads arrives
# by service 7, and the kernel's shell is not involved while
# it runs — a fact the proof leans on: its prompt, its words
# and its little courtesies are visibly its own, and when it
# leaves, the launching shell answers `verse` in its own
# voice again, one screen apart from this one's.
#
# What it is: its own framed screen, reckoned from the size
# service 4 reports — a border, an ink ground, a cardinal
# title bar naming it "Feather Terminal" — a prompt ("> "),
# typing echoed as it comes, Backspace rubbing out, Enter
# answering, and a small scrollback of its own: the last
# twenty-eight lines it has spoken, kept in its scratch
# page, the eldest let go when the twenty-ninth arrives.
# Its words are few and its own: help, verse (John 1:1,
# Douay-Rheims, from its own data), about, clear, exit.
#
# Esc it never receives, and its help says so: Esc is the
# user's key, and pressed while TERM stands, it stops the
# feather and gives the screen back to the shell that
# called it — no shame in it; that is the law of the door.
#
# Its keeping, all in the one scratch page at 0x40010000:
#   0x000  the screen's width      0x008  its height
#   0x010  the visible text rows   0x018  the scrollback's count
#   0x020  the input line's length 0x028  the lines last shown
#   0x100  the input line (80)     0x200  the composed "> " line
#   0x300  the scrollback's line lengths (28 bytes)
#   0x400  the scrollback: 28 records of 72 bytes
# Lines hold at most 72 letters; the input takes 66, leaving
# room for the prompt's two. The guest's contract is the one
# written out in programs/hello.s, widened by milestone 18's
# suite and published in docs/FEATHER.md. Written by hand,
# in the open, in the public domain.

    .text
    .globl  _start
_start:
    mov     $0x40010000, %r15       # the scratch page: my desk

    mov     $4, %rax                # service 4: screen size
    int     $0x80                   # the door
    test    %rax, %rax
    je      hopeless                # no screen is mine to stand on
    mov     %eax, %edx              # the width (a 32-bit move clears the top)
    mov     %rdx, 0x00(%r15)        # the width, kept
    shr     $32, %rax
    mov     %rax, 0x08(%r15)        # the height
    cmpq    $400, 0x00(%r15)
    jb      hopeless                # a screen too small to frame
    cmpq    $300, 0x08(%r15)
    jb      hopeless

    movq    $0, 0x18(%r15)          # the scrollback starts empty
    movq    $0, 0x20(%r15)          # and so does the input line

    # The visible rows: (height - 190) / 16, held between
    # 4 and 24 — the scrollback's own depth is the real cap.
    mov     0x08(%r15), %rax
    sub     $190, %rax
    shr     $4, %rax
    cmp     $24, %rax
    jbe     rows_low
    mov     $24, %rax
rows_low:
    cmp     $4, %rax
    jae     rows_done
    mov     $4, %rax
rows_done:
    mov     %rax, 0x10(%r15)

    # The field first: the whole screen laid with the
    # desktop gradient's own foot colour, so the screen is
    # wholly mine while I stand — the frame stands on it.
    xor     %esi, %esi
    xor     %edx, %edx
    mov     0x00(%r15), %rcx
    mov     0x08(%r15), %r8
    mov     $0x100308, %r9          # near black, warm
    call    fill

    # The frame's border, drawn once: render_all repaints
    # only the ground within it.
    mov     $28, %rsi
    mov     $28, %rdx
    mov     0x00(%r15), %rcx
    sub     $56, %rcx
    mov     0x08(%r15), %r8
    sub     $56, %r8
    mov     $0x2A1A12, %r9          # the border's dark brown
    call    fill

    # The opening lines, into the scrollback.
    lea     boot1(%rip), %rsi
    mov     $boot1_end - boot1, %rdx
    call    append_line
    lea     boot2(%rip), %rsi
    mov     $boot2_end - boot2, %rdx
    call    append_line
    lea     boot3(%rip), %rsi
    mov     $boot3_end - boot3, %rdx
    call    append_line
    lea     boot4(%rip), %rsi
    mov     $boot4_end - boot4, %rdx
    call    append_line
    call    render_all

    # The whole life: knock for a key; none waiting, yield
    # and knock again.
keyloop:
    mov     $7, %rax                # service 7: read a key
    int     $0x80                   # the door
    test    %rax, %rax
    jne     have_key
    mov     $3, %rax                # service 3: yield
    int     $0x80                   # the door
    jmp     keyloop
have_key:
    cmp     $0x0A, %rax             # Enter: answer the line
    je      do_submit
    cmp     $0x08, %rax             # Backspace: rub one out
    je      do_back
    cmp     $0x20, %rax             # below the space: not a letter
    jb      keyloop
    cmp     $0x7E, %rax             # past the last printable
    ja      keyloop
    mov     0x20(%r15), %rcx        # the input's length
    cmp     $66, %rcx
    jae     keyloop                 # a full line takes no more
    mov     %al, 0x100(%r15, %rcx)  # the letter joins the line
    inc     %rcx
    mov     %rcx, 0x20(%r15)
    call    render_prompt
    jmp     keyloop
do_back:
    mov     0x20(%r15), %rcx
    test    %rcx, %rcx
    je      keyloop                 # nothing to rub out
    dec     %rcx
    mov     %rcx, 0x20(%r15)
    call    render_prompt
    jmp     keyloop
do_submit:
    call    submit_line
    jmp     keyloop

hopeless:
    mov     $3, %rdi                # no screen was mine to stand on
    mov     $0, %rax                # service 0: exit
    int     $0x80

# ------------------------------------------------------------------
# The door's two drawing hands, in the door's own register
# order: rsi = x, rdx = y, rcx and r8 the shape or the words,
# r9 the colour. Only rax is spent by a knock.
# ------------------------------------------------------------------

fill:
    mov     $5, %rax                # service 5: fill a rectangle
    int     $0x80
    ret

draw:
    mov     $6, %rax                # service 6: draw text
    int     $0x80
    ret

# ------------------------------------------------------------------
# copy_fwd: rdi the destination, rsi the source, rcx the
# count. Byte by byte, forward — the scrollback's shift
# copies downward, so forward never chases its own tail.
# ------------------------------------------------------------------
copy_fwd:
    test    %rcx, %rcx
    je      cf_done
cf_loop:
    movzbl  (%rsi), %eax
    mov     %al, (%rdi)
    inc     %rsi
    inc     %rdi
    dec     %rcx
    jne     cf_loop
cf_done:
    ret

# ------------------------------------------------------------------
# append_line: rsi a line's place, rdx its length (at most
# 72). The line joins the scrollback; a full scrollback lets
# its eldest go, records and lengths shifting up together.
# ------------------------------------------------------------------
append_line:
    mov     %rsi, %r10
    mov     %rdx, %r11
    mov     0x18(%r15), %rax        # the count
    cmp     $28, %rax
    jb      al_room
    lea     0x400(%r15), %rdi       # the records shift up one
    lea     0x448(%r15), %rsi
    mov     $1944, %rcx             # twenty-seven records of 72
    call    copy_fwd
    lea     0x300(%r15), %rdi       # and the lengths with them
    lea     0x301(%r15), %rsi
    mov     $27, %rcx
    call    copy_fwd
    mov     $27, %rax               # the count, for the store
al_room:
    mov     %rax, %rcx              # the record's place:
    shl     $6, %rcx                # count * 64
    mov     %rax, %rdx
    shl     $3, %rdx                # count * 8
    add     %rdx, %rcx              # count * 72
    lea     0x400(%r15, %rcx), %rdi
    xor     %ecx, %ecx              # the record wiped first,
al_zero:
    cmp     $72, %rcx
    jae     al_copy
    movb    $0, (%rdi, %rcx)
    inc     %rcx
    jmp     al_zero
al_copy:
    xor     %ecx, %ecx              # then the line laid in
al_cin:
    cmp     %r11, %rcx
    jae     al_len
    movzbl  (%r10, %rcx), %edx
    mov     %dl, (%rdi, %rcx)
    inc     %rcx
    jmp     al_cin
al_len:
    mov     %r11b, 0x300(%r15, %rax)
    inc     %rax
    mov     %rax, 0x18(%r15)
    ret

# ------------------------------------------------------------------
# compose_prompt: the composed line — "> " and the input —
# is built at 0x200; its length answers in rax.
# ------------------------------------------------------------------
compose_prompt:
    movb    $0x3E, 0x200(%r15)      # >
    movb    $0x20, 0x201(%r15)      # and a space
    xor     %ecx, %ecx
    mov     0x20(%r15), %rdx        # the input's length
cp_loop:
    cmp     %rdx, %rcx
    jae     cp_done
    movzbl  0x100(%r15, %rcx), %r9d
    mov     %r9b, 0x202(%r15, %rcx)
    inc     %rcx
    jmp     cp_loop
cp_done:
    mov     %rdx, %rax
    add     $2, %rax
    ret

# ------------------------------------------------------------------
# render_prompt: the input line's band repainted — the band
# wiped, the composed line drawn, and a small underline for
# a cursor at the line's end. The band's row is the one
# render_all last reckoned (the slot at 0x028).
# ------------------------------------------------------------------
render_prompt:
    mov     $48, %rsi
    mov     0x28(%r15), %rdx
    shl     $4, %rdx
    add     $96, %rdx               # the band's top
    mov     0x00(%r15), %rcx
    sub     $96, %rcx
    mov     $16, %r8
    mov     $0x201612, %r9          # the ground's ink
    call    fill
    call    compose_prompt          # rax: the composed length
    mov     %rax, %r10
    mov     $52, %rsi
    mov     0x28(%r15), %rdx
    shl     $4, %rdx
    add     $96, %rdx
    lea     0x200(%r15), %rcx
    mov     %r10, %r8
    mov     $0xF4EDDE, %r9          # parchment letters
    call    draw
    mov     %r10, %rsi              # the cursor: a short bar
    shl     $4, %rsi                # at the composed line's end
    add     $52, %rsi
    mov     0x28(%r15), %rdx
    shl     $4, %rdx
    add     $109, %rdx              # the band's foot, less three
    mov     $16, %rcx
    mov     $3, %r8
    mov     $0xF4EDDE, %r9
    call    fill
    ret

# ------------------------------------------------------------------
# render_all: the whole face repainted — the ground, the
# title bar and its name, the scrollback's visible tail, and
# the prompt beneath it. The visible tail: at most one less
# than the text rows, so the prompt always has its own row.
# ------------------------------------------------------------------
render_all:
    mov     $36, %rsi               # the ground
    mov     $36, %rdx
    mov     0x00(%r15), %rcx
    sub     $72, %rcx
    mov     0x08(%r15), %r8
    sub     $72, %r8
    mov     $0x201612, %r9
    call    fill
    mov     $36, %rsi               # the title bar
    mov     $36, %rdx
    mov     0x00(%r15), %rcx
    sub     $72, %rcx
    mov     $44, %r8
    mov     $0x7A1220, %r9          # cardinal
    call    fill
    mov     $52, %rsi               # its name
    mov     $50, %rdx
    lea     title(%rip), %rcx
    mov     $title_end - title, %r8
    mov     $0xFFFFFF, %r9
    call    draw
    mov     0x18(%r15), %r13        # the count
    mov     0x10(%r15), %r12        # the visible rows
    dec     %r12                    # less the prompt's own row
    mov     %r13, %rax              # shown = the lesser of
    cmp     %r12, %rax              # the count and the room
    cmova   %r12, %rax
    mov     %rax, 0x28(%r15)        # the lines shown, kept
    mov     %r13, %rbp
    sub     %rax, %rbp              # the first of them
    xor     %ebx, %ebx              # the row being painted
ra_line:
    cmp     0x28(%r15), %rbx
    jae     ra_prompt
    mov     %rbp, %rcx              # the record: start + row
    add     %rbx, %rcx
    movzbl  0x300(%r15, %rcx), %r10d    # its length
    mov     %rcx, %rax              # its place: record * 72
    shl     $6, %rax
    mov     %rcx, %rdx
    shl     $3, %rdx
    add     %rdx, %rax
    lea     0x400(%r15, %rax), %r11
    test    %r10, %r10
    je      ra_next                 # an empty line paints nothing
    mov     $52, %rsi
    mov     %rbx, %rdx
    shl     $4, %rdx
    add     $96, %rdx
    mov     %r11, %rcx
    mov     %r10, %r8
    mov     $0xF4EDDE, %r9
    call    draw
ra_next:
    inc     %rbx
    jmp     ra_line
ra_prompt:
    call    render_prompt
    ret

# ------------------------------------------------------------------
# cmd_is: rsi a command word's place, rdx its length. The
# answer is 1 when the input's first word — folded small,
# as the shell folds its own commands — is exactly that
# word, and 0 when it is anything else.
# ------------------------------------------------------------------
cmd_is:
    xor     %ecx, %ecx              # the input word's length:
    mov     0x20(%r15), %r8         # up to a space or the end
ci_wlen:
    cmp     %r8, %rcx
    jae     ci_have
    movzbl  0x100(%r15, %rcx), %r9d
    cmp     $0x20, %r9b
    je      ci_have
    inc     %rcx
    jmp     ci_wlen
ci_have:
    cmp     %rdx, %rcx
    jne     ci_no
    xor     %ecx, %ecx              # letter by letter, folded
ci_letter:
    cmp     %rdx, %rcx
    jae     ci_yes
    movzbl  0x100(%r15, %rcx), %r9d
    cmp     $0x41, %r9b
    jb      ci_cmp
    cmp     $0x5A, %r9b
    ja      ci_cmp
    add     $0x20, %r9b             # A ... Z -> a ... z
ci_cmp:
    cmp     (%rsi, %rcx), %r9b
    jne     ci_no
    inc     %rcx
    jmp     ci_letter
ci_yes:
    mov     $1, %rax
    ret
ci_no:
    xor     %eax, %eax
    ret

# ------------------------------------------------------------------
# submit_line: Enter was pressed. The line as typed joins
# the scrollback wearing its prompt, and then the line is
# answered — by leaving, by wiping, or by speaking — and
# the face is repainted whole.
# ------------------------------------------------------------------
submit_line:
    call    compose_prompt
    mov     %rax, %rdx
    lea     0x200(%r15), %rsi
    call    append_line             # the line, as it was typed
    lea     cmd_exit(%rip), %rsi
    mov     $4, %rdx
    call    cmd_is
    test    %rax, %rax
    jne     sl_exit
    lea     cmd_clear(%rip), %rsi
    mov     $5, %rdx
    call    cmd_is
    test    %rax, %rax
    jne     sl_clear
    lea     cmd_help(%rip), %rsi
    mov     $4, %rdx
    call    cmd_is
    test    %rax, %rax
    jne     sl_help
    lea     cmd_verse(%rip), %rsi
    mov     $5, %rdx
    call    cmd_is
    test    %rax, %rax
    jne     sl_verse
    lea     cmd_about(%rip), %rsi
    mov     $5, %rdx
    call    cmd_is
    test    %rax, %rax
    jne     sl_about
    lea     unk1(%rip), %rsi        # a word I do not know
    mov     $unk1_end - unk1, %rdx
    call    append_line
    lea     unk2(%rip), %rsi
    mov     $unk2_end - unk2, %rdx
    call    append_line
    jmp     sl_finish
sl_help:
    lea     help1(%rip), %rsi
    mov     $help1_end - help1, %rdx
    call    append_line
    lea     help2(%rip), %rsi
    mov     $help2_end - help2, %rdx
    call    append_line
    lea     help3(%rip), %rsi
    mov     $help3_end - help3, %rdx
    call    append_line
    lea     help4(%rip), %rsi
    mov     $help4_end - help4, %rdx
    call    append_line
    lea     help5(%rip), %rsi
    mov     $help5_end - help5, %rdx
    call    append_line
    lea     help6(%rip), %rsi
    mov     $help6_end - help6, %rdx
    call    append_line
    lea     help7(%rip), %rsi
    mov     $help7_end - help7, %rdx
    call    append_line
    lea     help8(%rip), %rsi
    mov     $help8_end - help8, %rdx
    call    append_line
    jmp     sl_finish
sl_verse:
    lea     verse1(%rip), %rsi
    mov     $verse1_end - verse1, %rdx
    call    append_line
    lea     verse2(%rip), %rsi
    mov     $verse2_end - verse2, %rdx
    call    append_line
    lea     verse3(%rip), %rsi
    mov     $verse3_end - verse3, %rdx
    call    append_line
    jmp     sl_finish
sl_about:
    lea     about1(%rip), %rsi
    mov     $about1_end - about1, %rdx
    call    append_line
    lea     about2(%rip), %rsi
    mov     $about2_end - about2, %rdx
    call    append_line
    lea     about3(%rip), %rsi
    mov     $about3_end - about3, %rdx
    call    append_line
    lea     about4(%rip), %rsi
    mov     $about4_end - about4, %rdx
    call    append_line
    jmp     sl_finish
sl_clear:
    movq    $0, 0x18(%r15)          # the scrollback wiped
    movq    $0, 0x20(%r15)          # the input with it
    call    render_all
    ret
sl_exit:
    mov     $0, %rdi                # a clean leaving
    mov     $0, %rax                # service 0: exit
    int     $0x80
    ret                             # the door never returns
sl_finish:
    movq    $0, 0x20(%r15)          # a fresh line
    call    render_all
    ret

1:
    hlt                             # the door never returns; see hello.s
    jmp     1b

title:
    .ascii  "Feather Terminal"
title_end:
boot1:
    .ascii  "A terminal that is a feather."
boot1_end:
boot2:
    .ascii  "I stand on the service door alone: I knock, and"
boot2_end:
boot3:
    .ascii  "the kernel draws; your keys reach me by the door."
boot3_end:
boot4:
    .ascii  "Type help."
boot4_end:
cmd_help:
    .ascii  "help"
cmd_clear:
    .ascii  "clear"
cmd_verse:
    .ascii  "verse"
cmd_about:
    .ascii  "about"
cmd_exit:
    .ascii  "exit"
help1:
    .ascii  "The words I know:"
help1_end:
help2:
    .ascii  "  help   this list"
help2_end:
help3:
    .ascii  "  verse  John 1:1, from my own pages"
help3_end:
help4:
    .ascii  "  about  what I am"
help4_end:
help5:
    .ascii  "  clear  wipe my screen clean"
help5_end:
help6:
    .ascii  "  exit   go back to the shell that called me"
help6_end:
help7:
    .ascii  "Esc is the user's key: pressed, it stops me and"
help7_end:
help8:
    .ascii  "gives the screen back. It never reaches me."
help8_end:
verse1:
    .ascii  "In the beginning was the Word, and the Word was with God, and"
verse1_end:
verse2:
    .ascii  "the Word was God."
verse2_end:
verse3:
    .ascii  "- John 1:1 (Douay-Rheims)"
verse3_end:
about1:
    .ascii  "I am the Feather Terminal: a terminal that is a"
about1_end:
about2:
    .ascii  "feather. I stand on the service door alone - the"
about2_end:
about3:
    .ascii  "kernel's shell is not helping me. Every letter on"
about3_end:
about4:
    .ascii  "this screen, I drew by knocking."
about4_end:
unk1:
    .ascii  "I do not know that word. Type help and I will"
unk1_end:
unk2:
    .ascii  "tell you the words I know."
unk2_end:
