/* Cardnull OS — our own bootloader, the UEFI door.
 *
 * Milestone 22: the last GPL-shaped passenger leaves.
 * Behind the UEFI door, GRUB has loaded our kernel since
 * milestone 5; this small public-domain application takes
 * its place on that door. It is deliberately not a GRUB
 * clone. It does exactly four things, in the order it
 * signs them on screen:
 *
 *   1. It reads the kernel — the same /boot/kernel.bin the
 *      BIOS door's GRUB loads, present on the boot volume
 *      at \BOOT\KERNEL.BIN — through the firmware's own
 *      file protocol, from the very volume the firmware
 *      booted this loader from.
 *   2. It lays the kernel's ELF segments at their physical
 *      addresses (the kernel stands at 1 MiB, where its
 *      linker script put it) and zeroes what the file
 *      leaves unwritten, claiming that ground by its exact
 *      address so nothing else can be standing there.
 *   3. It chooses the screen through the firmware's
 *      graphics protocol — 1280 by 800 at 32 bits to a
 *      pixel when the machine offers it, exactly what the
 *      desktop has always drawn on — and builds the
 *      Multiboot2 information structure THE KERNEL ALREADY
 *      READS: a framebuffer tag from the chosen mode, and
 *      a memory map tag translated, region for region,
 *      from the firmware's own map. No more, no less: two
 *      tags and the end tag, the whole of the kernel's
 *      diet since milestones 5 and 6.
 *   4. It leaves the firmware's keeping (ExitBootServices)
 *      and steps the processor down to the doorstep
 *      Multiboot2 promises — 32-bit protected mode, paging
 *      off, EAX the magic, EBX the information — by the
 *      hand in trampoline.S, and jumps to the kernel's
 *      entry point. The kernel never learns the loader's
 *      name; it reads the same word GRUB left it, which
 *      is the whole design.
 *
 * Honest edges, stated rather than hidden:
 *
 *   - The memory map is the firmware's, translated at the
 *     moment of leaving: memory the loaders used (this
 *     program, its readings) is spoken of as available,
 *     as GRUB also spoke of its own — the kernel reserves
 *     its own image and the information structure itself
 *     out of that pool by their own addresses, and its
 *     allocator never hands out what the map calls
 *     anything but available.
 *   - The firmware's runtime services are spoken of as
 *     reserved. The kernel never calls them, and the
 *     memory they stand on is not ours to hand out.
 *   - A road that fails — no kernel on the volume, no
 *     screen the kernel can use, ground already taken at
 *     1 MiB — stops the loader where it stands, with the
 *     reason printed and the firmware's status beside it.
 *     Nothing is handed over half-made.
 *
 * Written by hand, in the open, in the public domain.
 */

#include "efi.h"

/* The step down, in trampoline.S: called once, never
 * returns. The information's address and the kernel's
 * entry, each a 32-bit physical address by then. */
extern void cardnull_enter_kernel(uint32_t infoAddress,
                                  uint32_t entryAddress);

/* The handful of C-library shapes a freestanding file
 * still owes its compiler. */
