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
#   5. Carry the interrupt stubs (milestone 4): one door per exception
#      vector, one per hardware IRQ the kernel takes, and the table of
#      their addresses the IDT is built from. Milestone 7 gives the
#      page fault (vector 14) a hand-written door of its own, below,
#      which carries the faulting address and error code up to Swift.
#   7. Carry milestone 9's program machinery: two user segments and
#      an empty TSS slot in the GDT (support.c fills the slot and
#      loads the register while the floor's own map still stands),
#      the service-door stub behind vector 0x80, and the two hands
#      that move the machine between the shell and a guest —
#      cardnull_launch_program going out, and the door's exit path
#      and cardnull_abandon_program coming home.
#   6. Keep the bootloader's word (milestone 5): the Multiboot2 header
#      asks for a linear framebuffer — the UEFI door has no text grid
#      to write in, only pixels — and the entry stub preserves EBX,
#      the Multiboot2 information pointer, and hands it to `kmain`,
#      so the kernel can read where the screen actually lives.
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
    # Framebuffer tag (type 5, milestone 5): ask for a linear
    # framebuffer. Under UEFI the firmware's graphics protocol is
    # the only screen there is; under BIOS, GRUB answers with a VBE
    # mode. The mode is deliberately unpreferred — width, height,
    # and depth all zero — because a bootloader that must match an
    # exact mode can fail to find one (UEFI GRUB, asked for
    # 1024x768x32 by name, answered "no suitable video mode found"
    # on a machine whose graphics offered other modes only). Any
    # direct-color mode it can set is welcome; the kernel reads the
    # mode it actually got from the framebuffer tag of the
    # information structure — the tag, not the request, is believed.
    # Flags 0: a framebuffer itself is not optional.
    .align 8
    .word   5                                   # type: framebuffer
    .word   0                                   # flags: none (required)
    .long   20                                  # size of this tag
    .long   0                                   # width: no preference
    .long   0                                   # height: no preference
    .long   0                                   # depth: no preference
    # End tag: type 0, no flags, size 8.
    .align 8
    .word   0
    .word   0
    .long   8
header_end:

# ---------------------------------------------------------------------------
# Entry point. GRUB lands here in 32-bit protected mode:
#   EAX = Multiboot2 magic, EBX = address of the Multiboot2 info structure.
# EAX's magic we have never needed; EBX is kept from this milestone
# on — the information structure carries the framebuffer tag that
# says where the screen lives, and the kernel reads it.
# ---------------------------------------------------------------------------
    .section .text
    .code32
    .globl  _start
_start:
    # Keep the bootloader's word before anything can clobber EBX:
    # one absolute store into a .bss slot, read back in long mode
    # and handed to kmain as its argument.
    mov     %ebx, cardnull_multiboot_info

    # Our own stack, before anything else.
    mov     $stack_top, %esp

    # --- Build the page tables (identity map of the first 4 GiB) ------
    # PML4[0] -> PDPT, PDPT[0..3] -> four PDs, and each PD holds 512
    # entries of 2 MiB: 4 GiB of the world, mapped as itself. The
    # kernel lives at 0x100000 and the VGA text buffer at 0xB8000,
    # both in the first gigabyte; the framebuffer GRUB parks in PCI
    # space — near 0x80000000 on the machines we run on — sits in the
    # second, and the wider map keeps both doors' screens reachable.
    mov     $page_table_pd, %edi
    xor     %ecx, %ecx                          # entry index / running address
1:
    mov     %ecx, %eax
    shl     $21, %eax                           # address = index * 2 MiB
    or      $0x83, %eax                         # present | writable | huge page (PS)
    mov     %eax, (%edi, %ecx, 8)
    movl    $0, 4(%edi, %ecx, 8)                # high dword: no flags above 4 GiB
    inc     %ecx
    cmp     $2048, %ecx
    jne     1b

    mov     $page_table_pd, %eax
    or      $0x3, %eax                          # present | writable
    mov     %eax, page_table_pdpt               # PDPT[0] -> PD #0 (0 .. 1 GiB)
    mov     $page_table_pd + 4096, %eax
    or      $0x3, %eax
    mov     %eax, page_table_pdpt + 8           # PDPT[1] -> PD #1 (1 .. 2 GiB)
    mov     $page_table_pd + 8192, %eax
    or      $0x3, %eax
    mov     %eax, page_table_pdpt + 16          # PDPT[2] -> PD #2 (2 .. 3 GiB)
    mov     $page_table_pd + 12288, %eax
    or      $0x3, %eax
    mov     %eax, page_table_pdpt + 24          # PDPT[3] -> PD #3 (3 .. 4 GiB)
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

    # Hand over to Swift. The Multiboot2 information address rides
    # in RDI, the ABI's first argument: where the bootloader left
    # its word about the machine — above all, the framebuffer tag.
    # kmain never returns; if it somehow did, rest.
    mov     $cardnull_multiboot_info, %rax
    mov     (%rax), %edi
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
# Interrupt stubs (milestone 4).
#
# The processor speaks to the kernel through gates in the IDT, and
# every gate lands on one of these stubs — the floor's half of every
# interrupt. What a stub may do is narrow: exceptions go to a Swift
# handler that speaks once and halts; the two hardware IRQs we take
# (timer, keyboard) save every register, call their Swift handler, and
# return through iretq as if nothing had happened. The IDT itself is
# built in support.c from cardnull_stub_table, below.
#
# Exception stubs: some vectors arrive with a CPU-pushed error code,
# some do not. The ones that do not get a dummy 0 pushed here, so
# every frame has the same shape: [ error code ][ vector ] <- rsp.
# ---------------------------------------------------------------------------

# Save / restore every general-purpose register around an IRQ handler.
.macro PUSH_ALL
    push    %rax
    push    %rbx
    push    %rcx
    push    %rdx
    push    %rsi
    push    %rdi
    push    %rbp
    push    %r8
    push    %r9
    push    %r10
    push    %r11
    push    %r12
    push    %r13
    push    %r14
    push    %r15
.endm

.macro POP_ALL
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %r11
    pop     %r10
    pop     %r9
    pop     %r8
    pop     %rbp
    pop     %rdi
    pop     %rsi
    pop     %rdx
    pop     %rcx
    pop     %rbx
    pop     %rax
.endm

# IRQ0 — the timer. Fires 100 times a second; the Swift handler counts
# the tick and thanks the PIC. The one pad: the interrupt frame (40
# bytes) plus fifteen pushes leave rsp eight bytes off the ABI's call
# alignment on the idle path, so one slot is padded before the call.
    .globl  cardnull_irq0_stub
cardnull_irq0_stub:
    PUSH_ALL
    cld
    sub     $8, %rsp
    call    cardnull_timer_interrupt
    add     $8, %rsp
    POP_ALL
    iretq

# IRQ1 — the keyboard. The Swift handler takes the scancode out of
# the controller and into the kernel's ring buffer; the shell reads
# it later, at its leisure.
    .globl  cardnull_irq1_stub
cardnull_irq1_stub:
    PUSH_ALL
    cld
    sub     $8, %rsp
    call    cardnull_keyboard_interrupt
    add     $8, %rsp
    POP_ALL
    iretq

# The exceptions share one door: the vector number is the Swift
# handler's argument, and the handler never returns — it prints one
# plain sentence and halts. A clean, aligned stack is all it needs.
exception_common:
    mov     (%rsp), %rdi                        # the vector number
    and     $-16, %rsp                          # a fresh, aligned stack
    call    cardnull_exception_handler
    jmp     cardnull_halt                       # unreachable, by contract

# One stub per exception vector. The second argument says whether the
# processor itself pushes an error code for this vector (the Intel
# list: 8, 10, 11, 12, 13, 14, 17, 21, 30); the others get the dummy.
.macro EXCEPTION_STUB num, has_error
    .globl  cardnull_isr\num
cardnull_isr\num:
    .if \has_error == 0
    push    $0                                  # dummy error code
    .endif
    push    $\num                               # the vector number
    jmp     exception_common
.endm

    EXCEPTION_STUB 0, 0
    EXCEPTION_STUB 1, 0
    EXCEPTION_STUB 2, 0
    EXCEPTION_STUB 3, 0
    EXCEPTION_STUB 4, 0
    EXCEPTION_STUB 5, 0
    EXCEPTION_STUB 6, 0
    EXCEPTION_STUB 7, 0
    EXCEPTION_STUB 8, 1
    EXCEPTION_STUB 9, 0
    EXCEPTION_STUB 10, 1
    EXCEPTION_STUB 11, 1
    EXCEPTION_STUB 12, 1
    EXCEPTION_STUB 13, 1
    # Vector 14 (page fault) is hand-written below, not macro-born:
    # it owes the kernel two facts the shared door cannot carry.
    EXCEPTION_STUB 15, 0
    EXCEPTION_STUB 16, 0
    EXCEPTION_STUB 17, 1
    EXCEPTION_STUB 18, 0
    EXCEPTION_STUB 19, 0
    EXCEPTION_STUB 20, 0
    EXCEPTION_STUB 21, 1
    EXCEPTION_STUB 22, 0
    EXCEPTION_STUB 23, 0
    EXCEPTION_STUB 24, 0
    EXCEPTION_STUB 25, 0
    EXCEPTION_STUB 26, 0
    EXCEPTION_STUB 27, 0
    EXCEPTION_STUB 28, 0
    EXCEPTION_STUB 29, 0
    EXCEPTION_STUB 30, 1
    EXCEPTION_STUB 31, 0

# Vector 14 — the page fault (milestone 7). Until now a bad address
# died like every other exception, one plain sentence and no facts.
# Paging of our own makes the fault worth hearing out: the processor
# keeps the address that was reached for in CR2 and a small testimony
# of the reaching in the error code it pushes, and both belong to the
# kernel's report. So this stub is written by hand: it takes the
# the error code off the frame the processor built ([ error code ][ RIP ]
# [ CS ] [ RFLAGS ] ...) and CR2 out of the processor, and hands the
# pair to Swift in the ABI's first two argument registers. The
# handler never returns — it reports and halts — so the stack is
# simply aligned for the call, as the shared door above does.
    .globl  cardnull_isr14
cardnull_isr14:
    mov     (%rsp), %rdi                        # the error code the CPU pushed
    mov     %cr2, %rsi                          # the address that was reached for
    and     $-16, %rsp                          # a fresh, aligned stack
    call    cardnull_page_fault_handler
    jmp     cardnull_halt                       # unreachable, by contract

# ---------------------------------------------------------------------------
# Milestone 9: the door between the kernel and its guests.
#
# A guest runs in ring 3, on page tables of its own (built in Swift),
# and speaks to the kernel through one software interrupt, 0x80 —
# the only IDT gate whose descriptor lets ring 3 knock (support.c
# stamps it DPL 3; every other gate stays shut to guests). On entry
# the processor has already changed stacks, to the TSS's ring-0
# stack in support.c, and pushed the guest's frame.
#
# The guest's side of the door (written out in programs/hello.s):
# rax names the service — 1 writes a string (rsi = its address in
# the guest's own ground, rdx = its length), 2 writes one character
# (rsi's low byte), 0 leaves (rdi = the exit code). Services 1 and
# 2 are answered by Swift (cardnull_syscall_handler) and the guest
# resumes; service 0 never resumes, and is answered here, in the
# floor, because coming home is a matter of stacks and page-table
# roots, not of policy.
# ---------------------------------------------------------------------------
    .globl  cardnull_syscall_stub
cardnull_syscall_stub:
    cmp     $0, %rax                        # service 0 — leaving?
    je      cardnull_syscall_exit
    PUSH_ALL                                # the guest's registers, kept
    cld
    mov     112(%rsp), %rdi                 # the service number (saved rax)
    mov     80(%rsp), %rsi                  # the guest's first word (saved rsi)
    mov     88(%rsp), %rdx                  # the guest's second (saved rdx)
    call    cardnull_syscall_handler
    mov     %rax, 112(%rsp)                 # the answer rides home in rax
    POP_ALL
    iretq

# The way home, shared by the exit service above and by
# cardnull_abandon_program below: the kernel's own page tables are
# reloaded, the shell's stack — the one cardnull_launch_program
# was called from — is taken back, the registers that hand saved
# are restored, the interrupt gate is opened again (both doors
# here are interrupt gates or fault paths, which close it), and
# the launch hand's caller resumes as if the launch were an
# ordinary call that returned the value in rax.
cardnull_syscall_exit:
    mov     %rdi, %rax                      # the exit code is the return value
    mov     cardnull_return_cr3(%rip), %rcx
    mov     %rcx, %cr3                      # the kernel's own tables again
    mov     cardnull_shell_rsp(%rip), %rsp  # the shell's stack again
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbp
    pop     %rbx
    sti                                     # the shell lives with its gate open
    ret

# cardnull_launch_program(tables, entry, stack_top) -> verdict
#
# The going-out hand. It saves the registers the ABI calls
# callee-saved (the shell's Swift is standing on them), remembers
# the stack it was called on and the page tables it was called
# under, moves the machine onto the guest's tables, and builds
# the frame iretq needs to land in ring 3: the user data segment
# (0x20 | 3) under the guest's stack top, RFLAGS with the
# interrupt gate open (a guest that cannot be interrupted cannot
# be typed at, and its door is an interrupt besides), the user
# code segment (0x18 | 3), and the entry address. It never
# returns in the ordinary way: it is answered by the exit path
# above or by cardnull_abandon_program, both of which restore
# what was saved here and ret to the caller with a verdict.
    .globl  cardnull_launch_program
