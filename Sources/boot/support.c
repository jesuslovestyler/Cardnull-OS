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
 *   - Interrupts (milestone 4): the IDT's construction, the PIC
 *     remap, the PIT's programming, the sti that opens the gate, the
 *     hlt/cli hands, and 64 bytes of raw ring storage for the
 *     keyboard handler — the processor-table work a floor exists
 *     for. What interrupts mean is decided in Swift, above.
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

/* Sleep one wait: stop the processor until the next interrupt, then
 * return to the caller. Milestone 4's shell loop rests here instead of
 * spinning on the keyboard ports. Interrupts must already be enabled
 * (cardnull_setup_interrupts ends with sti). */
void cardnull_hlt_once(void) {
    __asm__ volatile("hlt");
}

/* Close the interrupt gate and keep it closed. The exception handler
 * calls this before its last words, so nothing can interrupt a halt. */
void cardnull_cli(void) {
    __asm__ volatile("cli");
}

/* ------------------------------------------------------------------ */
/* Milestone 4: the interrupt machinery.                               */
/*                                                                     */
/* The floor's half of interrupts, matching the stubs in boot.S:       */
/* build the IDT from the assembly stub table, point the processor     */
/* at it, move the PIC pair off the BIOS vectors (where they collide   */
/* with the exception vectors) to 0x20/0x28, set the timer ticking     */
/* at 100 Hz, and open the gate. The handlers themselves — what a      */
/* tick means, what a scancode means — are the kernel's, in Swift.     */
/* ------------------------------------------------------------------ */

/* One gate in the Interrupt Descriptor Table: sixteen bytes saying
 * where a vector goes, in which segment, and that it is an interrupt
 * gate in ring 0. */
struct idt_entry {
    unsigned short offset_low;
    unsigned short selector;
    unsigned char ist;
    unsigned char type_attr;
    unsigned short offset_mid;
    unsigned int offset_high;
    unsigned int reserved;
} __attribute__((packed));

static struct idt_entry cardnull_idt[256];

struct idt_pointer {
    unsigned short limit;
    unsigned long base;
} __attribute__((packed));

/* boot.S exports the stub addresses: entries 0..31 are the exception
 * stubs in vector order, entry 32 is IRQ0's stub, 33 is IRQ1's. */
extern const unsigned long cardnull_stub_table[];

static void idt_set_gate(int vector, unsigned long handler) {
    cardnull_idt[vector].offset_low = (unsigned short)(handler & 0xFFFF);
    cardnull_idt[vector].selector = 0x08;    /* the kernel code segment */
    cardnull_idt[vector].ist = 0;
    cardnull_idt[vector].type_attr = 0x8E;   /* present, ring 0, interrupt gate */
    cardnull_idt[vector].offset_mid = (unsigned short)((handler >> 16) & 0xFFFF);
    cardnull_idt[vector].offset_high = (unsigned int)((handler >> 32) & 0xFFFFFFFFUL);
    cardnull_idt[vector].reserved = 0;
}

/* A breath between PIC commands: write to the POST port, the ancient
 * way of wasting a moment of bus time while the chips catch up. */
static void io_wait(void) {
    cardnull_outb(0x80, 0);
}

/* Raise the whole machinery, in the only safe order: the table, the
 * pointer to it, the PICs, the timer, a last tidy of the keyboard
 * controller, and only then the gate itself. Called once from kmain,
 * with interrupts still closed from the boot. */
void cardnull_setup_interrupts(void) {
    struct idt_pointer pointer;
    int vector;

    /* The IDT: exceptions 0..31 to their stubs, IRQ0 and IRQ1 to
     * vectors 0x20 and 0x21. Every other gate stays zeroed — absent —
     * which for a vector we never unmasked is the honest state. (The
     * table lives in .bss and starts zeroed, as the boot leaves it.) */
    for (vector = 0; vector < 32; vector++) {
        idt_set_gate(vector, cardnull_stub_table[vector]);
    }
    idt_set_gate(0x20, cardnull_stub_table[32]);
    idt_set_gate(0x21, cardnull_stub_table[33]);

    pointer.limit = (unsigned short)(sizeof(cardnull_idt) - 1);
    pointer.base = (unsigned long)cardnull_idt;
    __asm__ volatile("lidt %0" : : "m"(pointer));

    /* Remap the 8259 pair. ICW1 opens the ceremony; ICW2 moves the
     * vectors — master to 0x20, slave to 0x28, clear of the exception
     * vectors the BIOS left them sitting on; ICW3 states the cascade
     * wiring (the slave hangs off the master's IRQ2); ICW4 asks for
     * plain 8086 mode. Then the masks: on the master, IRQ0 (timer)
     * and IRQ1 (keyboard) are open and all else shut; the slave is
     * shut entirely — we take nothing from it yet. */
    cardnull_outb(0x20, 0x11); io_wait();   /* master ICW1 */
    cardnull_outb(0xA0, 0x11); io_wait();   /* slave ICW1 */
    cardnull_outb(0x21, 0x20); io_wait();   /* master ICW2: vectors at 0x20 */
    cardnull_outb(0xA1, 0x28); io_wait();   /* slave ICW2: vectors at 0x28 */
    cardnull_outb(0x21, 0x04); io_wait();   /* master ICW3: slave on IRQ2 */
    cardnull_outb(0xA1, 0x02); io_wait();   /* slave ICW3: cascade identity */
    cardnull_outb(0x21, 0x01); io_wait();   /* master ICW4: 8086 mode */
    cardnull_outb(0xA1, 0x01); io_wait();   /* slave ICW4 */
    cardnull_outb(0x21, 0xFC);              /* master mask: IRQ0 + IRQ1 open */
    cardnull_outb(0xA1, 0xFF);              /* slave mask: all shut */

    /* The timer: PIT channel 0, square wave, divisor 11932 — the
     * 1,193,182 Hz input clock divided down to a 100 Hz heartbeat. */
    cardnull_outb(0x43, 0x36);
    cardnull_outb(0x40, (unsigned char)(11932 & 0xFF));
    cardnull_outb(0x40, (unsigned char)((11932 >> 8) & 0xFF));

    /* If the keyboard controller still holds a byte from the
     * bootloader's day, take it now, in the quiet before the gate
     * opens — so the first IRQ1 is a true keypress, not a leftover. */
    while (cardnull_inb(0x64) & 0x01) {
        (void)cardnull_inb(0x60);
    }

    /* Open the gate. From here the machine can speak first. */
    __asm__ volatile("sti");
}

/* The keyboard mailbox: 64 bytes of raw storage the Swift kernel uses
 * as its scancode ring buffer. The floor lends the memory — Embedded
 * Swift has no way to name a fixed mutable byte array without a heap —
 * and makes no decision about the bytes: who writes the ring, who
 * reads it, and what "full" means are the kernel's business, in
 * Kernel.swift. The number 64 is agreed with the kernel's keyRingSize. */
static unsigned char key_ring[64];

unsigned char *cardnull_key_ring(void) {
    return key_ring;
}
