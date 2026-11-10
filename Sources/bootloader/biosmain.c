/* Cardnull OS — our own bootloader, the BIOS door:
 * the second stage's mind.
 *
 * Milestone 24: the last borrowed piece leaves. Behind
 * the BIOS door, GRUB has loaded our kernel since the
 * first milestone; this stage takes its place. The boot
 * sector (biosboot.S) has already gathered the whole boot
 * image here, to 0x7E00, and left the drive and its
 * sector size at the door. What remains is the loading
 * proper, and it is deliberately not a GRUB clone. It
 * does exactly these things, in the order it signs them
 * on screen:
 *
 *   1. It asks the machine its shape: the memory map by
 *      the BIOS's own E820 word (int 15h), gathered first,
 *      while the text screen still stands to confess a
 *      failure.
 *   2. It walks the boot disc's ISO9660 tree by EDD
 *      packet reads (int 13h AH=42h) — the primary volume
 *      descriptor, the root, the BOOT directory — and
 *      finds KERNEL.BIN and, beside it, FILES.BUNDLE.
 *      The disc may be a CD (2048 bytes to a sector) or a
 *      stick carrying the same image (512): the boot
 *      sector learned the drive's width from the drive
 *      itself, and every read below is reckoned through
 *      that multiplier, so one road serves both.
 *   3. It lays the kernel's ELF segments at their
 *      physical addresses — the kernel stands at 1 MiB,
 *      where its linker script put it — and zeroes what
 *      the file leaves unwritten. The bundle, when one
 *      rides, is laid right behind the kernel's span.
 *      Memory past a mebibyte is reached only through
 *      the two protected-mode hands in biosentry.S; the
 *      BIOS is always spoken to as a plain real-mode
 *      caller, segments zero, buffers it can reckon.
 *   4. It chooses the screen through VESA VBE — 1280 by
 *      800 at 32 bits to a pixel when the machine offers
 *      it, exactly what the desktop has always drawn on
 *      and what GRUB chose on this door before us — and
 *      builds the Multiboot2 information structure THE
 *      KERNEL ALREADY READS: a framebuffer tag from the
 *      chosen mode, a memory map tag translated, region
 *      for region, from E820, and a module tag naming
 *      the bundle's span when one rode. No more, no
 *      less: those tags and the end tag.
 *   5. It hands the machine over through go_kernel: the
 *      Multiboot2 magic in EAX, the information in EBX,
 *      32-bit protected mode, paging off — the doorstep
 *      boot.S was written for, the same one GRUB and the
 *      UEFI trampoline deliver. The kernel never learns
 *      the loader's name.
 *
 * Honest edges, stated rather than hidden:
 *
 *   - A road that fails — no memory map, no disc, no
 *     kernel on it, no screen the kernel can use — stops
 *     the loader where it stands, with the reason
 *     printed in plain words. Nothing is handed over
 *     half-made.
 *   - A bundle that is not on the disc, or will not fit
 *     the handover, is spoken of plainly and the boot
 *     goes on without one: the bundle is cargo, not a
 *     condition, exactly as behind the UEFI door.
 *   - The E820 map is passed through as the machine
 *     spoke it; the kernel reserves its own image, the
 *     information structure, and the module's span out
 *     of that pool by their own addresses, as it always
 *     has.
 *
 * Written by hand, in the open, in the public domain.
 */

/* ---------------------------------------------------------------- */
/* The floor's small print: types and the asm skin's word. */

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

/* biosentry.S: the thunks, each running on its globals. */
extern void bios_putch(void);
extern void bios_edd_read(void);
extern void bios_e820(void);
extern void bios_vbe(void);
extern void pm_copy(void);
extern void pm_zero(void);
extern void go_kernel(u32 infoAddress);

extern u8 g_drive;
extern u8 g_mult;
extern u16 g_sect_size;
extern u8 g_char;
extern u8 g_status;
extern u8 g_carry;
extern u8 g_dap[16];
extern u32 g_e820_cont;
extern u32 g_e820_di;
extern u32 g_e820_len;
extern u32 g_e820_sig;
extern u16 g_vbe_ax;
extern u16 g_vbe_bx;
extern u16 g_vbe_cx;
extern u32 g_vbe_di;
extern u32 g_copy_src;
extern u32 g_copy_dst;
extern u32 g_copy_len;
extern u32 g_zero_dst;
extern u32 g_zero_len;
extern u32 g_entry;

