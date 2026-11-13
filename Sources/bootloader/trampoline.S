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
 *      in R8 (EDI is wanted for the copying in step 3
 *      and takes the entry back before the stairs),
 *      registers the tail disturbs neither;
 *   2. lays down a small GDT of our own — a flat 32-bit
 *      code segment and a flat 32-bit data segment, the
 *      same plain furniture GRUB's doorstep offered;
 *   3. copies the 32-bit tail to low memory at 0x8F000
 *      and steps into the 32-bit code segment there (a
 *      return-far into compatibility mode), loads the
 *      data segments — the tail runs low because the
 *      moment it turns paging off, the processor's own
 *      address is 32 bits wide, and this image may be
 *      standing above the 4 GiB line;
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
 * touches was arranged above the stairs. That is also
 * what lets it travel: copied byte for byte to low
 * memory, it stands exactly as it stood, because
 * nothing in it names the place it stands.
 *
 * Written by hand, in the open, in the public domain.
 */

    .text
    .code64
    .globl  cardnull_enter_kernel
cardnull_enter_kernel:
    cli
    movl    %ecx, %ebx          # EBX: the Multiboot2 information
    movl    %edx, %r8d          # R8: the kernel's entry point,
                                # kept aside while EDI works

    # The step down runs from a copy of itself laid in
    # low memory, and the copy is made here, while the
    # machine is still 64-bit and can name any address
    # it pleases. The reason is the tail's own trade:
    # its middle act turns paging off, and a processor
    # with paging off holds a 32-bit address — it can
    # only stand below 4 GiB. This image links at
    # 0x140000000, and on a machine whose RAM crosses
    # that line the firmware may stand it at its linked
    # home; a tail running from there is cut off at its
    # own waist the moment paging goes, and lands at
    # its address's low half, in whatever happens to
    # lie there. (Found November 13, 2026, in the same
    # witness that found the GDT store below: with that
    # store repaired the machine stopped resetting and
    # instead went silent at the handover, marching up
    # through empty memory from 0x4003152 — the tail's
    # own address with its high half gone.) The low
    # room is chosen clear of everything: above the
    # firmware's low data, below the kernel's home at
    # 1 MiB, and below the scratch stack the tail takes
    # at 0x90000, which grows down away from it. The
    # GDT needs no copy: every reading of it happens
    # while paging still stands, and the tail loads
    # its segments before it touches the switch.
    leaq    cardnull_step_down(%rip), %rsi
    movl    $0x0008F000, %edi   # the low room
    movl    $(cardnull_step_down_end - cardnull_step_down), %ecx
    cld
    rep     movsb

    # Our GDT's address is known only at runtime — the
    # firmware chose where to stand this image — so reckon
    # it here and lay it in the pointer before loading it.
    # The store names its target the same RIP-relative way
    # as its neighbours, and the naming is load-bearing:
    # written without (%rip), the assembler lays down a
    # 32-bit absolute address instead. This image links at
    # 0x140000000, so the 32-bit form truncates the GDT
    # pointer's address (0x14000501A became 0x4000501A),
    # and the firmware's 32-bit relocation only makes the
    # sum come right again while the image actually stands
    # below 4 GiB. On a machine with RAM past that line
    # the firmware may stand the image at its linked home
    # above it; then the store lands a gigabyte low, in
    # innocent memory, the pointer keeps the zero base it
    # was assembled with, and the return-far below faults
    # on a GDT that is not there — the machine resets
    # before the kernel ever wakes. (Found November 13,
    # 2026, on Tyler's UTM at 4096 MB: every disc since
    # this loader's first day carried it, and every bench
    # boot at 512 MB stood below the line and never knew.)
    leaq    cardnull_gdt(%rip), %rax
    movq    %rax, cardnull_gdt_pointer + 2(%rip)
    lgdt    cardnull_gdt_pointer(%rip)

    movl    %r8d, %edi          # EDI: the kernel's entry point

    # A return-far into the 32-bit code segment — into
    # the low copy of the step down: the processor lands
    # in compatibility mode, still with paging on, where
    # the step down can be finished by hand.
    pushq   $0x08               # the 32-bit code segment
    pushq   $0x0008F000         # the low copy's first step
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
cardnull_step_down_end:

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
