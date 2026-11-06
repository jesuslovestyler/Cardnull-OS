/* Cardnull OS — linker script.
 *
 * Lays the kernel out the way the boot path expects:
 *   - ELF64 for x86-64, entry point _start (in boot.S).
 *   - Loaded at 1 MiB (0x100000), the traditional home for Multiboot
 *     kernels: safely above the BIOS data areas, the VGA buffers, and
 *     the real-mode interrupt table.
 *   - The Multiboot2 header section comes FIRST in the image, because
 *     GRUB only scans the beginning of the file for it.
 *   - Each section starts on a fresh page, so the page tables the boot
 *     floor builds can grow honest permissions later.
 */

OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

SECTIONS
{
    . = 0x100000;

    /* The Multiboot2 header leads the file. */
    .text : ALIGN(4K)
    {
        *(.multiboot_header)
        *(.text)
    }

    .rodata : ALIGN(4K)
    {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4K)
    {
        *(.data .data.*)
    }

    .bss : ALIGN(4K)
    {
        *(COMMON)
        *(.bss .bss.*)
    }

    /* Anything the compilers emit that we did not name has no home here. */
    /DISCARD/ :
    {
        *(.note .note.*)
        *(.comment)
        *(.eh_frame .eh_frame.*)
    }
}