/* The linker's bounds on the stage's zeroed ground. */
extern u8 __bss_start;
extern u8 __bss_end;

/* The handful of C-library shapes a freestanding file
 * still owes its compiler. Volatile hands, so the
 * compiler cannot mistake these loops for calls to
 * themselves. */
void *memset(void *dst, int value, int n_);
void *memset(void *dst, int value, int n_) {
    volatile u8 *d = (volatile u8 *)dst;
    for (int i = 0; i < n_; i++) d[i] = (u8)value;
    return dst;
}

void *memcpy(void *dst, const void *src, int n_);
void *memcpy(void *dst, const void *src, int n_) {
    volatile u8 *d = (volatile u8 *)dst;
    const volatile u8 *s = (const volatile u8 *)src;
    for (int i = 0; i < n_; i++) d[i] = s[i];
    return dst;
}

/* Division by a variable is a library call on this
 * floor; the compiler is owed the two unsigned shapes.
 * Binary long division: shifts and subtractions only,
 * the same patience either way. */
u32 __udivmodsi4(u32 n, u32 d, u32 *rem);
u32 __udivmodsi4(u32 n, u32 d, u32 *rem) {
    u32 q = 0;
    u32 r = 0;
    if (d == 0) {
        if (rem) *rem = 0;
        return 0;
    }
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1u);
        if (r >= d) {
            r -= d;
            q |= (u32)1 << i;
        }
    }
    if (rem) *rem = r;
    return q;
}

u32 __udivsi3(u32 n, u32 d);
u32 __udivsi3(u32 n, u32 d) { return __udivmodsi4(n, d, (u32 *)0); }

u32 __umodsi3(u32 n, u32 d);
u32 __umodsi3(u32 n, u32 d) {
    u32 r = 0;
    (void)__udivmodsi4(n, d, &r);
    return r;
}

/* ---------------------------------------------------------------- */
/* Speech: the BIOS teletype, one letter at a time. */

static void print(const char *text) {
    while (*text) {
        g_char = (u8)*text++;
        bios_putch();
    }
}

/* A decimal reckoning, by patience: for each power of
 * ten, count the subtractions. No division anywhere. */
static void print_dec(u32 value) {
    static const u32 powers[10] = {1000000000u, 100000000u,
        10000000u, 1000000u, 100000u, 10000u, 1000u, 100u,
        10u, 1u};
    int started = 0;
    for (int i = 0; i < 10; i++) {
        u32 p = powers[i];
        u32 digit = 0;
        while (value >= p) {
            value -= p;
            digit++;
        }
        if (digit != 0 || started || i == 9) {
            g_char = (u8)('0' + digit);
            bios_putch();
            started = 1;
        }
    }
}

/* Stops the loader with the truth on screen. */
static void die(const char *what) {
    print("\r\nThe bootloader must stop here: ");
    print(what);
    print(".\r\nNothing was handed over. The machine rests.\r\n");
    for (;;) {
        __asm__ volatile("cli; hlt");
    }
}

/* ---------------------------------------------------------------- */
/* Reading the disc: EDD packet reads over int 13h.
 *
 * Every read the stage makes is reckoned in ISO sectors
 * (2048 bytes) and translated once, here, to the drive's
 * own width through the boot sector's multiplier: one
 * drive sector to an ISO sector on a CD, four on a
 * stick. Buffers are honest real-mode addresses: a
 * segment and an offset the BIOS can reckon, no higher
 * than the first mebibyte's honest country. */

