# The boot floor

This directory holds the thin layer that is *not* Swift: the code that
wakes an x86-64 processor, sets its tables, takes the handover from the
bootloader, and calls the kernel's `kmain`. Every operating system in
every language has this floor. Ours is as thin as honesty allows, and
every line says why it exists.

## What is here

- **`boot.S`** — the floor itself, in assembly:
  - a **Multiboot2 header**, so GRUB can load the kernel — carrying,
    since milestone 5, a framebuffer tag that asks the bootloader
    for a linear framebuffer (no particular mode: a bootloader that
    must match an exact mode can fail to find one, as UEFI GRUB
    did when asked for 1024x768 by name);
  - the entry stub (`_start`): GRUB hands over a 32-bit processor
    and the address of its information structure in EBX — preserved
    now in `cardnull_multiboot_info` and passed on to `kmain`, so
    the kernel can read the framebuffer tag — so the stub builds
    identity-mapped page tables (first 4 GiB, 2 MiB pages; wide
    enough for a firmware framebuffer wherever it honestly sits),
    enables PAE and the long-mode bit, turns paging on, loads a
    64-bit GDT, and far-jumps into long mode;
  - data-segment setup, a clean stack, and **SSE enablement** — Swift's
    compiler emits SSE instructions for ordinary work, and the first
    one faults if CR4.OSFXSR is not set, so waking the FPU/SSE unit is
    floor work;
  - the call into Swift's `kmain`, and `cardnull_halt`, the `hlt` loop
    the kernel rests in;
  - the **interrupt stubs** (milestone 4): one door per exception
    vector — vectors without a CPU error code get a dummy, so every
    frame is the same shape — all ending in a shared entry that hands
    the vector number to Swift's exception handler; two IRQ stubs
    (timer, keyboard) that save every register, call their Swift
    handler, and return by `iretq`; and `cardnull_stub_table`, the
    address table the IDT is built from. Milestone 7 replaced vector
    14's macro-born stub with a hand-written one: the page fault owes
    the kernel two facts the shared door cannot carry — the error
    code the processor pushed and the faulting address it keeps in
    CR2 — and this stub takes both and hands them to Swift's
    page-fault handler, which reports them before halting.
- **`support.c`** — runtime support shims: the stack-protector guard
  word and failure path, allocation entry points that honestly
  decline (there is no heap yet), and the port I/O hands
  `cardnull_inb` / `cardnull_outb` — Swift cannot emit the processor's
  `in`/`out` instructions, and the keyboard is spoken to through
  ports. Embedded Swift's object code names these symbols; the floor
  answers for them. Milestone 4 added the interrupt bring-up:
  `cardnull_setup_interrupts` builds the IDT from the stub table,
  remaps the PIC pair to vectors 0x20/0x28, programs the PIT for a
  100 Hz heartbeat, drains the keyboard controller, and opens the
  gate with `sti`; plus the `hlt`-once and `cli` hands the shell's
  sleep and the exception handler rest on, and 64 bytes of raw
  storage the kernel uses as its scancode ring buffer. Milestone 5
  added two lendings of storage: 2,000 bytes the kernel keeps its
  own 80x25 character grid in (`cardnull_text_grid`) — the grid is
  the screen's truth now, painted through whichever backend the
  boot provided — and the plain `memset` / `memcpy` / `memmove`
  every C floor owes, which Swift's grip on that grid reaches for
  by name. Milestone 6 added two more lendings, both for the frame
  allocator the kernel raises in Swift: 128 KiB of raw bitmap
  storage (`cardnull_frame_bitmap` — one bit per 4 KiB frame,
  covering the first 4 GiB) and the kernel image's own bounds
  (`cardnull_kernel_start` / `cardnull_kernel_end`), so the
  allocator can reserve the ground the kernel stands on. What the
  bits mean stays the kernel's business, as always. Milestone 7
  added the paging hands — `cardnull_enable_nxe` and
  `cardnull_load_cr3`, the two privileged touches Swift cannot
  make — and the linker's word about the image's text and
  read-only spans (`cardnull_text_start` / `cardnull_text_end`,
  `cardnull_rodata_start` / `cardnull_rodata_end`), so the kernel
  can lay W^X over its own body. The tables themselves — what is
  mapped, under what law — are built in Swift, above; the floor
  only lends the hands and the measurements. Milestone 8 widened
  the port hands to the double-word — `cardnull_inl` /
  `cardnull_outl`, for PCI configuration space, where the disc
  controller is found — and added `cardnull_invlpg`, the
  forget-one-translation hand: the disc driver maps its
  controller's registers into the kernel's standing tables,
  pages that were absent a moment ago, and the processor must be
  told to look again. The controller's own registers are
  memory-mapped and need no hand at all; everything the driver
  decides stands in Swift, above.
- **`font8x8.c`** — the letters for the framebuffer screen: the
  public-domain 8x8 bitmap font from Daniel Hepper's font8x8
  project (built on the public-domain IBM VGA font heritage),
  fetched from GitHub and held here as a table of 128 glyphs, with
  its provenance written in the file's own header. The kernel
  draws with it wherever the boot provided pixels instead of a
  text grid — behind UEFI, always.
- **`linker.ld`** — lays the kernel at 1 MiB (0x100000) with the
  Multiboot2 header first in the image, each section on its own
  page. Since milestone 6 it also names the image's bounds —
  `__cardnull_kernel_start` / `__cardnull_kernel_end` — the
  reservation the allocator lays over itself. Milestone 7 named
  the text and read-only spans as well —
  `__cardnull_text_start` / `__cardnull_text_end`,
  `__cardnull_rodata_start` / `__cardnull_rodata_end` — assigned
  inside their sections' braces, where the location counter
  already wears the section's alignment, so the kernel's page
  tables can mark the spans executable-unwritable and read-only
  in turn.

## What is not here yet

No tables of our own in the floor, by design: the floor's 4 GiB
identity map is scaffolding — it exists to walk the processor
into long mode — and since milestone 7 the kernel replaces it
with page tables of its own building as soon as the frame
allocator stands, and raises its heap (in Swift, above) on the
far side of the switch. The floor grows only when the kernel
above it honestly requires more. The IDT's gates beyond the
exceptions and IRQ0/IRQ1 stand empty, likewise: a vector earns
a stub when a device or a duty honestly arrives, not before.
