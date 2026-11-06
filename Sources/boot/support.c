/* Cardnull OS — runtime support shims.
 *
 * Part of the thin boot floor (DESIGN.md allows the floor to be
 * assembly and C). Embedded Swift's own object code names a handful of
 * C-library symbols even when the kernel never calls them — the whole
 * module links as one object, so the names must resolve. Each shim here
 * is honest about what a milestone-1 kernel can do:
 *
 *   - Stack protector: there is no userland to abort into. The guard
 *     word exists; failure rests the processor instead of returning.
 *   - Allocation: the kernel has no heap yet (memory management is
 *     milestone 3), so posix_memalign declines with ENOMEM and free
 *     lets go of nothing. Kernel code at this milestone allocates
 *     nothing; if a future call ever reached these, it would fail
 *     loudly rather than pretend.
 *   - Port I/O: Swift cannot emit the processor's `in`/`out`
 *     instructions, so the floor lends cardnull_inb / cardnull_outb.
 *     Milestone 2's keyboard hangs off them: the PS/2 controller is
 *     spoken to through ports 0x64 (status) and 0x60 (data).
 *
 * Written by hand, in the open, in the public domain.
 */

#include <stddef.h>

/* The stack-protector guard word the compiler's checks read. */
unsigned long __stack_chk_guard = 0;

/* Called if a stack check ever trips: rest, do not return. */
void __stack_chk_fail(void) {
    for (;;) {
        __asm__ volatile("hlt");
    }
}

/* No heap yet: decline, with ENOMEM, as POSIX allows. */
int posix_memalign(void **memptr, size_t alignment, size_t size) {
    (void)memptr;
    (void)alignment;
    (void)size;
    return 12; /* ENOMEM */
}

/* Pairs with the allocator above: nothing was ever handed out. */
void free(void *ptr) {
    (void)ptr;
}

/* Port I/O hands: read and write one byte at a processor I/O port. */
unsigned char cardnull_inb(unsigned short port) {
    unsigned char value;
    __asm__ volatile("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

void cardnull_outb(unsigned short port, unsigned char value) {
    __asm__ volatile("outb %0, %1" : : "a"(value), "Nd"(port));
}