static int read_drive(u32 iso_lba, u32 iso_count,
                      u16 buf_seg, u16 buf_off) {
    while (iso_count > 0) {
        u32 chunk = iso_count > 8 ? 8 : iso_count;
        g_dap[0] = 0x10;
        g_dap[1] = 0;
        u32 dev_count = chunk * g_mult;
        g_dap[2] = (u8)dev_count;
        g_dap[3] = (u8)(dev_count >> 8);
        g_dap[4] = (u8)buf_off;
        g_dap[5] = (u8)(buf_off >> 8);
        g_dap[6] = (u8)buf_seg;
        g_dap[7] = (u8)(buf_seg >> 8);
        u32 dev_lba = iso_lba * g_mult;
        g_dap[8] = (u8)dev_lba;
        g_dap[9] = (u8)(dev_lba >> 8);
        g_dap[10] = (u8)(dev_lba >> 16);
        g_dap[11] = (u8)(dev_lba >> 24);
        g_dap[12] = 0;
        g_dap[13] = 0;
        g_dap[14] = 0;
        g_dap[15] = 0;
        bios_edd_read();
        if (g_carry || g_status != 0) return 0;
        iso_lba += chunk;
        iso_count -= chunk;
        buf_seg = (u16)(buf_seg + 0x400); /* 16 KiB a chunk */
    }
    return 1;
}

/* One ISO sector, into the stage's own directory buffer. */
static u8 dirbuf[2048];

static int read_sector(u32 iso_lba, u8 *into) {
    u32 addr = (u32)(u32)(void *)into;
    return read_drive(iso_lba, 1, 0, (u16)addr);
}

/* Many ISO sectors, to any address in the machine, by
 * way of the bounce field at 0x40000 and the protected
 * hand. */
#define BOUNCE_PHYS 0x40000u

static int read_to_phys(u32 iso_lba, u32 iso_sectors, u32 dest) {
    while (iso_sectors > 0) {
        u32 chunk = iso_sectors > 8 ? 8 : iso_sectors;
        if (!read_drive(iso_lba, chunk, 0x4000, 0)) return 0;
        g_copy_src = BOUNCE_PHYS;
        g_copy_dst = dest;
        g_copy_len = chunk * 2048;
        pm_copy();
        iso_lba += chunk;
        iso_sectors -= chunk;
        dest += chunk * 2048;
    }
    return 1;
}

/* Many ISO sectors, to a home below a mebibyte — no
 * bounce needed; the drive can be told the address
 * itself, segment stepping and all. */
static int read_to_low(u32 iso_lba, u32 iso_sectors, u16 start_seg) {
    return read_drive(iso_lba, iso_sectors, start_seg, 0);
}

/* ---------------------------------------------------------------- */
/* The disc's tree: ISO9660, read the way the kernel
 * reads it — the plain name fields at each record's
 * offset 33, the ";1" version suffix forgiven, letters
 * matched without case. */

static u32 rd32(const u8 *p, u32 off) {
    return (u32)p[off] | ((u32)p[off + 1] << 8) |
           ((u32)p[off + 2] << 16) | ((u32)p[off + 3] << 24);
}

static u16 rd16(const u8 *p, u32 off) {
    return (u16)((u16)p[off] | ((u16)p[off + 1] << 8));
}

/* Does the record's name say the word we seek? The
 * record's name runs name_len bytes; ours is a plain
 * word. A ";1" tail on the record's side is forgiven,
 * as the kernel forgives it. */
static int name_says(const u8 *record, const char *word) {
    u32 name_len = record[32];
    const u8 *name = record + 33;
    u32 i = 0;
    for (;;) {
        char want = word[i];
        if (want == '\0') {
            /* Our word is spent: the record's name must
             * be spent too, or wearing only its version. */
            if (i == name_len) return 1;
            if (name[i] == ';') return 1;
            return 0;
        }
        if (i >= name_len) return 0;
        char got = (char)name[i];
        if (got >= 'a' && got <= 'z') got = (char)(got - 'a' + 'A');
        if (want >= 'a' && want <= 'z') want = (char)(want - 'a' + 'A');
        if (got != want) return 0;
        i++;
    }
}

/* Finds one name in one directory. On a find, the
 * extent and size are the caller's; the walk reads the
 * directory a sector at a time, forgiving the empty
 * tail of each sector the way the format leaves it. */
static int find_in_dir(u32 dir_lba, u32 dir_size,
                       const char *word,
                       u32 *out_lba, u32 *out_size) {
    u32 loaded_sector = 0xFFFFFFFFu;
    u32 pos = 0;
    while (pos < dir_size) {
        u32 sector = dir_lba + (pos >> 11);
        if (sector != loaded_sector) {
            if (!read_sector(sector, dirbuf)) return 0;
            loaded_sector = sector;
        }
        u32 at = pos & 2047;
        u8 rec_len = dirbuf[at];
        if (rec_len == 0) {
            pos = (pos & ~2047u) + 2048;
            continue;
        }
        if (name_says(dirbuf + at, word)) {
            *out_lba = rd32(dirbuf + at, 2);
            *out_size = rd32(dirbuf + at, 10);
            return 1;
        }
        pos += rec_len;
    }
    return 0;
}

/* Finds the BOOT directory and the two files this stage
 * exists for. The bundle's absence is not a failure:
 * its pointers simply stay zero. */
static u32 kernel_lba, kernel_size;
static u32 bundle_lba, bundle_size;

static void walk_disc(void) {
    if (!read_sector(16, dirbuf))
        die("reading the boot disc");
    if (dirbuf[0] != 1 || dirbuf[1] != 'C' || dirbuf[2] != 'D' ||
        dirbuf[3] != '0' || dirbuf[4] != '0' || dirbuf[5] != '1')
        die("the boot disc does not confess itself an ISO9660 disc");
    u32 root_lba = rd32(dirbuf, 156 + 2);
    u32 root_size = rd32(dirbuf, 156 + 10);
    u32 boot_lba = 0, boot_size = 0;
    if (!find_in_dir(root_lba, root_size, "BOOT",
                     &boot_lba, &boot_size))
        die("finding the BOOT directory on the boot disc");
    if (!find_in_dir(boot_lba, boot_size, "KERNEL.BIN",
                     &kernel_lba, &kernel_size))
        die("finding KERNEL.BIN on the boot disc");
    if (!find_in_dir(boot_lba, boot_size, "FILES.BUNDLE",
                     &bundle_lba, &bundle_size)) {
        bundle_lba = 0;
        bundle_size = 0;
    }
}

/* ---------------------------------------------------------------- */
/* The machine's shape: E820, gathered whole. */

static u8 e820_raw[64 * 24];
static u32 e820_count;

static void gather_memory(void) {
    e820_count = 0;
    g_e820_cont = 0;
    for (;;) {
        g_e820_di = (u32)(void *)(e820_raw + e820_count * 24);
        bios_e820();
        if (g_carry) break;
        if (g_e820_sig != 0x534D4150u)
            die("the machine's memory map would not speak "
                "its signature");
        if (g_e820_len < 20) break; /* a stub of an entry */
        /* Twenty honest bytes (or twenty-four, with the
         * ACPI word): keep the first twenty, zero the
         * rest of our row, whatever the BIOS left there. */
        e820_raw[e820_count * 24 + 20] = 0;
        e820_raw[e820_count * 24 + 21] = 0;
        e820_raw[e820_count * 24 + 22] = 0;
        e820_raw[e820_count * 24 + 23] = 0;
        e820_count++;
        if (g_e820_cont == 0) break;
        if (e820_count >= 64)
            die("the machine's memory map outgrew its keeping");
    }
    if (e820_count == 0)
        die("the machine offered no memory map");
}

/* ---------------------------------------------------------------- */
/* The kernel, laid at its own addresses. */

#define KSTAGE_PHYS 0x50000u
#define KSTAGE_SEG 0x5000u
#define KERNEL_FILE_CAP 0x48000u

static u8 elf_head[64];
static u8 phdr_tab[8 * 56];
static u32 kernel_entry;
static u32 kernel_span_high;

