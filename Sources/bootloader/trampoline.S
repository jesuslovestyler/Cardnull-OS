/* Cardnull OS — the bootloader's step down.
 *
 * Part of milestone 22: our own bootloader. The kernel's
 * boot floor (Sources/boot/boot.S) was written for the
 * door Multiboot2 promises: a processor standing in
 * 32-bit protected mode, paging off, EAX holding the
 * Multiboot2 magic and EBX the address of the information
 * structure, on flat segments GRUB laid down. GRUB walks
 * down to that doorstep from its own keeping; behind the
 * UEFI door, somebody must walk down from the firmware's
 * very different room — 64-bit long mode, paging on, the
 * firmware's own tables — and that somebody is this file.
 *
 * One hand lives here: cardnull_enter_kernel(info, entry),
 * called from the loader's C once ExitBootServices has
 * succeeded, never returning. It:
 *
 *   1. quiets interrupts and keeps the two gifts — the
 *      information's address in EBX, the kernel's entry
 *      in EDI, registers nothing below disturbs;
 *   2. lays down a small GDT of our own — a flat 32-bit
 *      code segment and a flat 32-bit data segment, the
 *      same plain furniture GRUB's doorstep offered;
 *   3. steps into the 32-bit code segment (a return-far
 *      into compatibility mode), loads the data segments;
 *   4. turns paging off, then long mode off at its own
 *      switch (EFER.LME), then the page-address extension
 *      off — the machine descending its stairs in order,
 *      until it stands in plain protected mode;
 *   5. sets a scratch stack in the low memory the map
 *      calls free (the kernel's first act is to take its
 *      own stack, so this one is barely stood on), sets
 *      EAX to the Multiboot2 magic, and jumps to the
 *      kernel's entry with EBX still holding the word.
 *
 * The 32-bit tail speaks in constants and registers only:
 * down there a program has no easy way to name its own
 * relocated addresses, and it needs none — every value it
 * touches was arranged above the stairs.
 *
 * Written by hand, in the open, in the public domain.
 */

    .text
    .code64
    .globl  cardnull_enter_kernel
cardnull_enter_kernel:
    cli
    movl    %ecx, %ebx          # EBX: the Multiboot2 information
    movl    %edx, %edi          # EDI: the kernel's entry point

    # Our GDT's address is known only at runtime — the
    # firmware chose where to stand this image — so reckon
    # it here and lay it in the pointer before loading it.
    leaq    cardnull_gdt(%rip), %rax
    movq    %rax, cardnull_gdt_pointer + 2
    lgdt    cardnull_gdt_pointer(%rip)

    # A return-far into the 32-bit code segment: the
    # processor lands in compatibility mode, still with
    # paging on, where the step down can be finished by
    # hand.
    leaq    cardnull_step_down(%rip), %rax
    pushq   $0x08               # the 32-bit code segment
    pushq   %rax
    lretq

    .code32
cardnull_step_down:
    movw    $0x10, %ax          # the 32-bit data segment
    movw    %ax, %ds
    movw    %ax, %es
    movw    %ax, %ss
    movw    %ax, %fs
    movw    %ax, %gs

    movl    %cr0, %eax
    andl    $~0x80010000, %eax  # CR0.PG off, CR0.WP off
    movl    %eax, %cr0          # paging off: protected mode

    movl    $0xC0000080, %ecx   # EFER
    rdmsr
    andl    $~0x100, %eax       # EFER.LME off
    wrmsr

    movl    %cr4, %eax
    andl    $~0x20, %eax        # CR4.PAE off
    movl    %eax, %cr4

    movl    $0x90000, %esp      # a scratch stack, briefly
    movl    $0x36d76289, %eax   # the Multiboot2 magic
    jmp     *%edi               # _start — and no return

    .data
    .balign 8
cardnull_gdt:
    .quad   0x0000000000000000  # the null descriptor
    .quad   0x00CF9A000000FFFF  # 0x08: flat 32-bit code
    .quad   0x00CF92000000FFFF  # 0x10: flat 32-bit data
cardnull_gdt_end:
cardnull_gdt_pointer:
    .word   cardnull_gdt_end - cardnull_gdt - 1
    .quad   0                   # base, laid in at runtime
