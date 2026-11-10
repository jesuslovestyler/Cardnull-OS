/* Cardnull OS — the BIOS second stage's linker script.
 *
 * Milestone 24. The second stage stands at 0x7E00, the
 * byte right behind the boot sector in the boot image,
 * and speaks in absolute addresses throughout: its
 * segment registers are zero from entry to handoff, so
 * the link address is the machine address. The entry
 * hand (biosentry.S) leads, then the thunks and the C,
 * then what the C reads, then the ground it keeps zeroed
 * until it writes it (buffers, the information staging).
 * The whole stage must end below 0x10000 — its buffers
 * are addressed as offsets under segment zero, and the
 * build holds it to that line.
 */

OUTPUT_FORMAT(elf32-i386)
ENTRY(_stage2_entry)

SECTIONS
{
    . = 0x7E00;

    .text : {
        *(.text.entry)
        *(.text)
        *(.text.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .data : {
        *(.data)
        *(.data.*)
    }

    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }

    /DISCARD/ : {
        *(.note .note.*)
        *(.comment)
        *(.eh_frame .eh_frame.*)
    }
}