static void load_kernel(void) {
    if (kernel_size == 0 || kernel_size > KERNEL_FILE_CAP)
        die("the kernel's size is past what this stage "
            "can carry");
    u32 sectors = (kernel_size + 2047) >> 11;
    if (!read_to_low(kernel_lba, sectors, KSTAGE_SEG))
        die("reading the kernel off the boot disc");

    g_copy_src = KSTAGE_PHYS;
    g_copy_dst = (u32)(void *)elf_head;
    g_copy_len = 64;
    pm_copy();
    if (elf_head[0] != 0x7F || elf_head[1] != 'E' ||
        elf_head[2] != 'L' || elf_head[3] != 'F' ||
        elf_head[4] != 2 || elf_head[5] != 1 ||
        rd16(elf_head, 18) != 0x3E)
        die("the kernel's file is not the ELF it should be");
    kernel_entry = rd32(elf_head, 24);
    u32 phoff = rd32(elf_head, 32);
    u16 phentsize = rd16(elf_head, 54);
    u16 phnum = rd16(elf_head, 56);
    if (phoff == 0 || phentsize < 56 || phnum == 0 || phnum > 8)
        die("the kernel's program table is not as it "
            "should be");

    g_copy_src = KSTAGE_PHYS + phoff;
    g_copy_dst = (u32)(void *)phdr_tab;
    g_copy_len = (u32)phnum * 56;
    pm_copy();

    u32 span_low = 0xFFFFFFFFu;
    u32 span_high = 0;
    for (u32 i = 0; i < phnum; i++) {
        const u8 *p = phdr_tab + i * 56;
        if (rd32(p, 0) != 1) continue; /* not a load */
        u32 offset = rd32(p, 8);
        u32 paddr = rd32(p, 24);
        u32 filesz = rd32(p, 32);
        u32 memsz = rd32(p, 40);
        if (rd32(p, 12) != 0 || rd32(p, 28) != 0 ||
            rd32(p, 36) != 0 || rd32(p, 44) != 0)
            die("the kernel stands past the 4 GiB this "
                "door can address");
        if (paddr < 0x100000u || memsz > 0x400000u ||
            filesz > memsz)
            die("a kernel segment stands where it should "
                "not");
        if (filesz > 0) {
            g_copy_src = KSTAGE_PHYS + offset;
            g_copy_dst = paddr;
            g_copy_len = filesz;
            pm_copy();
        }
        if (memsz > filesz) {
            g_zero_dst = paddr + filesz;
            g_zero_len = memsz - filesz;
            pm_zero();
        }
        if (paddr < span_low) span_low = paddr;
        if (paddr + memsz > span_high) span_high = paddr + memsz;
    }
    if (span_high == 0)
        die("the kernel carries nothing to lay down");
    kernel_span_high = span_high;

    print("The kernel is in hand: ");
    print_dec(kernel_size);
    print(" bytes, read from the boot disc, laid at 1 MiB.\r\n");
}

/* ---------------------------------------------------------------- */
/* The bundle, laid behind the kernel. */

static u32 bundle_start;
static u32 bundle_end;

static void load_bundle(void) {
    bundle_start = 0;
    bundle_end = 0;
    if (bundle_lba == 0) {
        print("The file bundle did not ride: it is not "
              "on the boot disc.\r\n");
        return;
    }
    if (bundle_size == 0 || bundle_size > 0x1000000u) {
        print("The file bundle did not ride: its size is "
              "past what the handover can name.\r\n");
        return;
    }
    u32 dest = (kernel_span_high + 0xFFF) & ~0xFFFu;
    u32 sectors = (bundle_size + 2047) >> 11;
    if (!read_to_phys(bundle_lba, sectors, dest))
        die("reading the file bundle off the boot disc");
    bundle_start = dest;
    bundle_end = dest + bundle_size;
    print("The file bundle rides in memory: ");
    print_dec(bundle_size);
    print(" bytes.\r\n");
}

/* ---------------------------------------------------------------- */
/* The screen, through VESA VBE. */

static u8 vbe_ctrl[512];
static u8 vbe_mode[256];
static u16 modelist[128];

static u32 fb_addr;
static u32 fb_pitch;
static u32 fb_width;
static u32 fb_height;
static u8 fb_bpp;
static u8 fb_rpos, fb_rsize, fb_gpos, fb_gsize, fb_bpos, fb_bsize;

static int vbe_call(u16 ax, u16 bx, u16 cx, u8 *buffer) {
    g_vbe_ax = ax;
    g_vbe_bx = bx;
    g_vbe_cx = cx;
    g_vbe_di = (u32)(void *)buffer;
    bios_vbe();
    return g_vbe_ax == 0x004F;
}

static void choose_screen(void) {
    if (!vbe_call(0x4F00, 0, 0, vbe_ctrl))
        die("the machine offers no VESA screen the "
            "kernel can draw on");
    if (vbe_ctrl[0] != 'V' || vbe_ctrl[1] != 'E' ||
        vbe_ctrl[2] != 'S' || vbe_ctrl[3] != 'A')
        die("the VESA word came back unsigned");

    /* The mode list lives where the controller says —
     * a segment:offset pair, often in the video ROM.
     * Copy it home through the protected hand. */
    u32 list_phys = ((u32)rd16(vbe_ctrl, 16) << 4) +
                    rd16(vbe_ctrl, 14);
    g_copy_src = list_phys;
    g_copy_dst = (u32)(void *)modelist;
    g_copy_len = 256;
    pm_copy();

    u16 best = 0xFFFF;
    u32 best_area = 0;
    int best_bpp = 0;
    int found = 0;
    for (int i = 0; i < 128; i++) {
        u16 mode = modelist[i];
        if (mode == 0xFFFF) break;
        if (!vbe_call(0x4F01, 0, mode, vbe_mode)) continue;
        u16 attrs = rd16(vbe_mode, 0);
        if ((attrs & 0x01) == 0) continue;      /* supported */
        if ((attrs & 0x80) == 0) continue;      /* a flat field */
        if (vbe_mode[27] != 6) continue;        /* direct color */
        u32 w = rd16(vbe_mode, 18);
        u32 h = rd16(vbe_mode, 20);
        int bpp = vbe_mode[25];
        if (w < 640 || h < 200) continue;
        if (bpp != 32 && bpp != 24) continue;
        if (w == 1280 && h == 800 && bpp == 32) {
            best = mode;                        /* the desktop's */
            best_bpp = bpp;                     /* own shape */
            found = 1;
            break;
        }
        u32 area = w * h;
        if (!found || bpp > best_bpp ||
            (bpp == best_bpp && area > best_area)) {
            best = mode;
            best_bpp = bpp;
            best_area = area;
            found = 1;
        }
    }
    if (!found)
        die("the machine offers no VESA mode the kernel "
            "can draw on");

    /* Ask the chosen mode its facts, and keep exactly
     * what it answers — the tag, not the hope, is what
     * the kernel believes. */
    if (!vbe_call(0x4F01, 0, best, vbe_mode))
        die("the chosen screen mode would not describe "
            "itself");
    fb_addr = rd32(vbe_mode, 40);
    fb_pitch = rd16(vbe_mode, 16);
    fb_width = rd16(vbe_mode, 18);
    fb_height = rd16(vbe_mode, 20);
    fb_bpp = vbe_mode[25];
    fb_rpos = vbe_mode[32];
    fb_rsize = vbe_mode[31];
    fb_gpos = vbe_mode[34];
    fb_gsize = vbe_mode[33];
    fb_bpos = vbe_mode[36];
    fb_bsize = vbe_mode[35];
    if (fb_addr == 0)
        die("the chosen screen mode has no field to "
            "draw on");

    print("Screen: ");
    print_dec(fb_width);
    print(" by ");
    print_dec(fb_height);
    print(", ");
    print_dec(fb_bpp);
    print(" bits to a pixel.\r\n");

    /* Set it, with the flat field asked for by name.
     * After this the text screen is gone, and the next
     * words on this screen are the kernel's own. */
    if (!vbe_call(0x4F02, (u16)(best | 0x4000), 0, vbe_mode))
        die("setting the screen's mode failed");
}

