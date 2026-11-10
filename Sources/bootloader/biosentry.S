# Cardnull OS — the BIOS second stage's assembly skin.
#
# Milestone 24. The second stage's mind is C (biosmain.c,
# compiled -m16); this file is everything C cannot do for
# itself down here:
#
#   - the entry hand: gathered by the boot sector at
#     0x7E00, it restates the machine plainly (segments
#     zero, the boot sector's stack), opens the A20 gate,
#     gathers the boot sector's leavings (the drive, the
#     sector multiplier, the sector size — left at
#     0x0500..0x0503) into the globals below, and calls
#     the C.
#   - the BIOS thunks: teletype, EDD packet read, the
#     E820 walk, the VESA calls — each taking its errand
#     from the globals and leaving its answer there, so
#     no calling convention stands between the C and the
#     interrupts. The caller is a perfectly conventional
#     real-mode program: every segment zero, every buffer
#     an honest segment:offset the BIOS can reckon.
#   - the two protected-mode hands, pm_copy and pm_zero:
#     the only road to memory past one mebibyte. Each
#     steps up alone — interrupts off, a small GDT of our
#     own, flat segments, one rep movsb or stosb — and
#     steps back down to the same real-mode room it left,
#     segments zero again. The BIOS never sees them.
#   - go_kernel: the handoff. It lays the same GDT's
#     32-bit furniture, steps into protected mode, seats
#     flat data segments and a scratch stack, puts the
#     Multiboot2 magic in EAX and the information's
#     address in EBX, and jumps to the kernel's entry —
#     the exact doorstep boot.S was written for, the same
#     one GRUB and the UEFI trampoline deliver.
#
# Written by hand, in the open, in the public domain.

    .code16gcc
    .section .text.entry, "ax"
    .globl _stage2_entry
_stage2_entry:
    cli
    xor     %ax, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %ss
    mov     $0x7C00, %sp
    sti

    # A20, by the fast gate at port 0x92: set bit 1, never
    # touch bit 0 (the reset line wears the same port).
    in      $0x92, %al
    test    $0x02, %al
    jnz     1f
    or      $0x02, %al
    and     $0xFE, %al
    out     %al, $0x92
1:
    # The boot sector's leavings, into the globals.
    mov     0x0500, %al
    mov     %al, g_drive
    mov     0x0501, %al
    mov     %al, g_mult
    mov     0x0502, %ax
    mov     %ax, g_sect_size

    call    stage2_main
    # The C returns only if something above it failed to
    # be final; rest rather than wander.
    cli
2:  hlt
    jmp     2b

# ---------------------------------------------------------------------------
# The globals the thunks run on. The C declares them extern
# and fills/reads them; nothing crosses in registers, so the
# 16-bit C ABI is never asked a question it answers oddly.
# ---------------------------------------------------------------------------
    .section .data
    .globl g_drive, g_mult, g_sect_size
g_drive:     .byte 0
g_mult:      .byte 0
    .align 2
g_sect_size: .word 0

    .globl g_char
g_char:      .byte 0

    .globl g_status, g_carry
g_status:    .byte 0
g_carry:     .byte 0

    # The EDD packet, filled by the C: size, count, buffer
    # offset and segment, the LBA's two halves.
    .globl g_dap
    .align 2
g_dap:       .fill 16, 1, 0

    # E820 in/out: the continuation in EBX, the entry's
    # place (an offset under segment zero).
    .globl g_e820_cont, g_e820_di, g_e820_len
    .align 4
g_e820_cont: .long 0
g_e820_di:   .long 0
g_e820_len:  .long 0

    # VESA in/out: the call's AX/BX/CX and its ES:DI place.
    .globl g_vbe_ax, g_vbe_bx, g_vbe_cx, g_vbe_di
    .align 2
g_vbe_ax:    .word 0
g_vbe_bx:    .word 0
g_vbe_cx:    .word 0
    .align 4
g_vbe_di:    .long 0

    # The protected-mode hands' errands.
    .globl g_copy_src, g_copy_dst, g_copy_len, g_zero_dst, g_zero_len
    .align 4
g_copy_src:  .long 0
g_copy_dst:  .long 0
g_copy_len:  .long 0
g_zero_dst:  .long 0
g_zero_len:  .long 0

    # The handoff's errand: the kernel's entry point.
    .globl g_entry
    .align 4
g_entry:     .long 0

# ---------------------------------------------------------------------------
# The thunks.
# ---------------------------------------------------------------------------
    .code16gcc
    .section .text

# Teletype: prints g_char through int 10h AH=0Eh.
    .globl bios_putch
bios_putch:
    push    %ax
    push    %bx
    mov     g_char, %al
    mov     $0x0E, %ah
    mov     $0x0007, %bx
    int     $0x10
    pop     %bx
    pop     %ax
    ret

# EDD packet read: the packet stands at g_dap, the drive
# at g_drive. g_status takes the BIOS's own AH; g_carry
# takes the carry flag, the read's true verdict.
    .globl bios_edd_read
bios_edd_read:
    push    %ax
    push    %dx
    push    %si
    mov     $g_dap, %si
    mov     g_drive, %dl
    mov     $0x42, %ah
    int     $0x13
    mov     %ah, g_status
    setc    g_carry
    pop     %si
    pop     %dx
    pop     %ax
    ret

