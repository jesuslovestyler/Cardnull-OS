# Cardnull OS — the boot floor.
#
# This is the thin layer of assembly DESIGN.md allows: the handful of
# things Swift cannot do for itself. Its whole job:
#
#   1. Carry a Multiboot2 header so GRUB can load us.
#   2. Wake the processor GRUB hands us (32-bit protected mode) and walk
#      it into 64-bit long mode: page tables, PAE, the long-mode bit,
#      paging, a 64-bit GDT, and a far jump.
#   3. Set up a stack and call the Swift kernel's kmain.
#   4. Provide cardnull_halt, the hlt-loop the kernel rests in.
#
# Everything above this floor is Swift. Written by hand, in the open,
# in the public domain.

# ---------------------------------------------------------------------------
# Multiboot2 header.
#
# GRUB scans the first 32 KiB of the kernel file for this header, checks
# the checksum, loads the ELF, and jumps to our entry point (_start) in
# 32-bit protected mode with paging off. The linker script places this
# section first in the image so it sits near the front of the file.
# ---------------------------------------------------------------------------
    .section .multiboot_header, "a"
    .align 8
header_start:
    .long   0xe85250d6                          # Multiboot2 magic
    .long   0                                   # architecture: i386 (32-bit entry)
    .long   header_end - header_start           # header length
    .long   -(0xe85250d6 + (header_end - header_start))  # checksum: magic + arch + length + checksum == 0
    # End tag: type 0, no flags, size 8.
    .word   0
    .word   0
    .long   8
header_end:

# ---------------------------------------------------------------------------
# Entry point. GRUB lands here in 32-bit protected mode:
#   EAX = Multiboot2 magic, EBX = address of the Multiboot2 info structure.
# We do not read either yet — milestone 1 needs nothing from them — but
# they are preserved by the ABI if a later milestone wants them.
# ---------------------------------------------------------------------------
    .section .text
    .code32
    .globl  _start
_start:
    # Our own stack, before anything else.
    mov     $stack_top, %esp

    # --- Build the page tables (identity map of the first 1 GiB) --------
    # PML4[0] -> PDPT, PDPT[0] -> PD, and the PD holds 512 entries of
    # 2 MiB each. The kernel lives at 0x100000 and the VGA text buffer at
    # 0xB8000; both sit inside that first gigabyte.
    mov     $page_table_pd, %edi
    xor     %ecx, %ecx                          # entry index / running address
1:
    mov     %ecx, %eax
    shl     $21, %eax                           # address = index * 2 MiB
    or      $0x83, %eax                         # present | writable | huge page (PS)
    mov     %eax, (%edi, %ecx, 8)
    movl    $0, 4(%edi, %ecx, 8)                # high dword: no flags above 4 GiB
    inc     %ecx
    cmp     $512, %ecx
    jne     1b

    mov     $page_table_pd, %eax
    or      $0x3, %eax                          # present | writable
    mov     %eax, page_table_pdpt               # PDPT[0] -> PD
    mov     $page_table_pdpt, %eax
    or      $0x3, %eax
    mov     %eax, page_table_pml4               # PML4[0] -> PDPT

    # --- Walk into long mode --------------------------------------------
    mov     $page_table_pml4, %eax
    mov     %eax, %cr3                          # install the tables

    mov     %cr4, %eax
    or      $0x20, %eax                         # CR4.PAE
    mov     %eax, %cr4

    mov     $0xC0000080, %ecx                   # EFER MSR
    rdmsr
    or      $0x100, %eax                        # EFER.LME (long mode enable)
    wrmsr

    mov     %cr0, %eax
    or      $0x80000000, %eax                   # CR0.PG (paging on -> long mode)
    mov     %eax, %cr0

    lgdt    gdt64_pointer
    ljmp    $0x08, $long_mode_start             # far jump into the 64-bit code segment

# ---------------------------------------------------------------------------
# 64-bit entry. Land here with the long-mode code segment selected.
# ---------------------------------------------------------------------------
    .code64
long_mode_start:
    # Data segments: load the 64-bit data descriptor (selector 0x10).
    mov     $0x10, %ax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %fs
    mov     %ax, %gs
    mov     %ax, %ss

    # The stack pointer GRUB's mode left us is a 32-bit value zero-
    # extended; restate it cleanly before calling Swift.
    mov     $stack_top, %rsp

    # Wake the floating-point/SSE unit. Swift's compiler emits SSE
    # instructions (movaps and friends) for ordinary work like filling
    # the screen; until CR4.OSFXSR is set, the first one faults — and
    # with no IDT yet, a fault here ends the boot. This is part of
    # waking the processor, so it belongs to the floor.
    mov     %cr0, %rax
    and     $~0x4, %rax                         # CR0.EM clear: FPU present
    or      $0x2, %rax                          # CR0.MP set
    mov     %rax, %cr0
    mov     %cr4, %rax
    or      $0x600, %rax                        # CR4.OSFXSR | CR4.OSXMMEXCPT
    mov     %rax, %cr4

    # Hand over to Swift. kmain never returns; if it somehow did, rest.
    call    kmain
    jmp     cardnull_halt

# ---------------------------------------------------------------------------
# cardnull_halt — the kernel's rest. hlt stops the processor until the
# next interrupt; with none enabled yet, this is a clean, cool idle.
# Swift declares this as a -> Never function.
# ---------------------------------------------------------------------------
    .globl  cardnull_halt
cardnull_halt:
    hlt
    jmp     cardnull_halt

# ---------------------------------------------------------------------------
# The 64-bit GDT. Long mode mostly ignores segmentation, but the processor
# still requires descriptors that say "64-bit code lives here."
# ---------------------------------------------------------------------------
    .section .rodata
    .align 8
gdt64:
    .quad   0x0000000000000000                  # null descriptor
    .quad   0x00209A0000000000                  # 0x08: code — present, executable, long-mode (L) bit set
    .quad   0x0000920000000000                  # 0x10: data — present, writable
gdt64_pointer:
    .word   gdt64_pointer - gdt64 - 1           # limit
    .quad   gdt64                               # base

# ---------------------------------------------------------------------------
# Page tables and the kernel stack, in uninitialized memory (.bss).
# The tables must be 4 KiB-aligned; the linker keeps .bss page-aligned.
# ---------------------------------------------------------------------------
    .section .bss
    .align 4096
page_table_pml4:
    .skip   4096
page_table_pdpt:
    .skip   4096
page_table_pd:
    .skip   4096

    .align 16
stack_bottom:
    .skip   16384                               # 16 KiB of kernel stack
stack_top:
