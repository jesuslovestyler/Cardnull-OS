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