cardnull_launch_program:
    push    %rbx
    push    %rbp
    push    %r12
    push    %r13
    push    %r14
    push    %r15
    mov     %rsp, cardnull_shell_rsp(%rip)
    mov     %cr3, %rax
    mov     %rax, cardnull_return_cr3(%rip)
    mov     %rdi, %cr3                      # the guest's tables
    push    $0x23                           # SS: user data, ring 3
    push    %rdx                            # RSP: the guest stack's top
    push    $0x202                          # RFLAGS: gate open, reserved bit
    push    $0x1B                           # CS: user code, ring 3
    push    %rsi                            # RIP: the guest's first byte
    iretq

# cardnull_abandon_program(verdict) -> Never (called from Swift)
#
# The other way home: a guest that faulted in its own mode is not
# resumed and not repaired — it is abandoned. The page fault's
# Swift handler reports the fault, then calls here with the
# verdict the launch should return; the moves are the exit path's
# moves, because home is the same place by either road.
    .globl  cardnull_abandon_program
cardnull_abandon_program:
    mov     %rdi, %rax                      # the verdict is the return value
    mov     cardnull_return_cr3(%rip), %rcx
    mov     %rcx, %cr3
    mov     cardnull_shell_rsp(%rip), %rsp
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbp
    pop     %rbx
    sti
    ret

# The stub address table: support.c builds the IDT from these.
# Entries 0..31 are the exception vectors in order; entry 32 is IRQ0
# (IDT vector 0x20), entry 33 is IRQ1 (IDT vector 0x21), and entry 34
# is the milestone-9 service door (IDT vector 0x80, the one gate a
# guest may knock on).
    .section .rodata
    .align 8
    .globl  cardnull_stub_table
cardnull_stub_table:
    .quad   cardnull_isr0
    .quad   cardnull_isr1
    .quad   cardnull_isr2
    .quad   cardnull_isr3
    .quad   cardnull_isr4
    .quad   cardnull_isr5
    .quad   cardnull_isr6
    .quad   cardnull_isr7
    .quad   cardnull_isr8
    .quad   cardnull_isr9
    .quad   cardnull_isr10
    .quad   cardnull_isr11
    .quad   cardnull_isr12
    .quad   cardnull_isr13
    .quad   cardnull_isr14
    .quad   cardnull_isr15
    .quad   cardnull_isr16
    .quad   cardnull_isr17
    .quad   cardnull_isr18
    .quad   cardnull_isr19
    .quad   cardnull_isr20
    .quad   cardnull_isr21
    .quad   cardnull_isr22
    .quad   cardnull_isr23
    .quad   cardnull_isr24
    .quad   cardnull_isr25
    .quad   cardnull_isr26
    .quad   cardnull_isr27
    .quad   cardnull_isr28
    .quad   cardnull_isr29
    .quad   cardnull_isr30
    .quad   cardnull_isr31
    .quad   cardnull_irq0_stub
    .quad   cardnull_irq1_stub
    .quad   cardnull_syscall_stub

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
    .quad   0x0020FA0000000000                  # 0x18: user code — present, ring 3, executable, long-mode (M9)
    .quad   0x0000F20000000000                  # 0x20: user data — present, ring 3, writable (M9)
    # 0x28: the TSS descriptor — the sixteen bytes a 64-bit task
    # state segment needs. It is born empty; support.c writes the
    # real descriptor into it (cardnull_setup_user_mode) while this
    # table still sits in the floor's writable map, before
    # milestone 7's page tables make read-only data read-only
    # in truth.
    .globl  cardnull_gdt_tss_slot
cardnull_gdt_tss_slot:
    .quad   0x0000000000000000
    .quad   0x0000000000000000
gdt64_pointer:
    .word   gdt64_pointer - gdt64 - 1           # limit
    .quad   gdt64                               # base

# ---------------------------------------------------------------------------
# Page tables and the kernel stack, in uninitialized memory (.bss).
# The tables must be 4 KiB-aligned; the linker keeps .bss page-aligned.
# ---------------------------------------------------------------------------
    .section .bss
    .align 4
    .globl  cardnull_multiboot_info
cardnull_multiboot_info:
    .skip   4                                   # the Multiboot2 info address (EBX, kept)

# Milestone 9's two bookmarks: where home is. cardnull_launch_program
# writes both before it leaves; the door's exit path and
# cardnull_abandon_program read them on the way back.
    .align 8
cardnull_shell_rsp:
    .skip   8
cardnull_return_cr3:
    .skip   8

    .align 4096
page_table_pml4:
    .skip   4096
page_table_pdpt:
    .skip   4096
page_table_pd:
    .skip   16384                               # four PDs, back to back (4 GiB of map)

    .align 16
stack_bottom:
    .skip   16384                               # 16 KiB of kernel stack
stack_top:
