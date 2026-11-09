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
 *   - Allocation: these C entry points decline with ENOMEM and free
 *     lets go of nothing. The kernel's heap (milestone 7) lives in
 *     Swift and serves the kernel itself; nothing in the floor calls
 *     these names, so they stay unconnected — answering honestly
 *     rather than pretending to be the heap they are not.
 *   - Port I/O: Swift cannot emit the processor's `in`/`out`
 *     instructions, so the floor lends cardnull_inb / cardnull_outb.
 *     Milestone 2's keyboard hangs off them: the PS/2 controller is
 *     spoken to through ports 0x64 (status) and 0x60 (data).
 *   - Interrupts (milestone 4): the IDT's construction, the PIC
 *     remap, the PIT's programming, the sti that opens the gate, the
 *     hlt/cli hands, and 64 bytes of raw ring storage for the
 *     keyboard handler — the processor-table work a floor exists
 *     for. What interrupts mean is decided in Swift, above.
 *   - The screen's memory (milestone 5): 2,000 bytes of raw storage
 *     holding the 80x25 character grid. While the kernel wrote
 *     straight into VGA text memory, the hardware itself kept the
 *     characters and the shell read typed lines back off it; the
 *     UEFI door has no such memory — a framebuffer keeps pixels,
 *     not letters — so the kernel keeps the grid itself now, here,
 *     and paints it through whichever screen is live. Which screen
 *     that is, and what the letters mean, are decided in Swift.
 *   - The mouse's keepings (milestone 12): a 256-byte ring for the
 *     PS/2 mouse's bytes, filled by IRQ12's handler one byte at a
 *     time and drained by the graphical face at its leisure, and a
 *     small cushion of raw pixel words — the ground the pointer
 *     stands on, saved before it is drawn and restored when it
 *     moves, so the pointer leaves no trail. The IDT gains the
 *     mouse's gate (vector 0x2C) and the PIC masks open the
 *     cascade and IRQ12 to let it speak. What the bytes mean is
 *     decided in Swift, above.
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

/* The memory hands (milestone 5): the compiler's own optimization
 * names memset for the kernel's grid-filling loops — a fill through
 * a raw pointer is recognized and lowered to the C symbol — and
 * memcpy/memmove are its kin, named here before the day another
 * pattern lowers to them. Plain byte loops, honestly sized to a
 * kernel that moves screenfuls, not libraries. */
void *memset(void *dest, int value, size_t count) {
    unsigned char *p = (unsigned char *)dest;
    size_t i;
    for (i = 0; i < count; i++) {
        p[i] = (unsigned char)value;
    }
    return dest;
}

void *memcpy(void *dest, const void *src, size_t count) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    size_t i;
    for (i = 0; i < count; i++) {
        d[i] = s[i];
    }
    return dest;
}

void *memmove(void *dest, const void *src, size_t count) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    size_t i;
    if (d < s) {
        for (i = 0; i < count; i++) {
            d[i] = s[i];
        }
    } else if (d > s) {
        for (i = count; i > 0; i--) {
            d[i - 1] = s[i - 1];
        }
    }
    return dest;
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

/* Milestone 8 widens the port hands to the double-word, for
 * PCI configuration space: a device's identity and its register
 * addresses are read and written a full 32 bits at a time
 * through ports 0xCF8 (the address) and 0xCFC (the data). The
 * disc controller is found there; its own registers are
 * memory-mapped and need no hand at all. What the configuration
 * means is decided in Swift, above; the floor only moves the
 * words. */
unsigned int cardnull_inl(unsigned short port) {
    unsigned int value;
    __asm__ volatile("inl %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

void cardnull_outl(unsigned short port, unsigned int value) {
    __asm__ volatile("outl %0, %1" : : "a"(value), "Nd"(port));
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
 * stubs in vector order, entry 32 is IRQ0's stub, 33 is IRQ1's,
 * entry 34 is the milestone-9 service-door stub, and entry 35 is
 * IRQ12's stub — the mouse's (milestone 12). */
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

/* Milestone 9's one open gate: the same interrupt gate, stamped
 * with privilege level 3, so a guest in ring 3 may knock with
 * int 0x80 — and only there. Every other gate in the table keeps
 * the ring-0 stamp above: a guest that reaches for any other
 * vector is met by a general-protection fault, not a welcome. */
static void idt_set_user_gate(int vector, unsigned long handler) {
    idt_set_gate(vector, handler);
    cardnull_idt[vector].type_attr = 0xEE;   /* present, ring 3, interrupt gate */
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
     * table lives in .bss and starts zeroed, as the boot leaves it.)
     * Milestone 9 adds one more gate after these: vector 0x80, the
     * guests' service door, stamped for ring 3 — the only door in
     * the wall a program is ever allowed to knock on. Milestone 12
     * adds the last of this raising: vector 0x2C, IRQ12 — the mouse,
     * which lives on the slave PIC (vectors 0x28 and up) as its
     * fourth child. */
    for (vector = 0; vector < 32; vector++) {
        idt_set_gate(vector, cardnull_stub_table[vector]);
    }
    idt_set_gate(0x20, cardnull_stub_table[32]);
    idt_set_gate(0x21, cardnull_stub_table[33]);
    idt_set_user_gate(0x80, cardnull_stub_table[34]);
    idt_set_gate(0x2C, cardnull_stub_table[35]);

    pointer.limit = (unsigned short)(sizeof(cardnull_idt) - 1);
    pointer.base = (unsigned long)cardnull_idt;
    __asm__ volatile("lidt %0" : : "m"(pointer));

    /* Remap the 8259 pair. ICW1 opens the ceremony; ICW2 moves the
     * vectors — master to 0x20, slave to 0x28, clear of the exception
     * vectors the BIOS left them sitting on; ICW3 states the cascade
     * wiring (the slave hangs off the master's IRQ2); ICW4 asks for
     * plain 8086 mode. Then the masks: on the master, IRQ0 (timer),
     * IRQ1 (keyboard), and IRQ2 — the cascade, the wire the slave
     * hangs from — are open and all else shut; on the slave, only
     * IRQ12 (the mouse, milestone 12) is open. The mouse itself is
     * woken by the kernel before this raising (its enable is a
     * polled conversation that must happen with the gate closed),
     * so no byte of its can arrive before its gate stands here. */
    cardnull_outb(0x20, 0x11); io_wait();   /* master ICW1 */
    cardnull_outb(0xA0, 0x11); io_wait();   /* slave ICW1 */
    cardnull_outb(0x21, 0x20); io_wait();   /* master ICW2: vectors at 0x20 */
    cardnull_outb(0xA1, 0x28); io_wait();   /* slave ICW2: vectors at 0x28 */
    cardnull_outb(0x21, 0x04); io_wait();   /* master ICW3: slave on IRQ2 */
    cardnull_outb(0xA1, 0x02); io_wait();   /* slave ICW3: cascade identity */
    cardnull_outb(0x21, 0x01); io_wait();   /* master ICW4: 8086 mode */
    cardnull_outb(0xA1, 0x01); io_wait();   /* slave ICW4 */
    cardnull_outb(0x21, 0xF8);              /* master mask: IRQ0 + IRQ1 + cascade open */
    cardnull_outb(0xA1, 0xEF);              /* slave mask: IRQ12 (mouse) open */

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

/* The screen's memory: 80 columns x 25 rows of characters, the grid
 * the kernel reads its typed lines from and paints its screens out
 * of. The floor lends the memory for the same reason it lends the
 * key ring — Embedded Swift cannot name a fixed mutable byte array
 * without a heap — and makes no decision about the letters. The
 * numbers 80 and 25 are agreed with the kernel's screenColumns and
 * screenRows. */
static unsigned char text_grid[80 * 25];

unsigned char *cardnull_text_grid(void) {
    return text_grid;
}

/* ------------------------------------------------------------------ */
/* Milestone 12: the mouse's two keepings.                             */
/*                                                                     */
/* The mouse speaks in threes — three bytes to a packet — and it      */
/* speaks by IRQ12, one byte per knock. The floor lends the two       */
/* places the kernel keeps them in, for the same reason it lends      */
/* the key ring: Embedded Swift cannot name fixed mutable storage     */
/* without a heap.                                                    */
/*                                                                     */
/*   - The mouse ring: 256 bytes the IRQ12 handler fills and the      */
/*     graphical face drains at its leisure. The number 256 is        */
/*     agreed with the kernel's mouseRingSize.                        */
/*   - The pointer's cushion: 32 x 32 raw pixel words — the ground    */
/*     under the pointer, lifted into safekeeping before the          */
/*     pointer is drawn on it and laid back when the pointer          */
/*     moves or goes home, so it never smears a trail across the      */
/*     face. 32 is the largest pointer the face will ever draw;       */
/*     the kernel's pointer is smaller, and clips its drawing to      */
/*     the screen's edge besides.                                     */
/* ------------------------------------------------------------------ */

static unsigned char mouse_ring[256];

unsigned char *cardnull_mouse_ring(void) {
    return mouse_ring;
}

static unsigned int gui_cushion[32 * 32];

unsigned int *cardnull_gui_cushion(void) {
    return gui_cushion;
}

/* ------------------------------------------------------------------ */
/* Milestone 6: the frame allocator's two lendings.                    */
/*                                                                     */
/* The allocator itself — which frames exist, which are free, what   */
/* the Multiboot2 memory map means — is decided in Swift, above.     */
/* The floor lends only what Swift cannot name for itself:           */
/*                                                                     */
/*   - The bitmap's raw storage: one bit per 4 KiB frame. 128 KiB    */
/*     of bits covers 1,048,576 frames — the whole first 4 GiB,      */
/*     which is also as far as the boot floor's identity map can     */
/*     reach today. The number is agreed with the kernel's           */
/*     frameBitmapCapacityBytes.                                     */
/*   - The kernel image's own bounds, as the linker script named     */
/*     them, so the allocator can reserve the ground the kernel      */
/*     itself is standing on.                                        */
/* ------------------------------------------------------------------ */

static unsigned char frame_bitmap[131072];

unsigned char *cardnull_frame_bitmap(void) {
    return frame_bitmap;
}

extern char __cardnull_kernel_start;
extern char __cardnull_kernel_end;

unsigned long cardnull_kernel_start(void) {
    return (unsigned long)&__cardnull_kernel_start;
}

unsigned long cardnull_kernel_end(void) {
    return (unsigned long)&__cardnull_kernel_end;
}

/* ------------------------------------------------------------------ */
/* Milestone 7: the paging hands, and the kernel's own shape.          */
/*                                                                     */
/* The page tables themselves — what is mapped, with what law — are  */
/* decided in Swift, above. The floor lends only the touches Swift   */
/* cannot make: two privileged instructions and the linker's word    */
/* about the image's own spans.                                      */
/*                                                                     */
/*   - cardnull_enable_nxe: the no-execute bit in a page entry is    */
/*     honored only while EFER's NXE bit stands; while it is clear,  */
/*     the same bit is reserved and would fault the very tables it   */
/*     belongs to. It is raised before any table carrying the bit    */
/*     is loaded — exactly once, by the kernel, at the switch.       */
/*   - cardnull_load_cr3: point the processor at a new set of page   */
/*     tables. The write itself flushes the translation caches,      */
/*     so the next instruction fetch already walks the new tables.   */
/*   - The text and read-only spans, as the linker script named      */
/*     them, so the kernel can give its own code pages the law       */
/*     W^X promises: text executable and never writable, read-only   */
/*     data neither.                                                 */
/* ------------------------------------------------------------------ */

void cardnull_enable_nxe(void) {
    unsigned int low, high;
    __asm__ volatile("rdmsr" : "=a"(low), "=d"(high) : "c"(0xC0000080));
    low |= 0x800;   /* EFER.NXE */
    __asm__ volatile("wrmsr" : : "c"(0xC0000080), "a"(low), "d"(high));
}

void cardnull_load_cr3(unsigned long root) {
    __asm__ volatile("mov %0, %%cr3" : : "r"(root) : "memory");
}

/* Forget one page's cached translation. Milestone 8's disc
 * driver maps its controller's registers into the standing
 * tables — pages that were absent a moment ago — and this hand
 * makes the processor look again rather than trust the absence
 * it may have remembered. */
void cardnull_invlpg(unsigned long address) {
    __asm__ volatile("invlpg (%0)" : : "r"(address) : "memory");
}

extern char __cardnull_text_start;
extern char __cardnull_text_end;
extern char __cardnull_rodata_start;
extern char __cardnull_rodata_end;

unsigned long cardnull_text_start(void) {
    return (unsigned long)&__cardnull_text_start;
}

unsigned long cardnull_text_end(void) {
    return (unsigned long)&__cardnull_text_end;
}

unsigned long cardnull_rodata_start(void) {
    return (unsigned long)&__cardnull_rodata_start;
}

unsigned long cardnull_rodata_end(void) {
    return (unsigned long)&__cardnull_rodata_end;
}

/* ------------------------------------------------------------------ */
/* Milestone 9: the ring-3 furniture.                                  */
/*                                                                     */
/* A guest cannot be entered until the processor has somewhere to    */
/* stand when the guest knocks or falls: a task state segment whose  */
/* ring-0 stack pointer names a stack of the kernel's own, and a     */
/* TSS descriptor in the GDT pointing at it. Both live here: the    */
/* TSS's 104 bytes and a 16 KiB entry stack, lent as raw storage    */
/* the way the floor lends the key ring and the text grid.          */
/*                                                                     */
/* cardnull_setup_user_mode writes the descriptor into the empty    */
/* slot boot.S left in the GDT, points the TSS at the entry stack,  */
/* and loads the task register. It must be called while the floor's */
/* own boot map still stands — that map leaves the kernel's         */
/* read-only span writable, and the GDT sits in it. Milestone 7's   */
/* page tables would make the descriptor write itself fault, so    */
/* kmain calls this before it builds them.                          */
/* ------------------------------------------------------------------ */

static unsigned char cardnull_entry_stack[16384] __attribute__((aligned(16)));
static unsigned char cardnull_tss[104] __attribute__((aligned(16)));

/* boot.S: the empty sixteen bytes at GDT offset 0x28. */
extern unsigned char cardnull_gdt_tss_slot[];

void cardnull_setup_user_mode(void) {
    const unsigned long tss = (unsigned long)cardnull_tss;
    const unsigned long stack_top =
        (unsigned long)(cardnull_entry_stack + sizeof(cardnull_entry_stack));
    unsigned char *slot = cardnull_gdt_tss_slot;
    int i;

    for (i = 0; i < 104; i++) {
        cardnull_tss[i] = 0;
    }
    /* RSP0, at offset 4: the stack every ring-3 knock, fault and
     * interrupt is received on. Its top is 16-byte aligned, so the
     * interrupt frame and the stubs' register saves land where the
     * ABI expects them. */
    *(unsigned long *)(cardnull_tss + 4) = stack_top;
    /* The I/O permission bitmap's base, at offset 102: set past the
     * segment's end, which says there is no bitmap — a guest that
     * touches an I/O port faults, and honestly so. */
    *(unsigned short *)(cardnull_tss + 102) = 104;

    /* The descriptor: limit 103 (the TSS's one hundred and four
     * bytes, counted the way limits are), the base in its scattered
     * fields, and the type byte of an available 64-bit TSS —
     * present, ring 0 (the TSS belongs to the kernel, always),
     * type 1001. */
    slot[0] = (unsigned char)(103 & 0xFF);
    slot[1] = (unsigned char)((103 >> 8) & 0xFF);
    slot[2] = (unsigned char)(tss & 0xFF);
    slot[3] = (unsigned char)((tss >> 8) & 0xFF);
    slot[4] = (unsigned char)((tss >> 16) & 0xFF);
    slot[5] = 0x89;
    slot[6] = 0;
    slot[7] = (unsigned char)((tss >> 24) & 0xFF);
    slot[8] = (unsigned char)((tss >> 32) & 0xFF);
    slot[9] = (unsigned char)((tss >> 40) & 0xFF);
    slot[10] = (unsigned char)((tss >> 48) & 0xFF);
    slot[11] = (unsigned char)((tss >> 56) & 0xFF);
    slot[12] = 0;
    slot[13] = 0;
    slot[14] = 0;
    slot[15] = 0;

    /* Load the task register with the slot's selector. From here,
     * a privilege change knows where the kernel's ground is. */
    __asm__ volatile("ltr %0" : : "r"((unsigned short)0x28));
}