/* ---------------------------------------------------------------- */
/* The handover's word: the Multiboot2 information.
 *
 * The layout is the specification's, and the kernel's
 * reader is the measure — the same three tags the UEFI
 * loader builds: the framebuffer (type 8, forty bytes,
 * its channels at 32..37), the module (type 3) when a
 * bundle rides, the memory map (type 6, 24-byte entries
 * at the tag's byte 16), and the end tag. */

static u8 info_buf[2048];

static void put32(u32 off, u32 value) {
    info_buf[off] = (u8)value;
    info_buf[off + 1] = (u8)(value >> 8);
    info_buf[off + 2] = (u8)(value >> 16);
    info_buf[off + 3] = (u8)(value >> 24);
}

static u32 mb_kind(u32 e820_type) {
    if (e820_type == 1) return 1;   /* available RAM */
    if (e820_type == 3) return 3;   /* ACPI, reclaimable */
    if (e820_type == 4) return 4;   /* ACPI, keep */
    if (e820_type == 5) return 5;   /* unusable */
    return 2;                       /* reserved */
}

static u32 build_information(void) {
    u32 off = 8;

    /* The framebuffer tag. */
    put32(off + 0, 8);
    put32(off + 4, 40);
    put32(off + 8, fb_addr);
    put32(off + 12, 0);
    put32(off + 16, fb_pitch);
    put32(off + 20, fb_width);
    put32(off + 24, fb_height);
    info_buf[off + 28] = fb_bpp;
    info_buf[off + 29] = 1;         /* direct color */
    info_buf[off + 30] = 0;
    info_buf[off + 31] = 0;
    info_buf[off + 32] = fb_rpos;
    info_buf[off + 33] = fb_rsize;
    info_buf[off + 34] = fb_gpos;
    info_buf[off + 35] = fb_gsize;
    info_buf[off + 36] = fb_bpos;
    info_buf[off + 37] = fb_bsize;
    info_buf[off + 38] = 0;
    info_buf[off + 39] = 0;
    off += 40;

    /* The module tag, when a bundle rides. */
    if (bundle_start != 0) {
        static const char naming[13] = "FILES.BUNDLE";
        put32(off + 0, 3);
        put32(off + 4, 32);
        put32(off + 8, bundle_start);
        put32(off + 12, bundle_end);
        for (int i = 0; i < 13; i++)
            info_buf[off + 16 + i] = (u8)naming[i];
        info_buf[off + 29] = 0;
        info_buf[off + 30] = 0;
        info_buf[off + 31] = 0;
        off += 32;
    }

    /* The memory map tag: E820, translated region for
     * region — the base and length carried verbatim,
     * the kind in Multiboot2's numbering. */
    u32 map_tag = off;
    put32(map_tag + 0, 6);
    put32(map_tag + 8, 24);         /* entry size */
    put32(map_tag + 12, 0);         /* entry version */
    u32 out = map_tag + 16;
    for (u32 i = 0; i < e820_count; i++) {
        const u8 *row = e820_raw + i * 24;
        for (int b = 0; b < 16; b++) info_buf[out + b] = row[b];
        put32(out + 16, mb_kind(rd32(row, 16)));
        put32(out + 20, 0);
        out += 24;
    }
    put32(map_tag + 4, 16 + e820_count * 24);
    off = out;

    /* The end tag, and the whole reckoning. */
    put32(off + 0, 0);
    put32(off + 4, 8);
    off += 8;
    put32(0, off);
    put32(4, 0);
    return off;
}

/* ---------------------------------------------------------------- */

void stage2_main(void);
void stage2_main(void) {
    /* Zero the stage's kept ground before anything
     * reads it — the boot image carries no promise
     * about what stood here before us. */
    memset(&__bss_start, 0,
           (int)(&__bss_end - &__bss_start));

    print("\r\nCardnull Bootloader\r\n");
    print("Cardnull OS behind the BIOS door, loaded by "
          "our own hand.\r\n");

    gather_memory();
    print("Memory map: ");
    print_dec(e820_count);
    print(" regions, by the machine's own E820 word.\r\n");

    walk_disc();
    load_kernel();
    load_bundle();

    choose_screen();

    (void)build_information();
    g_entry = kernel_entry;
    go_kernel((u32)(void *)info_buf);
}
