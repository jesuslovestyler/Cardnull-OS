/* Cardnull OS — linker script.
 *
 * Lays the kernel out the way the boot path expects:
 *   - ELF64 for x86-64, entry point _start (in boot.S).
 *   - Loaded at 1 MiB (0x100000), the traditional home for Multiboot
 *     kernels: safely above the BIOS data areas, the VGA buffers, and
 *     the real-mode interrupt table.
 *   - The Multiboot2 header section comes FIRST in the image, because
 *     GRUB only scans the beginning of the file for it.
 *   - Each section starts on a fresh page, so page tables can grow
 *     honest permissions later — and as of milestone 7 they have:
 *     the script now names the text and read-only spans below, and
 *     the kernel's own page tables mark them so.
 */

OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

SECTIONS
{
    . = 0x100000;

    /* The kernel image's own bounds, named for milestone 6: the
     * memory allocator must never hand out the frames the kernel
     * itself is standing on, so the floor lends these two addresses
     * to the kernel (through support.c) as its reservation. */
    __cardnull_kernel_start = .;

    /* The Multiboot2 header leads the file. Milestone 7 names the
     * text span: the kernel's own page tables mark these pages
     * executable and not writable, so the boundary must be a linker's
     * fact, not a guess. The .text.* glob is insurance for any
     * compiler-named code section that would otherwise land as an
     * orphan beyond the named span. */
    /* The span symbols live INSIDE the braces, deliberately: a
     * symbol assigned between sections would capture the location
     * counter before the next section's alignment is applied, and
     * the read-only span would begin a page early — inside text. */
    .text : ALIGN(4K)
    {
        __cardnull_text_start = .;
        *(.multiboot_header)
        *(.text)
        *(.text.*)
        __cardnull_text_end = .;
    }

    /* The read-only span, likewise named for milestone 7: data the
     * kernel reads but never writes and never executes. The Swift
     * module hash rides here — read-only by its own section flags,
     * and the page tables will treat the whole span as one country. */
    .rodata : ALIGN(4K)
    {
        __cardnull_rodata_start = .;
        *(.rodata .rodata.*)
        *(.swift_modhash)
        __cardnull_rodata_end = .;
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

    /* One past the kernel image's last byte (page tables and stack
     * live in .bss, so they are inside the reservation too). */
    __cardnull_kernel_end = .;

    /* Anything the compilers emit that we did not name has no home here. */
    /DISCARD/ :
    {
        *(.note .note.*)
        *(.comment)
        *(.eh_frame .eh_frame.*)
    }
}