void *memcpy(void *dst, const void *src, size_t n) {
    uint8_t *d = (uint8_t *)dst;
    const uint8_t *s = (const uint8_t *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dst;
}

void *memset(void *dst, int value, size_t n) {
    uint8_t *d = (uint8_t *)dst;
    for (size_t i = 0; i < n; i++) d[i] = (uint8_t)value;
    return dst;
}

/* The protocol names, as the firmware knows them. */
static const EFI_GUID kLoadedImageGuid = {
    0x5B1B31A1, 0x9562, 0x11D2,
    {0x8E, 0x3F, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B}};
static const EFI_GUID kFileSystemGuid = {
    0x964E5B22, 0x6459, 0x11D2,
    {0x8E, 0x39, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B}};
static const EFI_GUID kGraphicsGuid = {
    0x9042A9DE, 0x23DC, 0x4A38,
    {0x96, 0xFB, 0x7A, 0xDE, 0xD0, 0x80, 0x51, 0x6A}};

static EFI_BOOT_SERVICES *gBS;
static EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *gConOut;

/* Rests the processor: what a stopped loader does instead
 * of pretending. Interrupts off, so nothing disturbs it. */
static void rest(void) {
    for (;;) {
        __asm__ volatile("cli; hlt");
    }
}

/* Speaks one ASCII line through the firmware's console.
 * The console drinks UTF-16; the loader thinks in bytes,
 * so the words are widened a mouthful at a time. */
static void speak(const char *text) {
    CHAR16 wide[160];
    UINTN used = 0;
    for (const char *p = text;; p++) {
        if (*p == '\0' || used == 158) {
            if (used > 0) {
                wide[used] = 0;
                gConOut->OutputString(gConOut, wide);
                used = 0;
            }
            if (*p == '\0') return;
        }
        wide[used++] = (CHAR16)(uint8_t)*p;
    }
}

static void speak_dec(uint64_t value) {
    char digits[24];
    char out[24];
    int n = 0;
    if (value == 0) {
        speak("0");
        return;
    }
    while (value > 0) {
        digits[n++] = (char)('0' + (value % 10));
        value /= 10;
    }
    for (int i = 0; i < n; i++) out[i] = digits[n - 1 - i];
    out[n] = '\0';
    speak(out);
}

static void speak_hex(uint64_t value) {
    char out[19];
    out[0] = '0';
    out[1] = 'x';
    for (int i = 0; i < 16; i++) {
        int nibble = (int)((value >> (60 - 4 * i)) & 0xF);
        out[2 + i] = (char)(nibble < 10 ? '0' + nibble
                                        : 'a' + nibble - 10);
    }
    out[18] = '\0';
    speak(out);
}

/* Stops the loader with the truth on screen: what road
 * failed, and the firmware's own word about it. */
static void stop(const char *what, EFI_STATUS status) {
    speak("\r\nThe bootloader must stop here: ");
    speak(what);
    speak(".\r\nThe firmware's word on it: ");
    speak_hex(status);
    speak("\r\nNothing was handed over. The machine rests.\r\n");
    rest();
}

/* ---------------------------------------------------------------- */
/* The kernel's ELF shape, as much of it as loading needs. */

typedef struct {
    uint8_t ident[16];
    uint16_t type;
    uint16_t machine;
    uint32_t version;
    uint64_t entry;
    uint64_t phoff;
    uint64_t shoff;
    uint32_t flags;
    uint16_t ehsize;
    uint16_t phentsize;
    uint16_t phnum;
    uint16_t shentsize;
    uint16_t shnum;
    uint16_t shstrndx;
} Elf64Header;

typedef struct {
    uint32_t type;
    uint32_t flags;
    uint64_t offset;
    uint64_t vaddr;
    uint64_t paddr;
    uint64_t filesz;
    uint64_t memsz;
    uint64_t align;
} Elf64Program;

#define ELF_PT_LOAD 1
#define ELF_MACHINE_X86_64 0x3E

/* ---------------------------------------------------------------- */
/* The Multiboot2 information the kernel reads — two tags.
 *
 * The layout is the specification's, and the kernel's
 * reader is the measure: the framebuffer tag must be at
 * least 38 bytes with its channels at offsets 32..37, and
 * the memory map tag's entries must be at least 24 bytes
 * each, standing at the tag's byte 16. */

/* Where a mask's channel stands, and how wide it is: the
 * place of its lowest set bit, and the count of its bits. */
static void channel_shape(uint32_t mask, uint8_t *position,
                          uint8_t *size) {
    uint8_t pos = 0;
    uint8_t count = 0;
    if (mask == 0) {
        *position = 0;
        *size = 0;
        return;
    }
    while ((mask & 1) == 0) {
        mask >>= 1;
        pos++;
    }
    while (mask & 1) {
        mask >>= 1;
        count++;
    }
    *position = pos;
    *size = count;
}

/* The firmware's kinds, in Multiboot2's numbering — the
 * one translation this loader exists to make faithfully.
 * What a machine's next program may use is 1; the
 * firmware's own lasting countries become the reserved
 * and recollected kinds the kernel keeps out of its pool. */
static uint32_t multiboot_kind(uint32_t efiType) {
    switch (efiType) {
        case EfiConventionalMemory:
        case EfiLoaderCode:
        case EfiLoaderData:
        case EfiBootServicesCode:
        case EfiBootServicesData:
        case EfiPersistentMemory:
            return 1; /* available RAM */
        case EfiACPIReclaimMemory:
            return 3;
        case EfiACPIMemoryNVS:
            return 4;
        case EfiUnusableMemory:
            return 5;
        default:
            return 2; /* reserved: runtime services, the
                         memory-mapped dark, the unnamed */
    }
}

static void put_u32(uint8_t *base, UINTN offset, uint32_t value) {
    base[offset] = (uint8_t)value;
    base[offset + 1] = (uint8_t)(value >> 8);
    base[offset + 2] = (uint8_t)(value >> 16);
    base[offset + 3] = (uint8_t)(value >> 24);
}

static void put_u64(uint8_t *base, UINTN offset, uint64_t value) {
    put_u32(base, offset, (uint32_t)value);
    put_u32(base, offset + 4, (uint32_t)(value >> 32));
}

/* The framebuffer's facts, chosen before the leaving. */
static uint64_t gFbAddress;
static uint32_t gFbPitch;
static uint32_t gFbWidth;
static uint32_t gFbHeight;
static uint8_t gFbBpp;
static uint8_t gFbRedPos, gFbRedSize;
static uint8_t gFbGreenPos, gFbGreenSize;
static uint8_t gFbBluePos, gFbBlueSize;

/* Builds the information into the page kept for it, from
 * the firmware's map as last read. Returns the count of
 * regions handed over, or 0 when the map will not fit —
 * a map too large for its page is a stop, not a trimming,
 * because a trimmed map is a lie about the machine. */
#define INFO_BYTES 16384
#define INFO_MAX_REGIONS \
    ((INFO_BYTES - 8 - 40 - 16 - 8) / 24)

static UINTN build_information(uint8_t *info,
                               const uint8_t *mapBytes,
                               UINTN mapSize, UINTN descriptorSize) {
    UINTN count = mapSize / descriptorSize;
    if (count > INFO_MAX_REGIONS) return 0;

    /* The framebuffer tag (type 8), forty bytes. */
    UINTN off = 8;
    put_u32(info, off + 0, 8);
    put_u32(info, off + 4, 40);
    put_u64(info, off + 8, gFbAddress);
    put_u32(info, off + 16, gFbPitch);
    put_u32(info, off + 20, gFbWidth);
    put_u32(info, off + 24, gFbHeight);
    info[off + 28] = gFbBpp;
    info[off + 29] = 1; /* direct color, RGB in the fields */
    info[off + 30] = 0;
    info[off + 31] = 0;
    info[off + 32] = gFbRedPos;
    info[off + 33] = gFbRedSize;
    info[off + 34] = gFbGreenPos;
    info[off + 35] = gFbGreenSize;
    info[off + 36] = gFbBluePos;
    info[off + 37] = gFbBlueSize;
    off += 40;

    /* The memory map tag (type 6): its header, then one
     * 24-byte entry per region of the firmware's map. */
    UINTN mapTag = off;
    put_u32(info, mapTag + 0, 6);
    put_u32(info, mapTag + 8, 24);  /* entry size */
    put_u32(info, mapTag + 12, 0);  /* entry version */
    UINTN entryOut = mapTag + 16;
    UINTN written = 0;
    for (UINTN i = 0; i < count; i++) {
        const EFI_MEMORY_DESCRIPTOR *row =
            (const EFI_MEMORY_DESCRIPTOR *)(mapBytes +
                                            i * descriptorSize);
        uint64_t length = row->NumberOfPages * 4096ULL;
        if (length == 0) continue;
        put_u64(info, entryOut, row->PhysicalStart);
        put_u64(info, entryOut + 8, length);
        put_u32(info, entryOut + 16, multiboot_kind(row->Type));
        put_u32(info, entryOut + 20, 0);
        entryOut += 24;
        written++;
    }
    put_u32(info, mapTag + 4, (uint32_t)(16 + written * 24));
    off = entryOut;

    /* The end tag, and the whole reckoning in the header. */
    put_u32(info, off + 0, 0);
    put_u32(info, off + 4, 8);
    off += 8;
    put_u32(info, 0, (uint32_t)off);
    put_u32(info, 4, 0);
    return written;
}

/* ---------------------------------------------------------------- */

/* Could the kernel draw on this mode? Its reader asks for
 * a direct-color field at least as large as its grid of
 * letters — 640 by 200 — at 24 or 32 bits to a pixel. */
static int mode_usable(EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *mode,
                       uint32_t *bytesPerPixel) {
    if (mode->PixelFormat == PixelBltOnly) return 0;
    if (mode->HorizontalResolution < 640 ||
        mode->VerticalResolution < 200)
        return 0;
    uint32_t masks[3];
    if (mode->PixelFormat ==
        PixelRedGreenBlueReserved8BitPerColor) {
        masks[0] = 0x000000FF;
        masks[1] = 0x0000FF00;
        masks[2] = 0x00FF0000;
    } else if (mode->PixelFormat ==
               PixelBlueGreenRedReserved8BitPerColor) {
        masks[0] = 0x00FF0000;
        masks[1] = 0x0000FF00;
        masks[2] = 0x000000FF;
    } else if (mode->PixelFormat == PixelBitMask) {
        masks[0] = mode->PixelInformation.RedMask;
        masks[1] = mode->PixelInformation.GreenMask;
        masks[2] = mode->PixelInformation.BlueMask;
    } else {
        return 0;
    }
    uint32_t top = 0;
    for (int i = 0; i < 3; i++) {
        uint8_t pos, size;
        channel_shape(masks[i], &pos, &size);
        if (size == 0) return 0;
        if (pos + size > top) top = pos + size;
    }
    /* The pixel's whole span counts — reserved byte and
     * all. The two Reserved formats are four bytes by
     * their very names (three colors and a reserved
     * byte), and a BitMask mode's span runs over its
     * reserved mask too. Reckoning from the colors alone
     * reads a 32-bit screen as 24, and that is exactly
     * what milestone 22's first proof did: the loader
     * handed the kernel "1280 by 800, 24 bits to a
     * pixel", pitch 3840, on a screen whose truth was
     * 32 and 5120, and the kernel's desktop came up
     * squeezed and tiled, three quarters of it painted
     * and the last quarter never touched. GRUB, reading
     * the same firmware's word whole, never erred. */
    if (mode->PixelFormat == PixelBitMask) {
        uint8_t pos, size;
        channel_shape(mode->PixelInformation.ReservedMask,
                      &pos, &size);
        if (pos + size > top) top = pos + size;
    } else {
        top = 32; /* the Reserved formats, by definition */
    }
    uint32_t bytes = (top + 7) / 8;
    if (bytes != 4 && bytes != 3) return 0;
    *bytesPerPixel = bytes;
    return 1;
}

EFI_STATUS efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *systemTable) {
    gBS = systemTable->BootServices;
    gConOut = systemTable->ConOut;

    speak("\r\nCardnull Bootloader\r\n");
    speak("Cardnull OS behind the UEFI door, loaded by "
          "our own hand.\r\n");

    /* Quiet the firmware's watchdog: the handover takes
     * the time it takes, and no timer should rush it. */
    gBS->SetWatchdogTimer(0, 0, 0, NULL);

    /* ---- The kernel, read off the boot volume. ---- */
    EFI_LOADED_IMAGE_PROTOCOL *loaded = NULL;
    EFI_STATUS status = gBS->HandleProtocol(
        image, &kLoadedImageGuid, (void **)&loaded);
    if (EFI_ERROR(status))
        stop("asking the firmware how this loader was "
             "itself loaded", status);

    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *volume = NULL;
    status = gBS->HandleProtocol(loaded->DeviceHandle,
                                 &kFileSystemGuid,
                                 (void **)&volume);
    if (EFI_ERROR(status))
        stop("opening the boot volume's filesystem", status);

    EFI_FILE_PROTOCOL *root = NULL;
    status = volume->OpenVolume(volume, &root);
    if (EFI_ERROR(status)) stop("opening the boot volume", status);

    EFI_FILE_PROTOCOL *kernelFile = NULL;
    CHAR16 kernelName[] = u"\\BOOT\\KERNEL.BIN";
    status = root->Open(root, &kernelFile, kernelName,
                        EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(status))
        stop("finding KERNEL.BIN on the boot volume", status);

    status = kernelFile->SetPosition(kernelFile,
                                     EFI_FILE_POSITION_END);
    if (EFI_ERROR(status)) stop("standing at the kernel's end",
                                status);
    uint64_t kernelSize = 0;
    status = kernelFile->GetPosition(kernelFile, &kernelSize);
    if (EFI_ERROR(status)) stop("measuring the kernel", status);
    status = kernelFile->SetPosition(kernelFile, 0);
    if (EFI_ERROR(status)) stop("returning to the kernel's start",
                                status);

    uint8_t *kernelBytes = NULL;
    status = gBS->AllocatePool(EfiLoaderDataPool, kernelSize,
                               (void **)&kernelBytes);
    if (EFI_ERROR(status)) stop("making room to read the kernel",
                                status);
    UINTN readWanted = kernelSize;
    status = kernelFile->Read(kernelFile, &readWanted, kernelBytes);
    if (EFI_ERROR(status) || readWanted != kernelSize)
        stop("reading the kernel", status);
    kernelFile->Close(kernelFile);
    root->Close(root);

    speak("The kernel is in hand: ");
    speak_dec(kernelSize);
    speak(" bytes, read from the boot volume.\r\n");

    /* ---- Lay the kernel at its own addresses. ---- */
    Elf64Header *elf = (Elf64Header *)kernelBytes;
    if (kernelSize < sizeof(Elf64Header) || elf->ident[0] != 0x7F ||
        elf->ident[1] != 'E' || elf->ident[2] != 'L' ||
        elf->ident[3] != 'F' || elf->ident[4] != 2 ||
        elf->ident[5] != 1 || elf->machine != ELF_MACHINE_X86_64 ||
        elf->phentsize < sizeof(Elf64Program))
        stop("the kernel's file is not the ELF it should be", 0);

    Elf64Program *programs =
        (Elf64Program *)(kernelBytes + elf->phoff);
    uint64_t spanLow = UINT64_MAX, spanHigh = 0;
    for (int i = 0; i < elf->phnum; i++) {
        if (programs[i].type != ELF_PT_LOAD) continue;
        if (programs[i].paddr < spanLow) spanLow = programs[i].paddr;
        uint64_t end = programs[i].paddr + programs[i].memsz;
        if (end > spanHigh) spanHigh = end;
    }
    if (spanLow == UINT64_MAX || spanHigh <= spanLow)
        stop("the kernel carries nothing to lay down", 0);
    uint64_t claimBase = spanLow & ~0xFFFULL;
    uint64_t claimEnd = (spanHigh + 0xFFFULL) & ~0xFFFULL;
    EFI_PHYSICAL_ADDRESS claim = claimBase;
    status = gBS->AllocatePages(AllocateAddress, EfiLoaderData,
                                (claimEnd - claimBase) / 4096,
                                &claim);
    if (EFI_ERROR(status))
        stop("claiming the kernel's ground at its own address",
             status);
    for (int i = 0; i < elf->phnum; i++) {
        if (programs[i].type != ELF_PT_LOAD) continue;
        uint8_t *dest = (uint8_t *)(UINTN)programs[i].paddr;
        memcpy(dest, kernelBytes + programs[i].offset,
               (size_t)programs[i].filesz);
        if (programs[i].memsz > programs[i].filesz)
            memset(dest + programs[i].filesz, 0,
                   (size_t)(programs[i].memsz - programs[i].filesz));
    }
    uint64_t kernelEntry = elf->entry;
    gBS->FreePool(kernelBytes);

    speak("The kernel stands at 1 MiB, ELF segments laid, "
          "the unwritten zeroed.\r\n");

    /* ---- Choose the screen. ---- */
    EFI_GRAPHICS_OUTPUT_PROTOCOL *graphics = NULL;
    status = gBS->LocateProtocol(&kGraphicsGuid, NULL,
                                 (void **)&graphics);
    if (EFI_ERROR(status))
        stop("asking the firmware for its graphics", status);

    uint32_t currentMode = graphics->Mode->Mode;
    uint32_t chosen = currentMode;
    uint32_t chosenBytes = 0;
    int haveChoice = 0;
    {
        uint32_t bpp = 0;
        if (mode_usable(graphics->Mode->Info, &bpp)) {
            haveChoice = 1;
            chosenBytes = bpp;
        }
    }
    for (uint32_t m = 0; m < graphics->Mode->MaxMode; m++) {
        EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info = NULL;
        UINTN infoSize = 0;
        status = graphics->QueryMode(graphics, m, &infoSize, &info);
        if (EFI_ERROR(status)) continue;
        uint32_t bpp = 0;
        if (mode_usable(info, &bpp)) {
            if (info->HorizontalResolution == 1280 &&
                info->VerticalResolution == 800) {
                chosen = m; /* the desktop's own shape */
                chosenBytes = bpp;
                haveChoice = 1;
                gBS->FreePool(info);
                break;
            }
            if (!haveChoice) {
                chosen = m;
                chosenBytes = bpp;
                haveChoice = 1;
            }
        }
        gBS->FreePool(info);
    }
    if (!haveChoice)
        stop("the firmware offers no screen the kernel can "
             "draw on", 0);
    if (chosen != currentMode) {
        status = graphics->SetMode(graphics, chosen);
        if (EFI_ERROR(status)) stop("setting the screen's mode",
                                    status);
    }
    {
        EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info =
            graphics->Mode->Info;
        uint32_t redMask, greenMask, blueMask;
        if (info->PixelFormat ==
            PixelRedGreenBlueReserved8BitPerColor) {
            redMask = 0x000000FF;
            greenMask = 0x0000FF00;
            blueMask = 0x00FF0000;
        } else if (info->PixelFormat ==
                   PixelBlueGreenRedReserved8BitPerColor) {
            redMask = 0x00FF0000;
            greenMask = 0x0000FF00;
            blueMask = 0x000000FF;
        } else {
            redMask = info->PixelInformation.RedMask;
            greenMask = info->PixelInformation.GreenMask;
            blueMask = info->PixelInformation.BlueMask;
        }
        gFbAddress = graphics->Mode->FrameBufferBase;
        gFbWidth = info->HorizontalResolution;
        gFbHeight = info->VerticalResolution;
        gFbPitch = info->PixelsPerScanLine * chosenBytes;
        gFbBpp = (uint8_t)(chosenBytes * 8);
        channel_shape(redMask, &gFbRedPos, &gFbRedSize);
        channel_shape(greenMask, &gFbGreenPos, &gFbGreenSize);
        channel_shape(blueMask, &gFbBluePos, &gFbBlueSize);
    }

    speak("Screen: ");
    speak_dec(gFbWidth);
    speak(" by ");
    speak_dec(gFbHeight);
    speak(", ");
    speak_dec(gFbBpp);
    speak(" bits to a pixel.\r\n");

    /* ---- The information's keeping, and the map's. ---- */
    EFI_PHYSICAL_ADDRESS infoBase = 0;
    status = gBS->AllocatePages(AllocateAnyPages, EfiLoaderData,
                                INFO_BYTES / 4096, &infoBase);
    if (EFI_ERROR(status))
        stop("making room for the handover's word", status);
    if (infoBase >= 0x100000000ULL)
        stop("the handover's word landed past the kernel's "
             "reach", 0);
    memset((void *)(UINTN)infoBase, 0, INFO_BYTES);

    /* 64 KiB of reading room: some thousands of regions —
     * far more than any machine here has ever confessed. */
    UINTN mapRoom = 65536;
    uint8_t *mapBytes = NULL;
    status = gBS->AllocatePool(EfiLoaderDataPool, mapRoom,
                               (void **)&mapBytes);
    if (EFI_ERROR(status))
        stop("making room to read the machine's memory", status);

    /* ---- The leaving. ----
     * The map is read, the word built from it, and the
     * leaving attempted with that reading's key — in that
     * order, every time, so the map the kernel inherits is
     * the map of the moment it inherits the machine. A
     * failed leaving changes the key; the reading is taken
     * again, and the word rebuilt, as many times as need
     * be within a small patience. */
    int handed = 0;
    for (int attempt = 0; attempt < 8 && !handed; attempt++) {
        UINTN mapSize = mapRoom;
        UINTN mapKey = 0;
        UINTN descriptorSize = 0;
        uint32_t descriptorVersion = 0;
        status = gBS->GetMemoryMap(&mapSize, (EFI_MEMORY_DESCRIPTOR *)mapBytes,
                                   &mapKey, &descriptorSize,
                                   &descriptorVersion);
        if (EFI_ERROR(status))
            stop("reading the machine's memory map", status);
        UINTN regions = build_information(
            (uint8_t *)(UINTN)infoBase, mapBytes, mapSize,
            descriptorSize);
        if (regions == 0)
            stop("the machine's memory will not fit in the "
                 "word kept for it", 0);
        if (attempt == 0) {
            speak("Memory map: ");
            speak_dec(regions);
            speak(" regions, translated from the "
                  "firmware's own.\r\n");
            speak("Handing the machine to Cardnull OS...\r\n");
        }
        status = gBS->ExitBootServices(image, mapKey);
        if (!EFI_ERROR(status)) handed = 1;
    }
    if (!handed)
        stop("leaving the firmware's keeping", status);

    /* The firmware is gone. What remains is the step down
     * and the jump — the trampoline's whole work. */
    cardnull_enter_kernel((uint32_t)infoBase,
                          (uint32_t)kernelEntry);
    rest();
    return EFI_SUCCESS;
}
