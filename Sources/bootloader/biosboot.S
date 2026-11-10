# Cardnull OS — the BIOS door's first hand: our boot sector.
#
# Milestone 24: the last borrowed piece leaves. Behind the
# BIOS door, GRUB has loaded our kernel since the first
# milestone; this sector and the second stage beside it
# (biosentry.S, biosmain.c) take its place, in the public
# domain like everything else in Cardnull.
#
# This sector is 512 bytes and lives twice in every image:
#
#   - as the El Torito boot image file /BOOT/BIOSBOOT.IMG,
#     whose first 2 KiB the BIOS loads at 0x7C00 when the
#     machine boots the CD (the image build asks xorriso
#     for El Torito's boot info table, which patches this
#     sector's table at bytes 8..63 with the file's own
#     place on the disc);
#   - as the image's master boot record, written there by
#     the build's own patcher (tools/patch-mbr.py) over the
#     protective MBR xorriso lays down, keeping xorriso's
#     partition table and signature untouched — so a stick
#     carrying the image boots the very same bytes through
#     the MBR door, with the table carrying the same file
#     place the patcher wrote from the finished disc.
#
# Either way the work is one: learn the drive the BIOS
# booted (DL, its gift), learn the drive's sector size
# (EDD's own word, so a 2048-byte CD sector and a 512-byte
# stick sector are the same road at different widths),
# read the whole boot image — this sector and the second
# stage behind it — off the disc in 16 KiB mouthfuls by
# EDD packet reads, and step into the second stage at
# 0x7E00. What it cannot do, it says in plain words on the
# text screen and rests: no EDD, no boot table, a failed
# read — each named, none silent.
#
# The boot drive, the sector-size multiplier, and the
# sector size itself are left at 0x0500..0x0503 for the
# second stage's entry hand to gather.
#
# Written by hand, in the open, in the public domain.

    .code16
    .section .text
    .globl _bios_boot
_bios_boot:
    jmp     boot_main               # bytes 0..1
    .byte   0x90                    # byte 2
    .fill   5, 1, 0                 # bytes 3..7
    # The El Torito boot information table (bytes 8..63),
    # zeros here: in the image file, xorriso patches the
    # disc's primary volume descriptor place (offset 8),
    # this file's place (offset 12), and its length in
    # bytes (offset 16); in the MBR copy, the build's
    # patcher writes the same two facts from the finished
    # disc. The sector reads only those two fields.
    .fill   56, 1, 0

boot_main:
    cli
    xor     %ax, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %ss
    mov     $0x7C00, %sp
    sti

    mov     %dl, 0x0500             # the boot drive, kept

    # --- The drive's sector size (int 13h AH=48h) --------
    # The parameter block's size word first: 0x1E is the
    # smallest confession that carries the bytes-per-sector
    # word at its offset 24. A drive that will not answer
    # is treated as a CD — 2048 bytes to a sector — the
    # door this chain was first built for.
    mov     $0x0504, %si
    movw    $0x001E, (%si)
    movw    $0x0000, 2(%si)
    mov     $0x48, %ah
    int     $0x13
    jc      assume_cd
    mov     0x0504 + 24, %ax        # bytes per sector
    cmp     $512, %ax
    je      size_512
    cmp     $2048, %ax
    je      size_2048
assume_cd:
    mov     $2048, %ax
size_2048:
    movb    $1, 0x0501              # one drive sector
    jmp     size_kept               # to an ISO sector
size_512:
    movb    $4, 0x0501              # four
size_kept:
    mov     %ax, 0x0502             # the size itself

    # --- EDD present? (int 13h AH=41h) -------------------
    mov     $0x55AA, %bx
    mov     $0x41, %ah
    mov     0x0500, %dl
    int     $0x13
    jc      fail_edd
    cmp     $0xAA55, %bx
    jne     fail_edd
    test    $0x01, %cx              # packet reads offered?
    jz      fail_edd

    # --- The table's word: where the image lives ---------
    mov     0x7C0C, %eax            # the file's ISO sector
    test    %eax, %eax
    jz      fail_table
    mov     0x7C10, %ecx            # its length in bytes
    test    %ecx, %ecx
    jz      fail_table

    # Drive sectors for the whole: the length reckoned in
    # ISO sectors first ((bytes + 2047) / 2048), then at
    # the drive's own width. The running LBA walks at the
    # drive's width too.
    add     $2047, %ecx
    shr     $11, %ecx               # ISO sectors, whole
    movzbl  0x0501, %edx            # the multiplier
    imul    %edx, %ecx              # drive sectors, whole
    imul    %edx, %eax              # first drive LBA

    # Load in 16 KiB mouthfuls into 0x7C00 onward: the
    # buffer segment steps 0x400 paragraphs a mouthful.
    mov     $0x07C0, %bx            # buffer segment
load_loop:
    test    %ecx, %ecx
    jz      load_done
    # This mouthful: the smaller of what is left and one
    # 16 KiB span at the drive's width (sectors = 16384 /
    # size, reckoned through the multiplier: 8 * mult).
    mov     %ecx, %edx
    movzbl  0x0501, %esi
    shl     $3, %esi                # 8 * mult
    cmp     %esi, %edx
    jbe     1f
    mov     %esi, %edx
1:
    # The packet, at 0x0520.
    mov     $0x0520, %si
    movb    $0x10, (%si)            # packet size
    movb    $0x00, 1(%si)
    mov     %dx, 2(%si)             # sectors this mouthful
    movw    $0x0000, 4(%si)         # buffer offset
    mov     %bx, 6(%si)             # buffer segment
    mov     %eax, 8(%si)            # LBA, low
    movl    $0x00000000, 12(%si)    # LBA, high

    push    %eax
    push    %ecx
    push    %edx
    mov     0x0500, %dl
    mov     $0x42, %ah
    int     $0x13
    jc      fail_read
    pop     %edx
    pop     %ecx
    pop     %eax

    add     %edx, %eax              # the LBA walks
    sub     %edx, %ecx              # what is left shrinks
    add     $0x400, %bx             # the buffer steps
    jmp     load_loop
load_done:
    ljmp    $0x0000, $0x7E00        # the second stage

# --- Plain words, then rest --------------------------------
fail_edd:
    mov     $msg_edd, %si
    jmp     fail_say
fail_table:
    mov     $msg_table, %si
    jmp     fail_say
fail_read:
    mov     $msg_read, %si
fail_say:
    # The three failures share a frame — "Cardnull boot:
    # ", the failure's own words, " The machine rests." —
    # spoken in three breaths, because one sector's
    # ground will not hold the frame three times whole.
    push    %si
    mov     $msg_pre, %si
    call    say
    pop     %si
    call    say
    mov     $msg_suf, %si
    call    say
    cli
1:  hlt
    jmp     1b

# Prints the NUL-ended words at DS:SI on the text screen,
# the BIOS's own teletype (int 10h AH=0Eh).
say:
    lodsb
    test    %al, %al
    jz      2f
    mov     $0x0E, %ah
    mov     $0x0007, %bx
    int     $0x10
    jmp     say
2:  ret

msg_pre:
    .asciz  "Cardnull boot: "
msg_edd:
    .asciz  "this drive offers no packet reads (EDD)."
msg_table:
    .asciz  "the boot table is empty."
msg_read:
    .asciz  "reading the boot image failed."
msg_suf:
    .asciz  " The machine rests.\r\n"

    # Pad to the signature: code and words must end by
    # byte 446, where an MBR's partition table would sit —
    # the table's own ground is left for xorriso's hand
    # and the patcher's keeping.
    .fill   510 - (. - _bios_boot), 1, 0
    .word   0xAA55
