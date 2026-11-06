# The boot floor

This directory holds the thin layer that is *not* Swift: the code that
wakes an x86-64 processor, sets its tables, takes the handover from the
bootloader, and calls the kernel's `kmain`. Every operating system in
every language has this floor. Ours is as thin as honesty allows, and
every line says why it exists.

## What is here

- **`boot.S`** — the floor itself, in assembly:
  - a **Multiboot2 header**, so GRUB can load the kernel;
  - the entry stub (`_start`): GRUB hands over a 32-bit processor, so
    the stub builds identity-mapped page tables (first 1 GiB, 2 MiB
    pages), enables PAE and the long-mode bit, turns paging on, loads a
    64-bit GDT, and far-jumps into long mode;
  - data-segment setup, a clean stack, and **SSE enablement** — Swift's
    compiler emits SSE instructions for ordinary work, and the first
    one faults if CR4.OSFXSR is not set, so waking the FPU/SSE unit is
    floor work;
  - the call into Swift's `kmain`, and `cardnull_halt`, the `hlt` loop
    the kernel rests in.
- **`support.c`** — runtime support shims: the stack-protector guard
  word and failure path, allocation entry points that honestly
  decline (there is no heap until milestone 3), and the port I/O hands
  `cardnull_inb` / `cardnull_outb` — Swift cannot emit the processor's
  `in`/`out` instructions, and milestone 2's keyboard is spoken to
  through ports. Embedded Swift's object code names these symbols;
  the floor answers for them.
- **`linker.ld`** — lays the kernel at 1 MiB (0x100000) with the
  Multiboot2 header first in the image, each section on its own page.

## What is not here yet

No IDT and no interrupt handling — milestone 2's keyboard *polls*, so
nothing here had to grow for it beyond the port I/O hands in
`support.c`. No memory beyond the identity map, either — memory
management is milestone 3. The floor grows only when the kernel above
it honestly requires more.
