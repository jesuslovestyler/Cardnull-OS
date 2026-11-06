# The boot floor

This directory will hold the thin layer that is *not* Swift: the assembly
and C that wake an x86-64 processor, set its tables (GDT, IDT, paging),
take the handover from the bootloader, and call the kernel's `kmain`.

It is deliberately not written yet. The boot path is chosen when milestone 1
begins in earnest (bootloader, entry protocol, and linker script together),
and writing it before that choice would be decoration, not foundation.

Every operating system in every language has this floor. Ours will be as
thin as honesty allows, and every line of it will say why it exists.