# One E820 step: EBX rides in and out at g_e820_cont, the
# entry lands at segment zero : g_e820_di, its length at
# g_e820_len; the signature lands in EAX, checked by the C.
    .globl bios_e820
bios_e820:
    push    %eax
    push    %ebx
    push    %ecx
    push    %edx
    push    %edi
    mov     g_e820_cont, %ebx
    mov     g_e820_di, %edi
    mov     $24, %ecx
    mov     $0x534D4150, %edx       # "SMAP"
    mov     $0xE820, %eax
    int     $0x15
    setc    g_carry
    mov     %ebx, g_e820_cont
    mov     %ecx, g_e820_len
    mov     %eax, g_e820_sig
    pop     %edi
    pop     %edx
    pop     %ecx
    pop     %ebx
    pop     %eax
    ret

    .section .data
    .globl g_e820_sig
    .align 4
g_e820_sig:  .long 0
    .section .text

# One VESA call: AX/BX/CX in at their globals, ES:DI the
# buffer (segment zero, the offset at g_vbe_di); AX's
# answer returns to g_vbe_ax.
    .globl bios_vbe
bios_vbe:
    push    %ax
    push    %bx
    push    %cx
    push    %edi
    mov     g_vbe_di, %edi
    mov     g_vbe_ax, %ax
    mov     g_vbe_bx, %bx
    mov     g_vbe_cx, %cx
    int     $0x10
    mov     %ax, g_vbe_ax
    pop     %edi
    pop     %cx
    pop     %bx
    pop     %ax
    ret

# ---------------------------------------------------------------------------
# The protected-mode hands.
#
# One GDT serves both, and the handoff below: a flat
# 32-bit code segment, a flat 32-bit data segment, and a
# 16-bit code segment for the step back down. The hands
# run with interrupts off throughout; the step down
# reloads every segment to zero before interrupts return,
# so nothing of the excursion leaks into the BIOS's view.
# ---------------------------------------------------------------------------
    .section .data
    .align 8
gdt:
    .quad   0x0000000000000000      # 0x00: the null
    .quad   0x00CF9A000000FFFF      # 0x08: flat 32-bit code
    .quad   0x00CF92000000FFFF      # 0x10: flat 32-bit data
    .quad   0x000F9A000000FFFF      # 0x18: 16-bit code, 64 KiB
gdt_end:
gdt_ptr:
    .word   gdt_end - gdt - 1
    .long   gdt

# pm_copy: g_copy_src -> g_copy_dst, g_copy_len bytes,
# anywhere in the first 4 GiB.
    .section .text
    .globl pm_copy
pm_copy:
    pushf
    cli
    push    %eax
    push    %esi
    push    %edi
    push    %ecx
    lgdt    gdt_ptr
    mov     %cr0, %eax
    or      $0x01, %eax
    mov     %eax, %cr0
    ljmp    $0x08, $pm_copy_32
    .code32
pm_copy_32:
    mov     $0x10, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     g_copy_src, %esi
    mov     g_copy_dst, %edi
    mov     g_copy_len, %ecx
    rep     movsb
    ljmp    $0x18, $pm_copy_16
    .code16gcc
pm_copy_16:
    mov     %cr0, %eax
    and     $~0x01, %eax
    mov     %eax, %cr0
    ljmp    $0x0000, $pm_copy_home
pm_copy_home:
    xor     %ax, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %ss
    pop     %ecx
    pop     %edi
    pop     %esi
    pop     %eax
    popf
    ret

# pm_zero: g_zero_len zeros at g_zero_dst.
    .globl pm_zero
pm_zero:
    pushf
    cli
    push    %eax
    push    %edi
    push    %ecx
    lgdt    gdt_ptr
    mov     %cr0, %eax
    or      $0x01, %eax
    mov     %eax, %cr0
    ljmp    $0x08, $pm_zero_32
    .code32
pm_zero_32:
    mov     $0x10, %ax
    mov     %ax, %ds
    mov     %ax, %es
    xor     %eax, %eax
    mov     g_zero_dst, %edi
    mov     g_zero_len, %ecx
    rep     stosb
    ljmp    $0x18, $pm_zero_16
    .code16gcc
pm_zero_16:
    mov     %cr0, %eax
    and     $~0x01, %eax
    mov     %eax, %cr0
    ljmp    $0x0000, $pm_zero_home
pm_zero_home:
    xor     %ax, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %ss
    pop     %ecx
    pop     %edi
    pop     %eax
    popf
    ret

# ---------------------------------------------------------------------------
# go_kernel(info): the handoff. Called with the Multiboot2
# information's address as its argument — read off the
# stack in the 16-bit ABI (a 32-bit return address stands
# below it), kept in EBX across the mode change, and the
# kernel's entry at g_entry. Never returns.
# ---------------------------------------------------------------------------
    .globl go_kernel
go_kernel:
    mov     4(%esp), %ebx           # EBX: the information
    cli
    lgdt    gdt_ptr
    mov     %cr0, %eax
    or      $0x01, %eax
    mov     %eax, %cr0
    ljmp    $0x08, $go_kernel_32
    .code32
go_kernel_32:
    mov     $0x10, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %ss
    mov     %ax, %fs
    mov     %ax, %gs
    mov     $0x90000, %esp          # a scratch stack
    mov     $0x36D76289, %eax       # the Multiboot2 magic
    jmp     *g_entry                # _start — no return
    .code16gcc
