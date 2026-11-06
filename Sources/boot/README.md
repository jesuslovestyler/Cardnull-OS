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
    the kernel rests in;
  - the **interrupt stubs** (milestone 4): one door per exception
    vector — vectors without a CPU error code get a dummy, so every
    frame is the same shape — all ending in a shared entry that hands
    the vector number to Swift's exception handler; two IRQ stubs
    (timer, keyboard) that save every register, call their Swift
    handler, and return by `iretq`; and `cardnull_stub_table`, the
    address table the IDT is built from.
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
  storage the kernel uses as its scancode ring buffer.
- **`linker.ld`** — lays the kernel at 1 MiB (0x100000) with the
  Multiboot2 header first in the image, each section on its own page.

## What is not here yet

No memory beyond the identity map — memory management is milestone
3 on the roadmap, and the floor grows only when the kernel above it
honestly requires more. The IDT's gates beyond the exceptions and
IRQ0/IRQ1 stand empty, likewise: a vector earns a stub when a device
or a duty honestly arrives, not before.
