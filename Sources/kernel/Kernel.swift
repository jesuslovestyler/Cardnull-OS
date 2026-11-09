// Cardnull OS — the kernel.
//
// This file is the kernel proper: the function the boot floor calls once
// the processor is awake, its page tables are set, and control passes
// from the thin assembly floor into Swift.
//
// It is written in Embedded Swift — Swift compiled freestanding, with no
// operating system beneath it and no standard library beyond what can
// live on bare metal. Nothing is imported; there is nothing to import
// from yet.
//
// Written in Swift, in the open, in the public domain.

/// Provided by the boot floor (boot.S): stops the processor with `hlt`,
/// forever. The floor falls into it should `kmain` ever return; while
/// the kernel lives, it is not called.
@_silgen_name("cardnull_halt")
func cardnullHalt() -> Never

/// Provided by the boot floor (support.c): reads one byte from a
/// processor I/O port. Swift cannot emit the `in` instruction, so the
/// floor lends it this hand — the same arrangement as the VGA buffer,
/// where the kernel writes hardware memory through a raw pointer.
@_silgen_name("cardnull_inb")
func cardnullInb(_ port: UInt16) -> UInt8

/// Provided by the boot floor (support.c): writes one byte to a
/// processor I/O port — the `out` instruction, lent the same way.
@_silgen_name("cardnull_outb")
func cardnullOutb(_ port: UInt16, _ value: UInt8)

/// Provided by the boot floor (support.c): reads one double-word
/// from a processor I/O port — milestone 8's widening of the
/// hands above, for PCI configuration space, which speaks a full
/// 32 bits at a time. The disc controller is found there; its own
/// registers are memory-mapped and need no hand at all.
@_silgen_name("cardnull_inl")
func cardnullInl(_ port: UInt16) -> UInt32

/// Provided by the boot floor (support.c): writes one double-word
/// to a processor I/O port — the companion of the read above.
@_silgen_name("cardnull_outl")
func cardnullOutl(_ port: UInt16, _ value: UInt32)

/// Provided by the boot floor (support.c): raises the whole interrupt
/// machinery of milestone 4 — builds the IDT from the assembly stub
/// table, remaps the PIC pair to vectors 0x20/0x28, sets the PIT
/// ticking at 100 Hz, drains the keyboard controller, and opens the
/// interrupt gate (sti). Called once, before the shell's first sleep.
@_silgen_name("cardnull_setup_interrupts")
func cardnullSetupInterrupts()

/// Provided by the boot floor (support.c): one honest sleep — `hlt`
/// until the next interrupt arrives, then return. The shell loop
/// rests here between keystrokes instead of spinning on the ports.
@_silgen_name("cardnull_hlt_once")
func cardnullHltOnce()

/// Provided by the boot floor (support.c): closes the interrupt gate
/// (cli) and keeps it closed. The exception handler calls this before
/// its last words, so nothing can interrupt a halt.
@_silgen_name("cardnull_cli")
func cardnullCli()

/// Provided by the boot floor (support.c): the raw storage of the
/// keyboard ring buffer — 64 bytes the floor lends, because Embedded
/// Swift cannot name a fixed mutable byte array without a heap. Every
/// decision about those bytes is the kernel's, below; the floor only
/// keeps the memory.
@_silgen_name("cardnull_key_ring")
func cardnullKeyRing() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the raw storage of the
/// screen's character grid — 80 x 25 bytes the floor lends, for the
/// same reason as the key ring. Milestones 1-4 kept the characters
/// in the VGA text buffer itself and read typed lines back out of
/// the hardware; the framebuffer screen of milestone 5 holds pixels,
/// not letters, so the kernel keeps the grid itself now, and every
/// screen behind the one door reads and paints from it.
@_silgen_name("cardnull_text_grid")
func cardnullTextGrid() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the raw storage of the
/// mouse ring buffer — 256 bytes the floor lends, for the same
/// reason as the key ring. Milestone 12's IRQ12 handler fills it
/// one byte at a time; the graphical face drains it at its leisure
/// and makes packets of the bytes. Every decision about the bytes
/// is the kernel's, below; the floor only keeps the memory.
@_silgen_name("cardnull_mouse_ring")
func cardnullMouseRing() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the pointer's cushion —
/// 32 x 32 raw pixel words the floor lends. Before the face draws
/// its pointer it lifts the pixels underneath into this cushion,
/// and when the pointer moves or goes home it lays them back, so
/// the pointer never leaves a trail across the desktop. What the
/// words hold — one framebuffer pixel each, in the screen's own
/// packing — is the kernel's business, below.
@_silgen_name("cardnull_gui_cushion")
func cardnullGuiCushion() -> UnsafeMutablePointer<UInt32>

/// Provided by the boot floor (font8x8.c): the 8x8 bitmap font the
/// framebuffer backend draws letters from — 128 glyphs of 8 bytes,
/// one byte per row, bit 0 the leftmost pixel. Daniel Hepper's
/// font8x8_basic, drawn from the public-domain IBM VGA fonts and
/// public domain itself, as everything here is.
@_silgen_name("cardnull_font8x8")
func cardnullFont8x8() -> UnsafePointer<UInt8>

/// Provided by the boot floor (support.c): the raw storage of the
/// frame allocator's bitmap — 128 KiB of bits, one per 4 KiB frame,
/// covering the first 4 GiB of the machine. The floor lends the
/// memory for the same reason it lends the key ring and the text
/// grid; which frames exist and which are free is the kernel's
/// business, in the memory section below.
@_silgen_name("cardnull_frame_bitmap")
func cardnullFrameBitmap() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the kernel image's own
/// first address, as the linker script named it. The allocator
/// reserves the whole image — code, data, page tables, stack — so
/// it never hands out the ground the kernel is standing on.
@_silgen_name("cardnull_kernel_start")
func cardnullKernelStart() -> UInt64

/// The companion bound: one past the kernel image's last byte.
@_silgen_name("cardnull_kernel_end")
func cardnullKernelEnd() -> UInt64

/// Provided by the boot floor (support.c): raises EFER's NXE bit,
/// the switch that makes the no-execute bit in a page entry law
/// instead of a reserved-bit fault. Milestone 7 calls it once,
/// just before loading its own page tables — the tables carrying
/// NX bits must never be walked before this stands.
@_silgen_name("cardnull_enable_nxe")
func cardnullEnableNxe()

/// Provided by the boot floor (support.c): loads CR3 — points the
/// processor at a new set of page tables. The write flushes the
/// translation caches, so the very next instruction already walks
/// the new tables.
@_silgen_name("cardnull_load_cr3")
func cardnullLoadCr3(_ root: UInt64)

/// Provided by the boot floor (support.c): forgets one page's
/// cached translation (`invlpg`). Milestone 8's disc driver maps
/// its controller's registers into the standing tables — pages
/// that were absent a moment ago — and the processor must be
/// told to look again rather than trust the remembered absence.
@_silgen_name("cardnull_invlpg")
func cardnullInvlpg(_ address: UInt64)

/// Provided by the boot floor (support.c): the kernel image's text
/// span, as the linker script named it. Milestone 7's page tables
/// mark these pages executable and not writable — the W of W^X.
@_silgen_name("cardnull_text_start")
func cardnullTextStart() -> UInt64

/// The companion bound: one past the text span's last byte.
@_silgen_name("cardnull_text_end")
func cardnullTextEnd() -> UInt64

/// Provided by the boot floor (support.c): the kernel image's
/// read-only span, as the linker script named it — neither writable
/// nor executable in the kernel's own tables.
@_silgen_name("cardnull_rodata_start")
func cardnullRodataStart() -> UInt64

/// The companion bound: one past the read-only span's last byte.
@_silgen_name("cardnull_rodata_end")
func cardnullRodataEnd() -> UInt64

/// Provided by the boot floor (support.c): raises milestone 9's
/// ring-3 furniture — a task state segment whose ring-0 stack
/// pointer names a stack of the kernel's own, its descriptor
/// written into the GDT slot boot.S left empty, and the task
/// register loaded. Called once from kmain *before* the kernel's
/// own page tables are built: the GDT sits in read-only data, and
/// only the floor's borrowed map still lets it be written.
@_silgen_name("cardnull_setup_user_mode")
func cardnullSetupUserMode()

/// Provided by the boot floor (boot.S): the going-out hand of
/// milestone 9. Moves the machine onto the given page tables and
/// enters the guest at its entry address in ring 3, with the
/// given stack top. Returns only when the guest has left — by
/// its exit service, with its exit code, or by abandonment, with
/// the verdict the fault handler handed the floor.
@_silgen_name("cardnull_launch_program")
func cardnullLaunchProgram(_ tables: UInt64, _ entry: UInt64,
                           _ stackTop: UInt64) -> UInt64

/// Provided by the boot floor (boot.S): the other way home. Called
/// from the page-fault handler when a guest has faulted in its own
/// mode: the floor restores the kernel's tables and the shell's
/// stack and returns the verdict to the launch hand's caller, as
/// if the guest had exited with it. Never returns here.
@_silgen_name("cardnull_abandon_program")
func cardnullAbandonProgram(_ verdict: UInt64) -> Never

/// Provided by the boot floor (boot.S): milestone 10's going-out
/// hand for two guests. Bookmarks home exactly as the single
/// launch does, writes each guest's whole state into one of the
/// floor's two guest books — its tables, its entry, its stack,
/// its flags, every other word wiped clean — and enters guest A.
/// From there the guests trade the machine by the door's yield
/// service until both have left or been stopped; only then does
/// this hand return, carrying guest A's verdict. Guest B's
/// verdict and the two standings wait in the floor's result
/// bookmarks, read out by the three hands below.
@_silgen_name("cardnull_launch_pair")
func cardnullLaunchPair(_ tablesA: UInt64, _ entryA: UInt64,
                        _ stackTopA: UInt64, _ tablesB: UInt64,
                        _ entryB: UInt64, _ stackTopB: UInt64) -> UInt64

/// Provided by the boot floor (boot.S): the pair's fault road.
/// Called from the page-fault handler when a guest has faulted
/// while a partner lives: the floor writes the fallen guest down
/// as stopped, with the verdict the handler named, and takes the
/// machine to the survivor — or home, if the survivor is finished
/// too. Never returns here.
@_silgen_name("cardnull_abandon_guest_in_pair")
func cardnullAbandonGuestInPair(_ verdict: UInt64) -> Never

/// Provided by the boot floor (boot.S): guest B's verdict from
/// the last pair session, read out of the floor's result
/// bookmarks after the pair launch has returned.
@_silgen_name("cardnull_pair_verdict_b")
func cardnullPairVerdictB() -> UInt64

/// Provided by the boot floor (boot.S): guest A's standing from
/// the last pair session — 1 when it left by the door, 2 when it
/// was stopped — read out of the floor's result bookmarks.
@_silgen_name("cardnull_pair_status_a")
func cardnullPairStatusA() -> UInt64

/// Provided by the boot floor (boot.S): guest B's standing from
/// the last pair session, the companion to the hand above.
@_silgen_name("cardnull_pair_status_b")
func cardnullPairStatusB() -> UInt64

/// The kernel's first word, spoken by milestone 1 and kept on screen
/// by every milestone after it.
///
/// A StaticString, not a String: Embedded Swift has no heap and no
/// String type yet, so the banner lives in the kernel's read-only data
/// as raw UTF-8 bytes — which is all the screen needs from it.
public let cardnullBanner: StaticString = "CARDNULL"

// ---------------------------------------------------------------------------
// The screen.
//
// Two doors, one room (milestone 5). Behind the BIOS door the screen
// is the PC text grid: a memory-mapped array at physical address
// 0xB8000, 80 columns x 25 rows, two bytes per cell — the character,
// then its attribute (color). Behind the UEFI door there is no text
// grid at all: the firmware's graphics protocol hands over a linear
// framebuffer, a field of pixels, and letters must be drawn into it
// glyph by glyph from the floor's bitmap font.
//
// The kernel therefore keeps the characters itself now, in a grid
// the floor lends, and paints that grid through whichever screen is
// live. The choice is made once, at boot, from the Multiboot2
// information the floor preserved: a usable direct-color framebuffer
// tag means the framebuffer is the screen; otherwise the VGA text
// grid is. Everything above this layer — the echo, the scrolling,
// the shell reading its typed lines back — reads the kernel's grid
// and neither knows nor cares which door the machine came through.
//
// Milestone 1 wrote the banner and rested; milestone 2 kept a small
// conversation with the grid. Milestone 3 made it a true terminal:
// one door for all output (typed echo and the shell's answers walk
// through the same writeChar), and when the last row fills, the
// whole page lifts — scrolling, the way every terminal since the
// teletype has made room for the next line.
// ---------------------------------------------------------------------------

/// The screen's shape, named once so the code below reads plainly.
let screenColumns = 80
let screenRows = 25

/// White letters (0xF) on a black field (0x0) — milestone 1's colors,
/// kept for everything the kernel writes.
let textAttribute: UInt8 = 0x0F

/// The typing area starts two rows under the banner: row 0 holds
/// CARDNULL, row 1 is breathing room, typing begins at row 2.
let typingTopRow = 2

/// Where the next written character will land.
var cursorRow = typingTopRow
var cursorCol = 0

/// Where the current input line began: the row of its prompt, and the
/// column just past it. Backspace never eats past this point, so a
/// prompt — and the banner above the typing area — cannot be erased.
/// When scrolling lifts the page, this mark rides up with the line it
/// belongs to; if the line's own first row lifts off the top of the
/// screen, the mark falls to column 0 of the top row, where the line's
/// continuation now lives.
var lineStartRow = typingTopRow
var lineStartCol = 2

// ---------------------------------------------------------------------------
// Which screen is live, and the framebuffer's shape when it is.
//
// The boot floor preserved EBX: the address of the Multiboot2
// information structure GRUB built. It is a row of tags; the
// framebuffer tag (type 8) names the pixel field GRUB set up for us
// — its address, the bytes in one row of it (the pitch, which may
// pad past the visible width), its width and height in pixels, its
// depth, and where the red, green, and blue fields sit inside each
// pixel. The header asked for no particular mode; what GRUB
// actually set is what the tag says, and the kernel believes the
// tag, not the request.
// ---------------------------------------------------------------------------

/// True when the framebuffer is the screen (the UEFI door, or a BIOS
/// boot where GRUB set a graphics mode); false for the VGA text grid.
var useFramebuffer = false

/// The framebuffer's facts, read from the tag. The address is a
/// physical address inside the floor's 4 GiB identity map.
var framebufferAddress: UInt64 = 0
var framebufferPitch = 0
var framebufferWidth = 0
var framebufferHeight = 0
var framebufferBpp = 0

/// White, packed in the mode's own channel fields — each channel at
/// its full brightness, wherever the mode keeps it. Black is 0 in
/// any packing, so only white needs reckoning.
var framebufferWhite: UInt32 = 0

/// The framebuffer's channel layout, remembered from the tag:
/// where the red, green, and blue fields sit inside a pixel and
/// how wide each is. Milestone 5 needed only white and black,
/// which any packing renders the same; milestone 12's face paints
/// in colour, and colour must be packed in the mode's own fields
/// or it comes out as some other colour entirely. All six are 0
/// until a framebuffer is chosen.
var framebufferRedPosition = 0
var framebufferRedSize = 0
var framebufferGreenPosition = 0
var framebufferGreenSize = 0
var framebufferBluePosition = 0
var framebufferBlueSize = 0

/// The glyph magnification: 2 when the pixel field is roomy enough
/// (a cell becomes 16x16 pixels, near the text grid's own stature),
/// else 1 (8x8 cells, small but honest).
var glyphScale = 1

/// Little-endian readers for the boot information's raw bytes.
@inline(__always)
func bootInfoU32(_ base: UnsafeMutablePointer<UInt8>, _ offset: Int) -> UInt32 {
    UInt32(base[offset])
        | UInt32(base[offset + 1]) << 8
        | UInt32(base[offset + 2]) << 16
        | UInt32(base[offset + 3]) << 24
}

@inline(__always)
func bootInfoU64(_ base: UnsafeMutablePointer<UInt8>, _ offset: Int) -> UInt64 {
    UInt64(bootInfoU32(base, offset)) | UInt64(bootInfoU32(base, offset + 4)) << 32
}

/// Reads one channel's full-brightness contribution to the packed
/// white pixel: its field filled with ones, shifted to its place.
@inline(__always)
func channelWhite(_ position: UInt8, _ size: UInt8) -> UInt32 {
    if size == 0 { return 0 }
    if size >= 32 { return UInt32.max }
    return ((UInt32(1) << UInt32(size)) - 1) << UInt32(position)
}

/// Walks the Multiboot2 information tags and chooses the screen. A
/// direct-color (RGB) framebuffer of 24 or 32 bits per pixel, large
/// enough to hold the 80x25 grid of 8x8 glyphs, becomes the screen;
/// anything else — no tag, an indexed palette, a postage stamp —
/// leaves the VGA text grid in charge, exactly as milestones 1-4
/// found it.
func chooseScreen(infoAddress: UInt64) {
    if infoAddress == 0 { return }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let totalSize = Int(bootInfoU32(base, 0))
    var offset = 8
    while offset + 8 <= totalSize {
        let type = bootInfoU32(base, offset)
        let size = Int(bootInfoU32(base, offset + 4))
        if type == 0 || size < 8 { break }
        if type == 8 && size >= 38 {
            let address = bootInfoU64(base, offset + 8)
            let pitch = bootInfoU32(base, offset + 16)
            let width = bootInfoU32(base, offset + 20)
            let height = bootInfoU32(base, offset + 24)
            let bpp = base[offset + 28]
            let colorType = base[offset + 29]
            if address != 0 && colorType == 1 && (bpp == 32 || bpp == 24)
                && width >= UInt32(screenColumns * 8)
                && height >= UInt32(screenRows * 8) {
                framebufferAddress = address
                framebufferPitch = Int(pitch)
                framebufferWidth = Int(width)
                framebufferHeight = Int(height)
                framebufferBpp = Int(bpp)
                // The channel fields begin after a TWO-byte reserved
                // field (offsets 30-31) — the spec's quiet trap, and
                // the one this kernel fell into first: read a byte
                // early and red is reckoned from the reserved zero,
                // painting the whole screen cyan. Red at 32, green
                // at 34, blue at 36, each a position and a size.
                framebufferWhite =
                    channelWhite(base[offset + 32], base[offset + 33])
                    | channelWhite(base[offset + 34], base[offset + 35])
                    | channelWhite(base[offset + 36], base[offset + 37])
                framebufferRedPosition = Int(base[offset + 32])
                framebufferRedSize = Int(base[offset + 33])
                framebufferGreenPosition = Int(base[offset + 34])
                framebufferGreenSize = Int(base[offset + 35])
                framebufferBluePosition = Int(base[offset + 36])
                framebufferBlueSize = Int(base[offset + 37])
                useFramebuffer = true
            }
        }
        offset += (size + 7) & ~7
    }
    if useFramebuffer {
        glyphScale = framebufferWidth >= screenColumns * 16
            && framebufferHeight >= screenRows * 16 ? 2 : 1
    }
}

// ---------------------------------------------------------------------------
// Painting: the grid the kernel keeps, drawn through the live screen.
// ---------------------------------------------------------------------------

/// Reads back one character of the grid the kernel keeps. The shell
/// reads the typed line straight off this grid — what the typist
/// sees is literally what the kernel obeys, and no separate line
/// buffer exists to disagree with it.
@inline(__always)
func screenChar(cell offset: Int) -> UInt8 {
    cardnullTextGrid()[offset]
}

/// Writes one pixel of the framebuffer: white or black, at the
/// mode's own depth. At 24 bits the three channel bytes are simply
/// all-on or all-off — for pure white and pure black, the order of
/// the channels cannot matter, so no packing is needed there.
@inline(__always)
func putPixel(x: Int, y: Int, white on: Bool) {
    let rowStart = framebufferAddress + UInt64(y * framebufferPitch)
    if framebufferBpp == 32 {
        let pixel = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(rowStart + UInt64(x * 4)))!
        pixel.pointee = on ? framebufferWhite : 0
    } else {
        let pixel = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(rowStart + UInt64(x * 3)))!
        let value: UInt8 = on ? 0xFF : 0x00
        pixel[0] = value
        pixel[1] = value
        pixel[2] = value
    }
}

/// Draws one grid cell into the framebuffer: the glyph the grid
/// holds there, white on black, magnified by the glyph scale. The
/// cursor, when asked for, is an honest underline — the cell's
/// bottom two glyph rows lit solid, the way terminals have always
/// marked the place where the next letter lands.
func paintCellFramebuffer(row: Int, col: Int, underline: Bool) {
    let glyph = Int(screenChar(cell: row * screenColumns + col) & 0x7F)
    let font = cardnullFont8x8()
    let originX = col * 8 * glyphScale
    let originY = row * 8 * glyphScale
    for glyphY in 0 ..< 8 {
        let bits = font[glyph * 8 + glyphY]
        for glyphX in 0 ..< 8 {
            var on = bits & (UInt8(1) << UInt8(glyphX)) != 0
            if underline && glyphY >= 6 { on = true }
            for stepX in 0 ..< glyphScale {
                for stepY in 0 ..< glyphScale {
                    putPixel(x: originX + glyphX * glyphScale + stepX,
                             y: originY + glyphY * glyphScale + stepY,
                             white: on)
                }
            }
        }
    }
}

/// Paints one grid cell through whichever screen is live: a word
/// written into the VGA text buffer, or a glyph drawn into the
/// framebuffer. No cursor mark — the cursor is moveHardwareCursor's
/// affair.
func paintCell(row: Int, col: Int) {
    if useFramebuffer {
        paintCellFramebuffer(row: row, col: col, underline: false)
    } else {
        let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
        buffer[row * screenColumns + col] =
            UInt16(textAttribute) << 8
            | UInt16(screenChar(cell: row * screenColumns + col))
    }
}

/// Paints the whole grid, cell by cell. Scrolling and clearing both
/// end here: the grid is the truth, and the screen is made to match
/// it, so the two can never drift apart.
func repaintScreen() {
    for row in 0 ..< screenRows {
        for col in 0 ..< screenColumns {
            paintCell(row: row, col: col)
        }
    }
    framebufferCursorRow = -1
    framebufferCursorCol = -1
}

/// Writes one character into the grid and paints the cell it lands
/// in — the single act every screen change in the kernel is built
/// from, through either door.
@inline(__always)
func putCell(row: Int, col: Int, character: UInt8) {
    cardnullTextGrid()[row * screenColumns + col] = character
    paintCell(row: row, col: col)
}

/// Where the framebuffer cursor's underline is currently drawn, or
/// -1 when it is nowhere (after a repaint, before its first move).
/// The VGA text screen has its own hardware cursor and needs no
/// such bookkeeping.
var framebufferCursorRow = -1
var framebufferCursorCol = -1

/// Moves the screen's own blinking cursor to the typing position, so
/// the eye can see where the next letter will land. In the text grid
/// the cursor's address lives in the display controller, spoken to
/// through ports 0x3D4 (which register) and 0x3D5 (its value):
/// register 0x0F takes the low byte of the cell offset, 0x0E the
/// high byte. In the framebuffer there is no hardware cursor, so
/// the kernel draws its own: the old cell repainted plain, the new
/// cell repainted with its underline.
func moveHardwareCursor() {
    if useFramebuffer {
        if framebufferCursorRow == cursorRow
            && framebufferCursorCol == cursorCol { return }
        if framebufferCursorRow >= 0 {
            paintCellFramebuffer(row: framebufferCursorRow,
                                 col: framebufferCursorCol, underline: false)
        }
        paintCellFramebuffer(row: cursorRow, col: cursorCol, underline: true)
        framebufferCursorRow = cursorRow
        framebufferCursorCol = cursorCol
        return
    }
    let position = cursorRow * screenColumns + cursorCol
    cardnullOutb(0x3D4, 0x0F)
    cardnullOutb(0x3D5, UInt8(truncatingIfNeeded: position))
    cardnullOutb(0x3D4, 0x0E)
    cardnullOutb(0x3D5, UInt8(truncatingIfNeeded: position >> 8))
}

/// Lifts the whole page by one row: every row of the grid takes the
/// row beneath it, the last row is wiped clean for whatever comes
/// next, and the screen is repainted from the grid. The banner
/// scrolls away with everything else when the conversation outgrows
/// one screen — a real terminal keeps no favorites.
func scrollUp() {
    let grid = cardnullTextGrid()
    for row in 1 ..< screenRows {
        for col in 0 ..< screenColumns {
            grid[(row - 1) * screenColumns + col] =
                grid[row * screenColumns + col]
        }
    }
    for col in 0 ..< screenColumns {
        grid[(screenRows - 1) * screenColumns + col] = 0x20
    }
    if lineStartRow > 0 {
        lineStartRow -= 1
    } else {
        lineStartCol = 0
    }
    repaintScreen()
}

/// Writes one character at the cursor and advances — the kernel's one
/// door for output, used by the echo of a keystroke and by the shell's
/// answers alike. Advancing off the right edge wraps to the next row;
/// advancing off the bottom of the screen scrolls the page up and the
/// writing continues on the fresh last row.
func writeChar(_ character: UInt8) {
    putCell(row: cursorRow, col: cursorCol, character: character)
    cursorCol += 1
    if cursorCol == screenColumns {
        cursorCol = 0
        cursorRow += 1
        if cursorRow == screenRows {
            scrollUp()
            cursorRow = screenRows - 1
        }
    }
}

/// Steps to the start of the next row, scrolling if the screen is
/// full. Output and prompts both begin a line this way.
func writeNewline() {
    cursorCol = 0
    cursorRow += 1
    if cursorRow == screenRows {
        scrollUp()
        cursorRow = screenRows - 1
    }
}

/// Writes a whole static string, byte by byte, through writeChar.
func writeStatic(_ text: StaticString) {
    var index = 0
    while true {
        let character = text.utf8Start[index]
        if character == 0 { break }
        writeChar(character)
        index += 1
    }
}

/// Writes a static string and steps to a fresh row beneath it.
func writeLine(_ text: StaticString) {
    writeStatic(text)
    writeNewline()
}

/// Opens a fresh input line at the cursor's row: writes the "> "
/// prompt and remembers where this line's typing began, so backspace
/// knows its limit, and so the shell knows which bytes on the screen
/// are the command. The cursor must be at column 0 on entry.
func startLine() {
    putCell(row: cursorRow, col: 0, character: 0x3E)   // '>'
    putCell(row: cursorRow, col: 1, character: 0x20)   // ' '
    cursorCol = 2
    lineStartRow = cursorRow
    lineStartCol = 2
}

/// Backspace: take back the last character typed, and only ever a
/// typed character — never the prompt, never the banner. With
/// scrolling, there is always room to step back into: a cursor at the
/// start of a row steps up to the last cell of the row above, which
/// is where a wrapped line left its previous character.
func backspace() {
    if cursorRow == lineStartRow && cursorCol == lineStartCol { return }
    if cursorCol == 0 {
        if cursorRow <= lineStartRow { return }
        cursorRow -= 1
        cursorCol = screenColumns - 1
    } else {
        cursorCol -= 1
    }
    putCell(row: cursorRow, col: cursorCol, character: 0x20)
}

// ---------------------------------------------------------------------------
// The keyboard.
//
// What a key *means* is decided here: the translation of scancodes
// into characters. How a scancode *arrives* changed with milestone 4
// — it comes by interrupt now, through the ring buffer in the next
// section — but the meaning of each code is exactly what milestones 2
// and 3 taught the kernel, and it lives here unchanged.
//
// The controller speaks through two ports:
//
//   0x64  status: its lowest bit is set while a byte waits.
//   0x60  data:   the byte itself — a scancode, set 1.
//
// A key press sends its *make* code; a release sends the same code
// with the top bit set (the *break* code). Shift is tracked by hand:
// its makes set the flag, its breaks clear it. Caps Lock is a toggle:
// each press flips it, and it joins with Shift the way typewriters
// taught us — a letter is capital when exactly one of them is active.
// Milestone 3 completed the typewriter: every punctuation key of the
// main block, plain and shifted, joins the letters, digits, and space
// that milestone 2 took.
// ---------------------------------------------------------------------------

/// The keyboard controller's data door — the port the IRQ1 handler
/// takes each scancode from. (The status port, 0x64, belonged to the
/// polling years; nothing reads it now but the floor's one drain
/// before the interrupt gate opens.)
let keyboardDataPort: UInt16 = 0x60

/// Is either Shift key currently held?
var shiftHeld = false

/// Is Caps Lock latched on?
var capsLock = false

/// True after a 0xE0 byte: extended keys (the keypad's Enter, the
/// arrow keys, ...) announce themselves with that prefix and a second
/// code. The kernel has no work for them yet, so the second code is
/// swallowed whole rather than mistaken for an ordinary key.
var extendedPrefix = false

/// The letter rows of the keyboard, in scancode order, as raw bytes.
let topRowLetters: StaticString = "qwertyuiop"     // codes 0x10 ... 0x19
let homeRowLetters: StaticString = "asdfghjkl"     // codes 0x1E ... 0x26
let bottomRowLetters: StaticString = "zxcvbnm"     // codes 0x2C ... 0x32

/// The digit row, plain and shifted, in scancode order (0x02 ... 0x0B).
let digitRow: StaticString = "1234567890"
let digitRowShifted: StaticString = "!@#$%^&*()"

/// One letter from a row table. It is capital when exactly one of
/// Shift and Caps Lock is active — the two cancel, as on a real
/// typewriter's descendant, every modern keyboard.
func letter(from table: StaticString, at index: Int) -> UInt8 {
    var character = table.utf8Start[index]
    if shiftHeld != capsLock && character >= 0x61 && character <= 0x7A {
        character -= 0x20   // a ... z -> A ... Z
    }
    return character
}

/// One punctuation key's two faces: the plain character, or the
/// shifted one while Shift is held. Caps Lock does not touch these —
/// it belongs to the letters alone.
@inline(__always)
func punctuated(_ plain: UInt8, _ shifted: UInt8) -> UInt8 {
    shiftHeld ? shifted : plain
}

/// Translates a scancode set 1 make code to the character it types,
/// or 0 for a key the kernel does not take. Milestone 3's alphabet is
/// the whole main block of a US keyboard: letters, digits, space, and
/// every punctuation key, each in its plain and shifted face.
func ascii(forScancode code: UInt8) -> UInt8 {
    switch code {
    case 0x02 ... 0x0B:
        let index = Int(code - 0x02)
        return shiftHeld ? digitRowShifted.utf8Start[index]
                         : digitRow.utf8Start[index]
    case 0x0C:
        return punctuated(0x2D, 0x5F)   // - and _
    case 0x0D:
        return punctuated(0x3D, 0x2B)   // = and +
    case 0x10 ... 0x19:
        return letter(from: topRowLetters, at: Int(code - 0x10))
    case 0x1A:
        return punctuated(0x5B, 0x7B)   // [ and {
    case 0x1B:
        return punctuated(0x5D, 0x7D)   // ] and }
    case 0x1E ... 0x26:
        return letter(from: homeRowLetters, at: Int(code - 0x1E))
    case 0x27:
        return punctuated(0x3B, 0x3A)   // ; and :
    case 0x28:
        return punctuated(0x27, 0x22)   // ' and "
    case 0x29:
        return punctuated(0x60, 0x7E)   // ` and ~
    case 0x2B:
        return punctuated(0x5C, 0x7C)   // \ and |
    case 0x2C ... 0x32:
        return letter(from: bottomRowLetters, at: Int(code - 0x2C))
    case 0x33:
        return punctuated(0x2C, 0x3C)   // , and <
    case 0x34:
        return punctuated(0x2E, 0x3E)   // . and >
    case 0x35:
        return punctuated(0x2F, 0x3F)   // / and ?
    case 0x39:
        return 0x20   // space
    default:
        return 0
    }
}

// ---------------------------------------------------------------------------
// Interrupts (milestone 4).
//
// Until now the kernel asked; now it is told. The floor has built an
// IDT, moved the PIC pair to vectors 0x20/0x28 where they no longer
// collide with the exceptions, and set the PIT ticking at 100 Hz.
// Two interrupts does the kernel take, and a third company it keeps
// against its will:
//
//   IRQ0  the timer: the machine's heartbeat, counted and nothing
//         more — everything time means is reckoned from the count,
//         outside the handler.
//   IRQ1  the keyboard: the handler takes the scancode out of the
//         controller and lays it in a small ring buffer, and the
//         shell drains the ring at its leisure through the same
//         handleScancode the polling years used.
//   IRQ12 the mouse (milestone 12): the handler takes one byte —
//         a third of a packet — out of the same controller and
//         lays it in the mouse's own ring; the graphical face
//         drains that ring and makes packets of the bytes. It
//         lives on the slave PIC, so its thanks are owed twice:
//         to the slave first, then to the master it hangs from.
//   0-31  the exceptions: a stub per vector, all ending here, in a
//         handler that prints one plain line and halts — a fault is
//         spoken aloud, never a silent triple fault in the dark.
//
// A handler's law in this kernel: touch only static state, do little,
// and always thank the PIC — an interrupt not acknowledged is the
// last one the machine will ever deliver.
// ---------------------------------------------------------------------------

/// The master PIC's command port. IRQ0 and IRQ1 both live on the
/// master, so both handlers send their thanks here; the word 0x20 is
/// the EOI command. (That it equals the port's number is a small
/// coincidence of the old design, nothing more.)
let picCommandPort: UInt16 = 0x20
let picEOI: UInt8 = 0x20

/// The heartbeat's count: ticks since boot, one per timer interrupt,
/// a hundred to the second. Written by the timer handler alone; read
/// by the uptime command. Everything time means in Cardnull OS today
/// is this one honest number.
var ticks: UInt64 = 0

/// IRQ0's whole work: count the tick, thank the PIC. Nothing else
/// happens in here — scheduling, sleeping, and everything yet
/// unbuilt will read the count from outside, at their leisure.
@_cdecl("cardnull_timer_interrupt")
public func timerInterrupt() {
    ticks &+= 1
    cardnullOutb(picCommandPort, picEOI)
}

/// The keyboard ring's shape: 64 slots, the number agreed with the
/// floor's storage in support.c. A power of two, so the wrap is a
/// mask, not a division.
let keyRingSize = 64

/// The ring's two hands. The keyboard handler fills at the head; the
/// shell drains at the tail. One slot is always left empty, so head
/// meeting tail unambiguously means "nothing waiting".
var keyRingHead = 0
var keyRingTail = 0

/// IRQ1's whole work: take the scancode out of the controller — the
/// read itself is what clears the controller to speak again — lay it
/// in the ring if there is room (if the ring is full, the byte is
/// let go; fingers are slower than this kernel, and a dropped
/// keystroke beats a wedged one), and thank the PIC.
@_cdecl("cardnull_keyboard_interrupt")
public func keyboardInterrupt() {
    let code = cardnullInb(keyboardDataPort)
    let next = (keyRingHead + 1) & (keyRingSize - 1)
    if next != keyRingTail {
        cardnullKeyRing()[keyRingHead] = code
        keyRingHead = next
    }
    cardnullOutb(picCommandPort, picEOI)
}

/// Takes one waiting scancode out of the ring, or nil when the
/// keyboard has said nothing since the last look.
func nextScancode() -> UInt8? {
    if keyRingTail == keyRingHead { return nil }
    let code = cardnullKeyRing()[keyRingTail]
    keyRingTail = (keyRingTail + 1) & (keyRingSize - 1)
    return code
}

/// The slave PIC's command port. IRQ12 lives on the slave, so its
/// handler thanks the slave here — with the same EOI word the
/// master's handlers use — and then thanks the master as well, for
/// the cascade wire the knock arrived on. An interrupt thanked
/// only once, on the wrong chip, is the last one either delivers.
let picSlaveCommandPort: UInt16 = 0xA0

/// The mouse ring's shape: 256 slots, the number agreed with the
/// floor's storage in support.c. A power of two, so the wrap is a
/// mask, not a division.
let mouseRingSize = 256

/// The mouse ring's two hands, kept exactly as the keyboard's are:
/// the handler fills at the head; the face drains at the tail.
var mouseRingHead = 0
var mouseRingTail = 0

/// IRQ12's whole work: take the byte out of the controller — the
/// read itself is what clears the controller to speak again — lay
/// it in the mouse ring if there is room (a full ring lets the
/// byte go; a pointer's old news is not worth wedging the machine
/// for), and thank both PICs, the slave first and then the master.
/// What the byte means — which third of which packet — is the
/// face's business, below; the handler keeps no such company.
@_cdecl("cardnull_mouse_interrupt")
public func mouseInterrupt() {
    let byte = cardnullInb(keyboardDataPort)
    let next = (mouseRingHead + 1) & (mouseRingSize - 1)
    if next != mouseRingTail {
        cardnullMouseRing()[mouseRingHead] = byte
        mouseRingHead = next
    }
    cardnullOutb(picSlaveCommandPort, picEOI)
    cardnullOutb(picCommandPort, picEOI)
}

/// Takes one waiting byte out of the mouse ring, or nil when the
/// mouse has said nothing since the last look.
func nextMouseByte() -> UInt8? {
    if mouseRingTail == mouseRingHead { return nil }
    let byte = cardnullMouseRing()[mouseRingTail]
    mouseRingTail = (mouseRingTail + 1) & (mouseRingSize - 1)
    return byte
}

/// The exceptions' one answer. A fault leaves no promise standing —
/// not the cursor's bookkeeping, not the screen's story — so the
/// line is written into the top row of the grid, over whatever was
/// there, and painted through whichever screen is live; then the
/// machine rests with its gate closed. No vector number, no register
/// dump: one plain sentence, honestly.
let exceptionLine: StaticString = "Exception - halting."

@_cdecl("cardnull_exception_handler")
public func exceptionHandler(_ vector: UInt64) {
    cardnullCli()
    var index = 0
    while true {
        let character = exceptionLine.utf8Start[index]
        if character == 0 { break }
        putCell(row: 0, col: index, character: character)
        index += 1
    }
    cardnullHalt()
}

// ---------------------------------------------------------------------------
// The page fault's answer (milestone 7).
//
// Vector 14 no longer shares the exceptions' one plain sentence.
// Since the kernel keeps its own page tables, a page fault is a
// report the machine owes in detail: the processor kept the address
// that was reached for in CR2 and a small testimony of the reaching
// in the error code, and the floor's hand-written stub for this one
// vector carries both up. The handler below writes the report into
// the top rows of the grid — over whatever was there, exactly as
// the exception line above does, because a fault leaves no promise
// standing — and then rests the machine with its gate closed: a
// controlled halt, never a reboot loop. Nothing here tries to fix
// the fault and resume; there is nothing yet that could honestly
// be resumed into. That day may come with programs of our own.
// ---------------------------------------------------------------------------

/// Writes a static string into one grid row starting at a column,
/// through putCell like everything drawn after a fault, and
/// returns the column just past its last character.
func writeStaticAt(_ row: Int, _ startCol: Int, _ text: StaticString) -> Int {
    var col = startCol
    var index = 0
    while col < screenColumns {
        let character = text.utf8Start[index]
        if character == 0 { break }
        putCell(row: row, col: col, character: character)
        col += 1
        index += 1
    }
    return col
}

/// Writes a value in hexadecimal into one grid row — addresses and
/// error codes are hex by long custom, and the report speaks them
/// so — with exactly the digits asked for, leading zeros kept.
func writeHexAt(_ row: Int, _ startCol: Int, _ value: UInt64,
                _ digits: Int) -> Int {
    var col = startCol
    var shift = (digits - 1) * 4
    while shift >= 0 && col < screenColumns {
        let nibble = UInt8((value >> UInt64(shift)) & 0xF)
        let character: UInt8 = nibble < 10 ? 0x30 + nibble
                                           : 0x41 + (nibble - 10)
        putCell(row: row, col: col, character: character)
        col += 1
        shift -= 4
    }
    return col
}

/// Writes a value in decimal into one grid row: the digits reckoned
/// by a falling divisor, the same trick writeNumber walks on the
/// shell's road, here onto fixed cells of a report that cannot
/// scroll.
func writeDecimalAt(_ row: Int, _ startCol: Int, _ value: UInt64) -> Int {
    var col = startCol
    var divisor: UInt64 = 1
    while value / divisor >= 10 { divisor *= 10 }
    var remaining = value
    while true {
        if col < screenColumns {
            putCell(row: row, col: col,
                    character: 0x30 + UInt8(remaining / divisor))
            col += 1
        }
        remaining %= divisor
        if divisor == 1 { break }
        divisor /= 10
    }
    return col
}

/// The page fault report's vocabulary: the title and labels, and
/// the error code's testimony taken apart into words — present or
/// not, the kind of reaching, whose mode, and the reserved-bit and
/// instruction-fetch flags when they stand.
let pageFaultTitle: StaticString = "Page fault - halting."
let pageFaultGuestTitle: StaticString =
    "Page fault in a guest program - the guest was stopped."
let pageFaultAddressLabel: StaticString = "  Address: 0x"
let pageFaultErrorLabel: StaticString = "  Error code: 0x"
let pageFaultOpenParen: StaticString = " ("
let pageFaultCloseParen: StaticString = ")"
let pageFaultComma: StaticString = ", "
let reasonNotPresent: StaticString = "page not present"
let reasonProtection: StaticString = "protection violation"
let reasonWrite: StaticString = "write"
let reasonRead: StaticString = "read"
let reasonFetch: StaticString = "instruction fetch"
let reasonUser: StaticString = "user mode"
let reasonSupervisor: StaticString = "supervisor mode"
let reasonReserved: StaticString = "reserved bit set"

/// Vector 14's own handler, called by the floor's hand-written
/// stub with the two facts the processor kept: the error code it
/// pushed and the CR2 address.
///
/// Two roads since milestone 9. The old road — a fault of the
/// kernel's own, in supervisor mode — writes the report and halts,
/// cleanly, with the gate closed, and never returns; faulttest
/// still walks it. The new road is a fault in user mode while a
/// guest program runs: the same report is written under the
/// guest's title, and then, instead of the halt, the floor's
/// abandon hand carries the machine home — the guest is stopped
/// where it stands, and the shell that launched it receives the
/// verdict and answers for it below. A user-mode fault with no
/// guest running keeps the old road: it cannot happen by any road
/// the kernel knows, and honesty halts on it.
///
/// Milestone 10 forks the new road once more: while a pair
/// session stands, the abandon hand is the pair's own, which
/// writes the fallen guest down as stopped and takes the machine
/// to its partner — the report above is the fallen guest's whole
/// obituary, and the survivor runs on in the same session, in its
/// own ground, exactly where it last stood.
@_cdecl("cardnull_page_fault_handler")
public func pageFaultHandler(_ errorCode: UInt64, _ faultAddress: UInt64) {
    cardnullCli()
    if programRunning && errorCode & 0x4 != 0 {
        programFaultAddress = faultAddress
        programFaultError = errorCode
        printPageFaultReport(errorCode, faultAddress, pageFaultGuestTitle)
        if pairRunning {
            cardnullAbandonGuestInPair(programKilledVerdict)
        }
        cardnullAbandonProgram(programKilledVerdict)
    }
    printPageFaultReport(errorCode, faultAddress, pageFaultTitle)
    cardnullHalt()
}

/// The report itself — title, faulting address, error code in hex
/// and in words — written onto fixed rows, because a report is no
/// place for scrolling.
func printPageFaultReport(_ errorCode: UInt64, _ faultAddress: UInt64,
                          _ title: StaticString) {
    _ = writeStaticAt(0, 0, title)
    var col = writeStaticAt(1, 0, pageFaultAddressLabel)
    _ = writeHexAt(1, col, faultAddress, 16)
    col = writeStaticAt(2, 0, pageFaultErrorLabel)
    col = writeHexAt(2, col, errorCode, 4)
    col = writeStaticAt(2, col, pageFaultOpenParen)
    if errorCode & 0x10 != 0 {
        col = writeStaticAt(2, col, reasonFetch)
    } else if errorCode & 0x2 != 0 {
        col = writeStaticAt(2, col, reasonWrite)
    } else {
        col = writeStaticAt(2, col, reasonRead)
    }
    col = writeStaticAt(2, col, pageFaultComma)
    col = writeStaticAt(2, col,
                        errorCode & 0x1 != 0 ? reasonProtection
                                             : reasonNotPresent)
    col = writeStaticAt(2, col, pageFaultComma)
    col = writeStaticAt(2, col,
                        errorCode & 0x4 != 0 ? reasonUser
                                             : reasonSupervisor)
    if errorCode & 0x8 != 0 {
        col = writeStaticAt(2, col, pageFaultComma)
        col = writeStaticAt(2, col, reasonReserved)
    }
    _ = writeStaticAt(2, col, pageFaultCloseParen)
}

// ---------------------------------------------------------------------------
// Memory (milestone 6).
//
// The kernel stops merely standing in the machine's RAM and learns
// its shape. GRUB's word about the machine — the same Multiboot2
// information the screen was chosen from — carries a memory map
// (tag type 6): a row of regions, each a base, a length, and a
// kind, and only kind 1 is RAM a kernel may use. The kernel reads
// that map once, at boot, and builds a page-frame allocator over
// it: one bit per 4 KiB frame in storage the floor lends, a set bit
// meaning "spoken for" and a clear bit "free to hand out".
//
// The allocator's honesty rules:
//
//   - Every frame begins life spoken for. Only frames lying wholly
//     inside a region the map calls available RAM are ever cleared
//     into the free pool — so holes, firmware reservations, and
//     anything the map does not name stay untouchable.
//   - Reservations are then laid back over the pool: the first
//     mebibyte (the BIOS's own country), the kernel image itself
//     (the linker's bounds, lent by the floor), the framebuffer
//     when one is live, the Multiboot2 information itself, and
//     every frame any non-available region so much as touches.
//   - The counts the `mem` command speaks — usable RAM, total
//     frames, free frames, used frames — are reckoned from the map
//     and the bitmap at runtime. Nothing is remembered from the
//     build machine; nothing is invented.
//
// Frames beyond the bitmap's reach — past the first 4 GiB, which is
// also as far as the boot floor's identity map reaches — are not
// managed yet; the usable-bytes figure still counts them honestly
// from the map, and the frame pool covers what the kernel can
// actually touch. Nothing is paged and there is no heap: handing
// frames out, one by one, is this milestone's whole work.
// ---------------------------------------------------------------------------

/// The frame's size: 4 KiB, the processor's small page.
let pageSize: UInt64 = 4096

/// The bitmap's size in bytes, agreed with the floor's storage in
/// support.c. Eight bits to the byte, so this many bytes of bitmap
/// speak for frameBitmapCapacityBytes * 8 frames — 1,048,576 of
/// them, the whole first 4 GiB.
let frameBitmapCapacityBytes = 131072
let maxManagedFrames = 1048576

/// Did the bootloader hand over a memory map at all? Until it is
/// read, every count below is zero and `mem` says so plainly.
var memMapFound = false

/// The map's own testimony: the total length of every region it
/// calls available RAM, in bytes, counted exactly as written.
var memTotalUsableBytes: UInt64 = 0

/// How many 4 KiB frames lie wholly inside those available regions
/// (and within the bitmap's reach). This is the allocator's whole
/// estate: free frames plus used frames always equals it.
var memTotalFrames: UInt64 = 0

/// How many of those frames are free to hand out right now. Kept by
/// hand alongside the bitmap — every reserve, allocation, and free
/// moves it by exactly the frames it moves — so the `mem` answer
/// never has to recount a million bits.
var memFreeFrames: UInt64 = 0

/// The highest frame number the bitmap must cover: one past the
/// last frame of the last available region, within reach.
var memSpanFrames = 0

/// Where the allocator's search for a free frame resumes. Freed
/// frames lower it again, so a freed frame is the next one handed
/// out — which is also what makes the self-test below able to watch
/// a frame come back.
var memAllocHint = 0

/// The self-test's verdict, spoken by `mem`: at boot, once the
/// reservations are laid, the allocator takes two frames, gives one
/// back, takes another, gives all back — and passes only if every
/// taking succeeded, no two holdings were the same frame, and the
/// free count came home exactly to where it began.
var memSelfTestOK = false

/// Finds one tag in the Multiboot2 information, by type, and
/// returns its offset — or -1 when the bootloader left no such tag.
/// The tag walk the screen-choosing used, shared now with memory.
func findTagOffset(_ wanted: UInt32, infoAddress: UInt64) -> Int {
    if infoAddress == 0 { return -1 }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let totalSize = Int(bootInfoU32(base, 0))
    var offset = 8
    while offset + 8 <= totalSize {
        let type = bootInfoU32(base, offset)
        let size = Int(bootInfoU32(base, offset + 4))
        if type == 0 || size < 8 { break }
        if type == wanted { return offset }
        offset += (size + 7) & ~7
    }
    return -1
}

/// The first frame lying wholly inside a region that starts at the
/// given address: the region's base rounded up to a frame boundary,
/// capped at the bitmap's reach.
@inline(__always)
func availStartFrame(_ regionBase: UInt64) -> Int {
    let frame = Int((regionBase + pageSize - 1) / pageSize)
    return frame > maxManagedFrames ? maxManagedFrames : frame
}

/// One past the last frame lying wholly inside the region: its end
/// rounded down, capped the same way.
@inline(__always)
func availEndFrame(_ regionBase: UInt64, _ regionLength: UInt64) -> Int {
    let frame = Int((regionBase + regionLength) / pageSize)
    return frame > maxManagedFrames ? maxManagedFrames : frame
}

/// One frame's bit: true when the frame is spoken for.
@inline(__always)
func frameIsUsed(_ frame: Int) -> Bool {
    cardnullFrameBitmap()[frame >> 3]
        & (UInt8(1) << UInt8(frame & 7)) != 0
}

/// Sets one frame's bit. The counts are the callers' affair; this
/// only speaks to the bitmap.
@inline(__always)
func setFrameUsed(_ frame: Int, _ used: Bool) {
    let bitmap = cardnullFrameBitmap()
    let mask = UInt8(1) << UInt8(frame & 7)
    if used {
        bitmap[frame >> 3] |= mask
    } else {
        bitmap[frame >> 3] &= ~mask
    }
}

/// Lays a reservation over every frame the given range so much as
/// touches — a range's frames are reckoned outward, first frame at
/// the range's floor, end at its ceiling, because a frame half
/// covered by the kernel is wholly unusable. Only frames currently
/// free move the count; reserving a hole reserves nothing twice.
func reserveRange(base: UInt64, length: UInt64) {
    if length == 0 { return }
    var frame = Int(base / pageSize)
    var end = Int((base + length + pageSize - 1) / pageSize)
    if end > memSpanFrames { end = memSpanFrames }
    while frame < end {
        if !frameIsUsed(frame) {
            setFrameUsed(frame, true)
            memFreeFrames -= 1
        }
        frame += 1
    }
}

/// Reads the bootloader's memory map and raises the allocator over
/// it. Called once from kmain, after the screen is chosen (the
/// framebuffer's range is one of the reservations) and before the
/// shell opens. If no map came, nothing is raised and `mem` will
/// say so — the shell runs on exactly as before, standing in RAM it
/// simply cannot describe.
func initMemory(infoAddress: UInt64) {
    if infoAddress == 0 { return }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let tagOffset = findTagOffset(6, infoAddress: infoAddress)
    if tagOffset < 0 { return }
    let tagSize = Int(bootInfoU32(base, tagOffset + 4))
    let entrySize = Int(bootInfoU32(base, tagOffset + 8))
    if entrySize < 24 || tagSize < 16 { return }
    let entryCount = (tagSize - 16) / entrySize
    let entriesStart = tagOffset + 16
    let bitmap = cardnullFrameBitmap()

    // First pass: the estate's measure. Count the available
    // regions' bytes exactly as the map writes them, and the whole
    // frames lying inside them, and learn how wide a bitmap the
    // machine's RAM needs.
    var index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        let regionBase = bootInfoU64(base, entry)
        let regionLength = bootInfoU64(base, entry + 8)
        if bootInfoU32(base, entry + 16) == 1 {
            memTotalUsableBytes += regionLength
            let start = availStartFrame(regionBase)
            let end = availEndFrame(regionBase, regionLength)
            if end > start {
                memTotalFrames += UInt64(end - start)
                if end > memSpanFrames { memSpanFrames = end }
            }
        }
        index += 1
    }
    if memSpanFrames == 0 { return }

    // Every frame begins life spoken for: the bitmap is filled with
    // ones, so any frame the map does not expressly free — holes,
    // reservations, the unmapped dark — can never be handed out.
    for byteIndex in 0 ..< frameBitmapCapacityBytes {
        bitmap[byteIndex] = 0xFF
    }

    // Second pass: the available regions' frames are cleared into
    // the free pool.
    index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        let regionBase = bootInfoU64(base, entry)
        let regionLength = bootInfoU64(base, entry + 8)
        if bootInfoU32(base, entry + 16) == 1 {
            var frame = availStartFrame(regionBase)
            let end = availEndFrame(regionBase, regionLength)
            while frame < end {
                setFrameUsed(frame, false)
                frame += 1
            }
        }
        index += 1
    }
    memFreeFrames = memTotalFrames

    // The reservations, laid back over the pool.
    reserveRange(base: 0, length: 0x100000)          // the first mebibyte
    let kernelStart = cardnullKernelStart()
    let kernelEnd = cardnullKernelEnd()
    if kernelEnd > kernelStart {
        reserveRange(base: kernelStart, length: kernelEnd - kernelStart)
    }
    if useFramebuffer {
        reserveRange(base: framebufferAddress,
                     length: UInt64(framebufferPitch * framebufferHeight))
    }
    reserveRange(base: infoAddress,
                 length: UInt64(bootInfoU32(base, 0)))   // the map itself

    // Third pass: anything the map does not call available RAM —
    // ACPI tables, firmware reservations, the PCI dark — keeps any
    // available frame it touches out of the pool for good.
    index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        if bootInfoU32(base, entry + 16) != 1 {
            reserveRange(base: bootInfoU64(base, entry),
                         length: bootInfoU64(base, entry + 8))
        }
        index += 1
    }

    memMapFound = true
    runMemorySelfTest()
}

/// Hands out one free frame and returns its physical address, or 0
/// when the pool is empty — 0 is never a true answer, since frame
/// zero is reserved from the beginning and can never be handed out.
/// The search resumes where the last one ended, so frames are dealt
/// in order and a just-freed frame is found again at once.
func allocFrame() -> UInt64 {
    if !memMapFound || memSpanFrames == 0 { return 0 }
    var looked = 0
    while looked < memSpanFrames {
        let frame = memAllocHint + looked < memSpanFrames
            ? memAllocHint + looked
            : memAllocHint + looked - memSpanFrames
        if !frameIsUsed(frame) {
            setFrameUsed(frame, true)
            memFreeFrames -= 1
            memAllocHint = frame + 1
            if memAllocHint >= memSpanFrames { memAllocHint = 0 }
            return UInt64(frame) * pageSize
        }
        looked += 1
    }
    return 0
}

/// Gives one frame back to the pool. The caller's word is the only
/// guard: a frame may be freed only by whoever took it from
/// allocFrame — freeing a reservation would hand the kernel's own
/// ground to the next taker, and nothing in this young allocator
/// can tell the difference yet. Milestone 7's heap will keep books;
/// today, the kernel frees only what it took, in the self-test.
func freeFrame(_ address: UInt64) {
    if address % pageSize != 0 { return }
    let frame = Int(address / pageSize)
    if frame <= 0 || frame >= memSpanFrames { return }
    if frameIsUsed(frame) {
        setFrameUsed(frame, false)
        memFreeFrames += 1
        if frame < memAllocHint { memAllocHint = frame }
    }
}

/// The allocator's proof of life, run once at boot: take two
/// frames, give one back, take another, give everything back —
/// passing only if every taking succeeded, no two holdings were
/// ever the same frame, and the free count comes home exactly to
/// where it began. Its verdict rides in memSelfTestOK, and `mem`
/// speaks it; if it ever failed, the counts would still be true,
/// and the failure would be on the screen for anyone to see.
func runMemorySelfTest() {
    let before = memFreeFrames
    let first = allocFrame()
    let second = allocFrame()
    if first == 0 || second == 0 || first == second {
        if first != 0 { freeFrame(first) }
        if second != 0 { freeFrame(second) }
        memSelfTestOK = false
        return
    }
    freeFrame(first)
    let third = allocFrame()
    if third == 0 {
        freeFrame(second)
        memSelfTestOK = false
        return
    }
    freeFrame(second)
    freeFrame(third)
    memSelfTestOK = memFreeFrames == before
}


// ---------------------------------------------------------------------------
// Paging (milestone 7).
//
// Until now the kernel has run on borrowed tables: the boot floor
// built one identity map of the first 4 GiB — every page present,
// writable, executable — and the kernel simply stood in it. That
// was the floor's honest scaffolding, and scaffolding is not a
// house. Now the kernel builds tables of its own and moves in:
//
//   - Four levels, 4 KiB leaves, identity-mapped — a page's virtual
//     address is still its physical address, which is the truthful
//     shape for a kernel this young — but only for what is honestly
//     the kernel's to stand on: the usable RAM the bootloader's map
//     names, the kernel image, the live framebuffer, the VGA text
//     page that is the fallback screen, and the bootloader's own
//     information. Everything else — the PCI dark, the firmware's
//     country, the holes — is simply not there, and reaching for it
//     faults, by the page-fault handler's report above.
//   - The tables' frames are taken from the milestone-6 allocator,
//     so the map is built out of the very memory it describes.
//   - W^X, the first law of the hardening road, is laid in the
//     leaves: the kernel's text pages executable and not writable;
//     its read-only data neither writable nor executable; every
//     other mapped page writable and NOT executable. Nothing in
//     the kernel's world is both writable and executable.
//   - The switch itself is three breaths: build the tables while
//     the floor's map still carries the machine, raise EFER's NXE
//     (so the no-execute bit is law, not a reserved-bit fault),
//     and load CR3. If the shell answers afterward — screen,
//     keyboard, heartbeat, and all — the tables are the machine's
//     truth, and there is no stronger proof this milestone can
//     offer.
//
// The branch entries (PML4, PDPT, PD) carry present|writable and
// no law of their own: the leaf decides, as the processor's own
// rule reckons the strictest word along the walk. User pages did
// not exist when this was written — there were no users; every
// page was the kernel's, supervisor-only. Milestone 9's guests
// are the first exception, and they receive their user pages in
// cloned tables of their own, never in these.
// ---------------------------------------------------------------------------

/// The leaf flags of the kernel's three countries.
let ptePresent: UInt64 = 0x1
let pteWritable: UInt64 = 0x2
let pteNoExecute: UInt64 = 0x8000_0000_0000_0000

/// A fourth flag, no country's law but the guests': the user bit —
/// the difference between ground ring 3 may touch and ground it
/// may only be shown the wall of. It is never set in the kernel's
/// own tables; milestone 9 sets it only inside a guest's cloned
/// tables, on the one branch that leads to the guest's estate and
/// on that estate's leaves (see the programs section below).
let pteUser: UInt64 = 0x4

/// Did our own tables take over? Until the CR3 switch is behind
/// us this is false, and the fault test below will not pretend
/// otherwise: on the floor's borrowed map, everything answers.
var pagingReady = false

/// The physical address of our PML4 — a frame of the allocator's,
/// like every table below it.
var pagingRootAddress: UInt64 = 0

/// One entry of a page table, read or written through the identity
/// map both the floor's tables and ours keep.
@inline(__always)
func pagingEntry(_ table: UInt64, _ index: Int) -> UInt64 {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(table))![index]
}

@inline(__always)
func setPagingEntry(_ table: UInt64, _ index: Int, _ value: UInt64) {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(table))![index] = value
}

/// The frame-address mask of a table entry: the bits that are the
/// next table's (or the page's) physical address.
let pagingAddressMask: UInt64 = 0x000F_FFFF_FFFF_F000

/// Takes one frame from the allocator and wipes it clean — a
/// newborn table must read as all-absent, or the walk below would
/// follow yesterday's noise into the dark. Returns 0 when the pool
/// cannot pay, which the caller treats as the whole raising failed.
func pagingNewTable() -> UInt64 {
    let frame = allocFrame()
    if frame == 0 { return 0 }
    let entries = UnsafeMutablePointer<UInt64>(bitPattern: UInt(frame))!
    for index in 0 ..< 512 {
        entries[index] = 0
    }
    return frame
}

/// Maps one 4 KiB page, identity — the page's virtual address is
/// its physical address — under the given leaf flags, growing
/// branch tables along the walk as the allocator can pay for them.
/// A page already mapped is simply re-stamped: the later, more
/// particular law wins, which is how the kernel image's countries
/// are drawn over the RAM they stand in.
func mapPage(_ address: UInt64, _ leafFlags: UInt64) -> Bool {
    var table = pagingRootAddress
    var shift = 39
    while shift >= 21 {
        let index = Int((address >> UInt64(shift)) & 0x1FF)
        var entry = pagingEntry(table, index)
        if entry & ptePresent == 0 {
            let fresh = pagingNewTable()
            if fresh == 0 { return false }
            entry = fresh | ptePresent | pteWritable
            setPagingEntry(table, index, entry)
        }
        table = entry & pagingAddressMask
        shift -= 9
    }
    setPagingEntry(table, Int((address >> 12) & 0x1FF),
                   (address & ~UInt64(0xFFF)) | leafFlags)
    return true
}

/// Maps a whole range, page by page: the range's own pages are the
/// ones its floor and ceiling name, so a range ending mid-page does
/// not drag its neighbour in.
func mapRange(_ base: UInt64, _ length: UInt64,
              _ leafFlags: UInt64) -> Bool {
    if length == 0 { return true }
    var address = base & ~UInt64(0xFFF)
    let end = (base + length + pageSize - 1) & ~UInt64(0xFFF)
    while address < end {
        if !mapPage(address, leafFlags) { return false }
        address += pageSize
    }
    return true
}

/// Builds the kernel's own page tables and moves the machine into
/// them. Called once from kmain, after the frame allocator stands
/// (the tables are its frames) and before the interrupts open (a
/// fault mid-switch would have no IDT to catch it — but the whole
/// building happens under the floor's still-standing map, and the
/// switch itself is a single instruction with the screen, stack,
/// and code already mapped on the far side). If anything cannot be
/// paid for, the raising stops, pagingReady stays false, and the
/// kernel goes on standing on the floor's tables exactly as
/// before — poorer, but honest about it.
func initPaging(infoAddress: UInt64) {
    if !memMapFound || infoAddress == 0 { return }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let tagOffset = findTagOffset(6, infoAddress: infoAddress)
    if tagOffset < 0 { return }
    let tagSize = Int(bootInfoU32(base, tagOffset + 4))
    let entrySize = Int(bootInfoU32(base, tagOffset + 8))
    if entrySize < 24 || tagSize < 16 { return }
    let entryCount = (tagSize - 16) / entrySize
    let entriesStart = tagOffset + 16

    pagingRootAddress = pagingNewTable()
    if pagingRootAddress == 0 { return }

    let ramFlags = ptePresent | pteWritable | pteNoExecute

    // The usable RAM, reckoned afresh from the map — the same
    // estate the allocator keeps, whole frames only, and nothing
    // past the first 4 GiB, which is this kernel's whole reach
    // today. Table frames are taken as the building goes; every
    // one of them lies inside this estate and is mapped by it.
    var index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        if bootInfoU32(base, entry + 16) == 1 {
            let regionBase = bootInfoU64(base, entry)
            var regionEnd = regionBase &+ bootInfoU64(base, entry + 8)
            if regionBase < 0x1_0000_0000 {
                if regionEnd > 0x1_0000_0000 { regionEnd = 0x1_0000_0000 }
                let wholeEnd = regionEnd & ~UInt64(0xFFF)
                if wholeEnd > regionBase {
                    if !mapRange(regionBase, wholeEnd - regionBase,
                                 ramFlags) { return }
                }
            }
        }
        index += 1
    }

    // The bootloader's own information: the kernel reads it and
    // never writes it, so it comes back read-only — and not
    // executable, like everything that is not code.
    let infoSize = UInt64(bootInfoU32(base, 0))
    if infoSize > 0 {
        if !mapRange(infoAddress, infoSize,
                     ptePresent | pteNoExecute) { return }
    }

    // The VGA text page — the fallback screen behind a boot with
    // no framebuffer — writable device memory, never code.
    if !mapRange(0xB8000, pageSize, ramFlags) { return }

    // The live framebuffer, when there is one: the screen the
    // kernel is painting this very moment.
    if useFramebuffer {
        if !mapRange(framebufferAddress,
                     UInt64(framebufferPitch * framebufferHeight),
                     ramFlags) { return }
    }

    // The kernel image's own countries, drawn over the RAM they
    // stand in: read-only data first, then the text — so any page
    // the two spans somehow shared would end under the stricter
    // law of the two.
    let rodataStart = cardnullRodataStart()
    let rodataEnd = cardnullRodataEnd()
    if rodataEnd > rodataStart {
        if !mapRange(rodataStart, rodataEnd - rodataStart,
                     ptePresent | pteNoExecute) { return }
    }
    let textStart = cardnullTextStart()
    let textEnd = cardnullTextEnd()
    if textEnd > textStart {
        if !mapRange(textStart, textEnd - textStart,
                     ptePresent) { return }
    }

    // The switch: NXE first (the tables about to load are full of
    // the bit), then CR3. The instruction after the load already
    // walks the new tables; the stack under us and the screen
    // before us are mapped on both sides of it.
    cardnullEnableNxe()
    cardnullLoadCr3(pagingRootAddress)
    pagingReady = true
}

/// The address the `faulttest` command reaches for: a page in the
/// third gigabyte's high country, where no RAM, no frame buffer,
/// and no device of this machine has ever lived — under our own
/// tables, simply not there.
let faultTestAddress: UInt64 = 0xDEAD0000

/// Reaches for one byte at the fault test's address and brings it
/// back — a plain load through a raw pointer, marked never-inline
/// so the reach is a real reach and not a compiler's rumour of one.
/// Under honest paging this function is never allowed to return.
@inline(never)
func touchUnmapped() -> UInt8 {
    let pointer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(faultTestAddress))!
    return pointer.pointee
}


// ---------------------------------------------------------------------------
// The heap (milestone 7).
//
// Frames are honest, but they are coarse: a program — and a kernel
// with work ahead of it — needs memory in the sizes the work asks
// for, not only in 4 KiB slabs. So the kernel now keeps a heap: one
// unbroken field of frames taken from the allocator at boot, and
// within it a chain of blocks, each carrying a small header — its
// whole size, and whether it is spoken for. Allocation is
// first-fit: the first free block that can hold the ask is taken,
// and split when the remainder is still a block worth keeping.
// Freeing marks the block free and then walks the chain once,
// marrying each pair of neighbouring free blocks back into one —
// so the field does not shatter into splinters as work comes and
// goes.
//
// The books are kept by walking that same chain: used bytes and
// free bytes are the sums of the blocks' whole sizes, headers
// included, and used plus free always equals the region's size —
// the partition is the truth, and `heap` speaks it. The heap's
// pages are the RAM pages they are: writable, never executable,
// under the kernel's own tables.
//
// The heap stands in its own field and nowhere else: a request it
// cannot answer gets 0, never a neighbour's memory. And one law
// from the frame allocator still holds — the heap hands out only
// what it took; frames it borrowed are its estate for the kernel's
// whole life, returned to the pool never (what would the kernel
// do with an empty workbench?).
// ---------------------------------------------------------------------------

/// The heap's whole estate: 4 MiB of frames, a workbench sized for
/// the work ahead — filesystems and programs will want buffers —
/// and a small, honest fraction of the machines we run on.
let heapRegionBytes: UInt64 = 4 * 1024 * 1024

/// Every block begins with two words: its whole size in bytes
/// (header included) and its state — 1 spoken for, 0 free.
let heapHeaderBytes: UInt64 = 16

/// The smallest block worth keeping when a split leaves a
/// remainder: header plus one aligned payload word.
let heapMinBlockBytes: UInt64 = 32

/// Was a heap raised at all? Without the frame allocator there is
/// nothing to raise one from, and `heap` will say so plainly.
var heapReady = false

/// The heap field's first address; its size is heapRegionBytes.
var heapBase: UInt64 = 0

/// The heap's books, reckoned by walking the block chain after
/// every change: whole-block bytes and block counts, used and
/// free. Used plus free always equals heapRegionBytes.
var heapUsedBytes: UInt64 = 0
var heapFreeBytes: UInt64 = 0
var heapUsedBlocks: UInt64 = 0
var heapFreeBlocks: UInt64 = 0

/// The self-test's verdict, spoken by `heap`: at boot, blocks are
/// taken, written with known patterns, read back byte for byte,
/// freed, and taken again — the freed chair must be the first one
/// offered — and it passes only if every pattern survives, no
/// neighbour is disturbed, and the books come home to an empty
/// heap exactly as they began.
var heapSelfTestOK = false

/// One block's whole size, from its header.
@inline(__always)
func heapBlockSize(_ block: UInt64) -> UInt64 {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(block))![0]
}

/// One block's state: true when spoken for.
@inline(__always)
func heapBlockUsed(_ block: UInt64) -> Bool {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(block))![1] != 0
}

/// Writes one block's header: its whole size and its state.
@inline(__always)
func heapSetBlock(_ block: UInt64, _ size: UInt64, _ used: Bool) {
    let header = UnsafeMutablePointer<UInt64>(bitPattern: UInt(block))!
    header[0] = size
    header[1] = used ? 1 : 0
}

/// Walks the block chain and re-reckons the books from it — the
/// chain is the truth; the counters are only its latest reading.
/// Also proves the partition as it goes: the walk must land
/// exactly on the field's end, and if it cannot, the sums are
/// still the walk's honest sums but the caller may know the walk
/// broke (the self-test asks).
@discardableResult
func heapRecount() -> Bool {
    var usedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var usedBlocks: UInt64 = 0
    var freeBlocks: UInt64 = 0
    var block = heapBase
    let end = heapBase + heapRegionBytes
    while block < end {
        let size = heapBlockSize(block)
        if size == 0 || block + size > end { break }
        if heapBlockUsed(block) {
            usedBytes += size
            usedBlocks += 1
        } else {
            freeBytes += size
            freeBlocks += 1
        }
        block += size
    }
    heapUsedBytes = usedBytes
    heapFreeBytes = freeBytes
    heapUsedBlocks = usedBlocks
    heapFreeBlocks = freeBlocks
    return block == end
}

/// Takes one block from the heap: the first free block that can
/// hold the ask — payload rounded up to a sixteen-byte step, plus
/// the header — split when what remains is still a block worth
/// keeping. Returns the payload's address, or 0 when the heap
/// cannot answer; 0 is never a true answer, since every payload
/// stands sixteen bytes into a block and the field itself is no
/// neighbour of zero.
func heapAlloc(_ requested: Int) -> UInt64 {
    if !heapReady || requested <= 0 { return 0 }
    let payload = (UInt64(requested) + 15) & ~UInt64(15)
    let needed = payload + heapHeaderBytes
    var block = heapBase
    let end = heapBase + heapRegionBytes
    while block < end {
        let size = heapBlockSize(block)
        if size == 0 { return 0 }
        if !heapBlockUsed(block) && size >= needed {
            if size - needed >= heapMinBlockBytes {
                heapSetBlock(block + needed, size - needed, false)
                heapSetBlock(block, needed, true)
            } else {
                heapSetBlock(block, size, true)
            }
            heapRecount()
            return block + heapHeaderBytes
        }
        block += size
    }
    return 0
}

/// Gives one block back: the payload's header is found sixteen
/// bytes behind it, the block is marked free, and the chain is
/// walked once to marry neighbouring free blocks back together —
/// a freed block between two free ones makes all three one field
/// again. The books are re-reckoned from the healed chain.
func heapFree(_ payloadAddress: UInt64) {
    if !heapReady || payloadAddress == 0 { return }
    let block = payloadAddress - heapHeaderBytes
    if block < heapBase || block >= heapBase + heapRegionBytes { return }
    if !heapBlockUsed(block) { return }
    heapSetBlock(block, heapBlockSize(block), false)
    var current = heapBase
    let end = heapBase + heapRegionBytes
    while current < end {
        let size = heapBlockSize(current)
        if size == 0 { break }
        if !heapBlockUsed(current) {
            let next = current + size
            if next < end && !heapBlockUsed(next) {
                heapSetBlock(current, size + heapBlockSize(next), false)
                continue   // the same block, now longer: try again
            }
        }
        current += size
    }
    heapRecount()
}

/// Raises the heap: takes its frames from the allocator — one
/// unbroken run, for a heap scattered in pieces would be no field
/// at all — lays one free block over the whole run, and runs the
/// self-test. If the run breaks or the pool runs dry, every taken
/// frame is handed back and no heap stands: `heap` will say so,
/// which is the honest answer to a machine with nothing to spare.
func initHeap() {
    if !memMapFound { return }
    let framesNeeded = heapRegionBytes / pageSize
    var first: UInt64 = 0
    var previous: UInt64 = 0
    var taken: UInt64 = 0
    var unbroken = true
    while taken < framesNeeded {
        let frame = allocFrame()
        if frame == 0 { unbroken = false; break }
        if taken == 0 {
            first = frame
        } else if frame != previous + pageSize {
            unbroken = false
            // The stray frame is handed back with the run below.
            freeFrame(frame)
            break
        }
        previous = frame
        taken += 1
    }
    if !unbroken {
        var frame = first
        var returned: UInt64 = 0
        while returned < taken {
            freeFrame(frame)
            frame += pageSize
            returned += 1
        }
        return
    }
    heapBase = first
    heapSetBlock(heapBase, heapRegionBytes, false)
    heapReady = true
    heapRecount()
    runHeapSelfTest()
}

/// The pattern the self-test writes: a byte reckoned from the
/// block's own tag and the byte's place, so every block's writing
/// is its own and a neighbour's spill cannot masquerade as it.
@inline(__always)
func heapPatternByte(_ tag: UInt8, _ index: Int) -> UInt8 {
    tag ^ UInt8(truncatingIfNeeded: index)
}

/// Fills a block's payload with its pattern, byte by byte.
func heapFill(_ payload: UInt64, _ count: Int, _ tag: UInt8) {
    let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(payload))!
    for index in 0 ..< count {
        bytes[index] = heapPatternByte(tag, index)
    }
}

/// Reads a block's pattern back and compares it, byte for byte.
func heapCheck(_ payload: UInt64, _ count: Int, _ tag: UInt8) -> Bool {
    let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(payload))!
    for index in 0 ..< count {
        if bytes[index] != heapPatternByte(tag, index) { return false }
    }
    return true
}

/// The heap's proof of life, run once at boot: take three blocks,
/// fill each with its own pattern, read them all back; free the
/// middle one and take a smaller fourth — it must be offered the
/// freed chair, first-fit's plain promise — fill it too, and read
/// every survivor's pattern again, so a neighbour's disturbance
/// cannot hide. Then give everything back, and pass only if the
/// books come home exactly: nothing used, and the whole field free
/// in a single block, as it began.
func runHeapSelfTest() {
    let a = heapAlloc(100)
    let b = heapAlloc(1000)
    let c = heapAlloc(64)
    if a == 0 || b == 0 || c == 0 {
        if a != 0 { heapFree(a) }
        if b != 0 { heapFree(b) }
        if c != 0 { heapFree(c) }
        heapSelfTestOK = false
        return
    }
    heapFill(a, 100, 0xA1)
    heapFill(b, 1000, 0xB2)
    heapFill(c, 64, 0xC3)
    if !heapCheck(a, 100, 0xA1) || !heapCheck(b, 1000, 0xB2)
        || !heapCheck(c, 64, 0xC3) {
        heapFree(a)
        heapFree(b)
        heapFree(c)
        heapSelfTestOK = false
        return
    }
    heapFree(b)
    let d = heapAlloc(500)
    if d != b {
        if d != 0 { heapFree(d) }
        heapFree(a)
        heapFree(c)
        heapSelfTestOK = false
        return
    }
    heapFill(d, 500, 0xD4)
    if !heapCheck(d, 500, 0xD4) || !heapCheck(a, 100, 0xA1)
        || !heapCheck(c, 64, 0xC3) {
        heapFree(a)
        heapFree(c)
        heapFree(d)
        heapSelfTestOK = false
        return
    }
    heapFree(a)
    heapFree(c)
    heapFree(d)
    heapSelfTestOK = heapRecount()
        && heapUsedBytes == 0 && heapUsedBlocks == 0
        && heapFreeBytes == heapRegionBytes && heapFreeBlocks == 1
}

// ---------------------------------------------------------------------------
// The disc (milestone 8).
//
// The OS reads its own disc. Until now the kernel was the disc's
// only cargo and never looked at the rest of it; now it carries a
// driver for the drive it booted from and a reader for the format
// the disc is written in, and the shell gains two commands, `ls`
// and `cat`, to prove both.
//
//   - The driver speaks ATAPI over AHCI. The machines this
//     kernel boots on — the test rig and Tyler's alike — hang
//     their CD-ROM off an AHCI controller: an IDE device on one
//     of the controller's buses, with no legacy IDE port
//     hardware anywhere in the machine. The controller is found
//     in PCI configuration space by its class, its registers
//     are mapped into the kernel's own tables, and its ports
//     are asked in order: a port counts only when the device
//     signed to it signs itself ATAPI (0xEB140101) and the
//     drive answers IDENTIFY PACKET DEVICE as a packet device.
//     The boot report names the port that answered and what the
//     drive calls itself. Sectors are asked for one at a time
//     with the READ (10) packet, carried over the ATA PACKET
//     command, and the controller's own engine walks each
//     sector into memory — DMA, because AHCI knows no other
//     road.
//   - The reader speaks ISO9660, read-only. The Primary Volume
//     Descriptor at sector 16 must carry its CD001 signature or
//     the disc is answered as a filesystem this kernel does not
//     know. The root directory's record is taken from the
//     descriptor, and directory entries are walked record by
//     record within each sector — a record never crosses a
//     sector's edge, which is the format's own rule. Names on
//     the disc stand in capitals wearing a ";1" version suffix;
//     the reader shows them without the suffix and matches the
//     shell's paths letter for letter without caring about
//     case, the way the shell has always folded its commands.
//
// Nothing here writes: no sector is written, no name is changed,
// nothing is cached past the sector in hand. A file the disc
// does not hold is answered as missing; a directory asked to be
// printed as a file is answered as a directory; a read the drive
// refuses is answered as a read error. The truth, in all cases,
// over a comfortable fiction.
// ---------------------------------------------------------------------------

/// A disc sector's size: CD-ROM sectors carry 2048 bytes of data.
let discSectorBytes = 2048

/// How long the driver waits on the controller, in register
/// reads, before it calls the wait failed. Deliberately
/// generous: a drive spinning up is slower than any loop this
/// kernel runs, and a wait that ends in an honest error beats
/// a hang.
let discWaitLimit = 4000000

/// Did a drive answer the raising? Until one does, every disc
/// command answers with the absence, plainly.
var discDriveFound = false

/// Did the disc in the drive carry the ISO9660 signature? A
/// drive can answer honestly while its disc is a stranger.
var discIsoFound = false

/// The disc controller's register base — its fifth base-address
/// register, read from PCI configuration space — and the port
/// the drive answered on. The controller's registers are
/// memory-mapped, standing in the PCI dark the paging section
/// leaves unmapped on purpose; the driver maps its own door at
/// the raising.
var ahciBase: UInt64 = 0
var ahciPort = 0

/// The driver's two DMA fields, taken from the frame allocator
/// at the disc's raising and kept for the kernel's life: one
/// frame holds the chosen port's command list and, at its
/// 0x400 offset, the field the drive's own answer frames land
/// in; the other holds the one command table — the command
/// frame, the packet bytes, and the data descriptor. Their
/// addresses are physical as well as virtual, the identity
/// map's gift, which is what a DMA engine must be told.
var ahciListFrame: UInt64 = 0
var ahciTableFrame: UInt64 = 0

/// The sector buffer and the path scratch: two fields taken from
/// the heap at the disc's raising and kept for the kernel's life.
/// The buffer holds the one sector in hand — no caching, so no
/// stale sector can ever be mistaken for the disc's truth. The
/// scratch holds the command's path argument, copied off the
/// screen, up to its capacity in bytes.
var discBufferAddress: UInt64 = 0
var discPathAddress: UInt64 = 0
let discPathCapacity = 160

/// The found drive's own name for itself, from its IDENTIFY
/// answer: up to forty characters, kept in a heap scratch, with
/// its reckoned length beside it. Zero length means the drive
/// gave no name worth repeating, and the report says "ATAPI
/// CD-ROM" instead.
var discModelAddress: UInt64 = 0
var discModelLength = 0

/// The root directory's place and size, from the volume
/// descriptor: every path the shell resolves starts here.
var isoRootExtent: UInt32 = 0
var isoRootSize: UInt32 = 0

/// The last read's failure, remembered so a command can answer
/// "the disc could not be read" instead of a confident falsehood:
/// set by the sector reader's retries, cleared as each command
/// begins its work.
var discReadFailed = false

/// The sector buffer, as the pointer every disc reader shares.
@inline(__always)
func discBuffer() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(discBufferAddress))!
}

/// The path scratch, as a pointer.
@inline(__always)
func discPath() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(discPathAddress))!
}

/// A little-endian word and double-word read from the buffer in
/// hand — the ISO9660 fields the reader trusts are the format's
/// little-endian halves of its both-endian pairs.
@inline(__always)
func discU16(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int) -> UInt32 {
    UInt32(buffer[offset]) | UInt32(buffer[offset + 1]) << 8
}

@inline(__always)
func discU32(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int) -> UInt32 {
    discU16(buffer, offset) | discU16(buffer, offset + 2) << 16
}

/// A breath of bus time: reads of the POST port, the ancient way
/// of letting a chip catch up, repeated as long as asked. The
/// port read has a side effect the compiler cannot argue away,
/// which is the whole of the trick.
func atapiBreath(_ reads: Int) {
    var count = 0
    while count < reads {
        _ = cardnullInb(0x80)
        count += 1
    }
}

/// One register of the controller, read or written through
/// memory. AHCI registers are memory-mapped, so no floor hand
/// is needed — but these hands are functions the compiler may
/// not inline away, so a polling loop truly looks each time it
/// asks, and a written word truly lands when it is written.
@inline(never)
func mmioRead32(_ address: UInt64) -> UInt32 {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!
        .pointee
}

@inline(never)
func mmioWrite32(_ address: UInt64, _ value: UInt32) {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!
        .pointee = value
}

/// One word of PCI configuration space, through the floor's
/// double-word hands: the address port names the device, the
/// function, and the word, the data port carries it. This
/// kernel knows bus 0 only — the controller it seeks has lived
/// there on every machine it has met — but it asks every
/// function of every device: a chipset wears several devices
/// in one slot, and the disc controller is the second function
/// of its own.
func pciConfigRead32(_ device: UInt32, _ function: UInt32,
                     _ offset: UInt32) -> UInt32 {
    cardnullOutl(0xCF8, 0x80000000 | (device << 11)
                 | (function << 8) | (offset & 0xFC))
    return cardnullInl(0xCFC)
}

func pciConfigWrite32(_ device: UInt32, _ function: UInt32,
                      _ offset: UInt32, _ value: UInt32) {
    cardnullOutl(0xCF8, 0x80000000 | (device << 11)
                 | (function << 8) | (offset & 0xFC))
    cardnullOutl(0xCFC, value)
}

/// The chosen port's register addresses: the host registers
/// begin at the base; each port's field begins 0x100 in, with
/// 0x80 bytes per port.
@inline(__always)
func ahciReg(_ offset: UInt64) -> UInt64 {
    ahciBase + 0x100 + UInt64(ahciPort) * 0x80 + offset
}

/// Prepares the port's one slot for a command: the command
/// table is emptied, the command frame is laid at its head —
/// type 0x27, the mark that says "this writes the command
/// register", then the command and its feature word — one data
/// descriptor is laid at the table's 0x80 naming the sector
/// buffer and the count, and the slot's header is written in
/// the command list. Nothing is sent: a PACKET command's bytes
/// are the caller's to place first, in the packet area at 0x40.
func ahciPrepare(_ command: UInt8, _ features: UInt8,
                 _ packet: Bool, _ byteCount: Int) -> Bool {
    if ahciTableFrame == 0 { return false }
    let table = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciTableFrame))!
    var index = 0
    while index < 0x100 {
        table[index] = 0
        index += 1
    }
    table[0] = 0x27
    table[1] = 0x80
    table[2] = command
    table[3] = features
    let words = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(ahciTableFrame))!
    words[0x80 / 4] = UInt32(discBufferAddress & 0xFFFFFFFF)
    words[0x80 / 4 + 1] = UInt32(discBufferAddress >> 32)
    words[0x80 / 4 + 3] = UInt32(byteCount - 1) | 0x80000000
    let header = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(ahciListFrame))!
    var flags: UInt32 = 5 | 1 << 16
    if packet { flags |= 1 << 5 }
    header[0] = flags
    header[1] = 0
    header[2] = UInt32(ahciTableFrame & 0xFFFFFFFF)
    header[3] = UInt32(ahciTableFrame >> 32)
    return true
}

/// Fires the prepared slot and waits for the controller to hand
/// it back: completion is the slot's bit clearing, a task-file
/// error mark in the port's interrupt word refuses the wait,
/// and a transfer shorter than asked for is no success.
func ahciFire(_ byteCount: Int) -> Bool {
    mmioWrite32(ahciReg(0x10), 0xFFFFFFFF)
    mmioWrite32(ahciReg(0x38), 1)
    var waited = 0
    while mmioRead32(ahciReg(0x38)) & 1 != 0 {
        if mmioRead32(ahciReg(0x10)) & 0x40000000 != 0 {
            return false
        }
        waited += 1
        if waited >= discWaitLimit { return false }
    }
    if mmioRead32(ahciReg(0x10)) & 0x40000000 != 0 { return false }
    if mmioRead32(ahciReg(0x20)) & 0x01 != 0 { return false }
    let header = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(ahciListFrame))!
    return header[1] == UInt32(byteCount)
}

/// Raises the drive: finds the AHCI controller in PCI space,
/// takes the first port whose device signs itself ATAPI and
/// whose link stands, gives that port its fields, and wakes it.
/// On success the port is kept in ahciPort, ready for commands.
func ahciRaiseDrive() -> Bool {
    // The controller by its class: mass storage, SATA subclass,
    // the AHCI programming interface — the one door the modern
    // chipset world offers its disc drives.
    var device: UInt32 = 0
    var foundDevice: UInt32 = 0
    var foundFunction: UInt32 = 0
    var abar: UInt32 = 0
    while device < 32 && abar == 0 {
        var function: UInt32 = 0
        while function < 8 {
            let id = pciConfigRead32(device, function, 0)
            if id & 0xFFFF != 0xFFFF {
                let classes = pciConfigRead32(device, function,
                                              0x08)
                if classes >> 24 == 0x01
                    && (classes >> 16) & 0xFF == 0x06
                    && (classes >> 8) & 0xFF == 0x01 {
                    let bar = pciConfigRead32(device, function,
                                              0x24) & 0xFFFFFFF0
                    if bar != 0 {
                        abar = bar
                        foundDevice = device
                        foundFunction = function
                        break
                    }
                }
            }
            function += 1
        }
        device += 1
    }
    if abar == 0 { return false }
    // The controller must be allowed to see memory and to
    // master the bus: its engine's walking is the whole road in.
    let commandWord = pciConfigRead32(foundDevice, foundFunction,
                                      0x04)
    pciConfigWrite32(foundDevice, foundFunction, 0x04,
                     commandWord | 0x06)
    ahciBase = UInt64(abar)
    // The registers stand in the PCI dark the paging section
    // leaves unmapped on purpose; the driver maps its own door.
    if pagingReady {
        let regFlags = ptePresent | pteWritable | pteNoExecute
        if !mapPage(ahciBase, regFlags) { return false }
        if !mapPage(ahciBase + 0x1000, regFlags) { return false }
        cardnullInvlpg(ahciBase)
        cardnullInvlpg(ahciBase + 0x1000)
    }
    // AHCI mode on, then the map of which ports exist at all.
    mmioWrite32(ahciBase + 0x04,
                mmioRead32(ahciBase + 0x04) | 0x80000000)
    let present = mmioRead32(ahciBase + 0x0C)
    var port = 0
    var chosen = false
    while port < 32 && !chosen {
        if present & (UInt32(1) << UInt32(port)) != 0 {
            ahciPort = port
            // The device's signature in its port's register —
            // an ATAPI device signs 0xEB140101 — and the link's
            // word: 3 in the detect field means a device stands
            // there and the talking is done.
            if mmioRead32(ahciReg(0x24)) == 0xEB140101
                && mmioRead32(ahciReg(0x28)) & 0x0F == 3 {
                chosen = true
            }
        }
        port += 1
    }
    if !chosen { return false }
    // Still the port, then give it its fields.
    var cmd = mmioRead32(ahciReg(0x18))
    mmioWrite32(ahciReg(0x18), cmd & ~0x11)
    var waited = 0
    while mmioRead32(ahciReg(0x18)) & 0x8000 != 0 {
        waited += 1
        if waited >= discWaitLimit { return false }
    }
    ahciListFrame = allocFrame()
    ahciTableFrame = allocFrame()
    if ahciListFrame == 0 || ahciTableFrame == 0 { return false }
    let listBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciListFrame))!
    var index = 0
    while index < 4096 {
        listBytes[index] = 0
        index += 1
    }
    let tableBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciTableFrame))!
    index = 0
    while index < 4096 {
        tableBytes[index] = 0
        index += 1
    }
    mmioWrite32(ahciReg(0x00),
                UInt32(ahciListFrame & 0xFFFFFFFF))
    mmioWrite32(ahciReg(0x04), UInt32(ahciListFrame >> 32))
    let fisField = ahciListFrame + 0x400
    mmioWrite32(ahciReg(0x08), UInt32(fisField & 0xFFFFFFFF))
    mmioWrite32(ahciReg(0x0C), UInt32(fisField >> 32))
    mmioWrite32(ahciReg(0x30), 0xFFFFFFFF)
    mmioWrite32(ahciReg(0x10), 0xFFFFFFFF)
    cmd = mmioRead32(ahciReg(0x18))
    cmd |= 0x10 | 0x02 | 1 << 24
    mmioWrite32(ahciReg(0x18), cmd)
    mmioWrite32(ahciReg(0x18), cmd | 0x1)
    // The last wait: the link stands and the drive is neither
    // busy nor asking for a hand.
    waited = 0
    while true {
        if mmioRead32(ahciReg(0x28)) & 0x0F == 3
            && mmioRead32(ahciReg(0x20)) & 0x88 == 0 {
            return true
        }
        waited += 1
        if waited >= discWaitLimit { return false }
    }
}

/// Asks the raised drive its name: IDENTIFY PACKET DEVICE, the
/// one ATA command a packet device answers directly — and the
/// answer must call itself a packet device (the configuration
/// word's top two bits, 10 binary) before its name is trusted.
/// The name is words 27 to 46 of the answer, each word holding
/// two characters with the first in its high byte, so the pair
/// stands swapped in memory and is swapped back here; trailing
/// spaces are the padding, not the name's ending.
func ahciIdentify() -> Bool {
    if !ahciPrepare(0xA1, 0, false, 512) { return false }
    if !ahciFire(512) { return false }
    let buffer = discBuffer()
    if discU16(buffer, 0) >> 14 != 2 { return false }
    if discModelAddress != 0 {
        let model = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(discModelAddress))!
        var length = 0
        var index = 0
        while index < 40 {
            let byte = buffer[54 + (index & ~1) + (1 - (index & 1))]
            model[index] = byte
            if byte != 0x20 && byte != 0 { length = index + 1 }
            index += 1
        }
        discModelLength = length
    }
    return true
}

/// Reads one sector by its logical block address into the
/// buffer, through the READ (10) packet: the PACKET command is
/// prepared (feature word 1 — the packet's data may travel by
/// the controller's engine rather than by hand, the only road
/// AHCI offers), the twelve packet bytes are placed in the
/// table's packet area — the opcode, then the address in the
/// big-endian order the SCSI world speaks, then the count of
/// one — and the slot is fired. Any refusal, error, or silence
/// along the way is a plain false.
func discReadSectorOnce(_ lba: UInt32) -> Bool {
    if !ahciPrepare(0xA0, 0x01, true, discSectorBytes) {
        return false
    }
    let table = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciTableFrame))!
    table[0x40] = 0x28                        // READ (10)
    table[0x41] = 0
    table[0x42] = UInt8((lba >> 24) & 0xFF)
    table[0x43] = UInt8((lba >> 16) & 0xFF)
    table[0x44] = UInt8((lba >> 8) & 0xFF)
    table[0x45] = UInt8(lba & 0xFF)
    table[0x46] = 0
    table[0x47] = 0
    table[0x48] = 1                           // one sector
    table[0x49] = 0
    table[0x4A] = 0
    table[0x4B] = 0
    return ahciFire(discSectorBytes)
}

/// Reads one sector with the patience a real drive sometimes
/// needs: three attempts, a breath between them — a drive still
/// spinning up after the bootloader's day may refuse the first
/// asking and answer the second. The final failure is
/// remembered in discReadFailed for the command to speak.
func discReadSector(_ lba: UInt32) -> Bool {
    var attempt = 0
    while attempt < 3 {
        if discReadSectorOnce(lba) { return true }
        atapiBreath(200000)
        attempt += 1
    }
    discReadFailed = true
    return false
}

/// Raises the disc: take the buffer and scratches from the heap,
/// find and wake the drive behind the AHCI controller, and ask
/// its name. Then read the volume descriptor at sector 16 and
/// ask for its signature: the type byte 1, the letters CD001,
/// and the root directory's record at offset 156, whose extent
/// and size become every path's start.
func initDisc() {
    if !heapReady { return }
    discBufferAddress = heapAlloc(discSectorBytes)
    discPathAddress = heapAlloc(discPathCapacity)
    discModelAddress = heapAlloc(40)
    if discBufferAddress == 0 { return }
    if !ahciRaiseDrive() { return }
    if !ahciIdentify() { return }
    discDriveFound = true
    if !discReadSector(16) { return }
    let buffer = discBuffer()
    if buffer[0] != 1 { return }
    if buffer[1] != 0x43 || buffer[2] != 0x44 || buffer[3] != 0x30
        || buffer[4] != 0x30 || buffer[5] != 0x31 { return }
    isoRootExtent = discU32(buffer, 156 + 2)
    isoRootSize = discU32(buffer, 156 + 10)
    if isoRootExtent == 0 { return }
    discIsoFound = true
}

/// The disc report's vocabulary: the words the boot line is
/// built from, spoken once while the banner's field is clean.
let discReportPrefix: StaticString = "Disc: "
let discGenericName: StaticString = "ATAPI CD-ROM"
let discReportPortWord: StaticString = ", AHCI port "
let discReportSuffix: StaticString = "."
let discAbsentLine: StaticString = "No CD-ROM drive answered."
let discUnknownFsLine: StaticString =
    "The disc answered, but its filesystem is not ISO9660."

/// The boot report: one line naming the drive that answered —
/// its own name for itself when it gave one, and the controller
/// port it answered on — or the absence, plainly, when none
/// did. Spoken from kmain before the first prompt, so the shell
/// opens beneath the news.
func printDiscReport() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    writeStatic(discReportPrefix)
    if discModelLength > 0 && discModelAddress != 0 {
        let model = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(discModelAddress))!
        var index = 0
        while index < discModelLength {
            writeChar(model[index])
            index += 1
        }
    } else {
        writeStatic(discGenericName)
    }
    writeStatic(discReportPortWord)
    writeNumber(UInt64(ahciPort))
    writeLine(discReportSuffix)
    if !discIsoFound {
        writeLine(discUnknownFsLine)
    }
}

/// One directory entry's facts, as the walkers below find them:
/// kept in globals, as the heap keeps its books, because a
/// freestanding kernel returning a pocketful of fields from
/// every helper grows hard to read. entryFound says whether
/// they mean anything at all.
var entryFound = false
var entryExtent: UInt32 = 0
var entrySize: UInt32 = 0
var entryIsDirectory = false

/// Compares one directory record's name against a path component
/// held in the path scratch: the record's name with its ";1"
/// version suffix forgiven, letter for letter with case folded —
/// and the two nameless entries, whose names are the single
/// bytes 0 and 1, matched against "." and ".." as the world's
/// shells have always called them.
func isoNameMatches(_ buffer: UnsafeMutablePointer<UInt8>,
                    _ record: Int, _ componentStart: Int,
                    _ componentLength: Int) -> Bool {
    let path = discPath()
    let nameLength = Int(buffer[record + 32])
    if nameLength == 1 && buffer[record + 33] == 0 {
        return componentLength == 1 && path[componentStart] == 0x2E
    }
    if nameLength == 1 && buffer[record + 33] == 1 {
        return componentLength == 2 && path[componentStart] == 0x2E
            && path[componentStart + 1] == 0x2E
    }
    var effective = nameLength
    var index = 0
    while index < nameLength {
        if buffer[record + 33 + index] == 0x3B {   // ';'
            effective = index
            break
        }
        index += 1
    }
    if effective != componentLength { return false }
    index = 0
    while index < effective {
        var discByte = buffer[record + 33 + index]
        var pathByte = path[componentStart + index]
        if discByte >= 0x61 && discByte <= 0x7A { discByte -= 0x20 }
        if pathByte >= 0x61 && pathByte <= 0x7A { pathByte -= 0x20 }
        if discByte != pathByte { return false }
        index += 1
    }
    return true
}

/// Looks one component up in one directory: the directory's
/// sectors are read in turn, and within each, its records are
/// walked from the first byte — a record's own length says
/// where the next begins, a zero length means the rest of the
/// sector is padding, and the directory's reckoned size says
/// where the walking honestly stops.
func isoFindEntry(_ dirExtent: UInt32, _ dirSize: UInt32,
                  _ componentStart: Int,
                  _ componentLength: Int) -> Bool {
    entryFound = false
    if dirSize == 0 { return false }
    let buffer = discBuffer()
    var sectorIndex: UInt32 = 0
    let sectorCount = (dirSize + UInt32(discSectorBytes) - 1)
        / UInt32(discSectorBytes)
    while sectorIndex < sectorCount {
        if !discReadSector(dirExtent + sectorIndex) { return false }
        var inSector = discSectorBytes
        let remaining = dirSize - sectorIndex * UInt32(discSectorBytes)
        if remaining < UInt32(discSectorBytes) {
            inSector = Int(remaining)
        }
        var offset = 0
        while offset < inSector {
            let recordLength = Int(buffer[offset])
            if recordLength == 0 { break }
            if recordLength >= 34
                && isoNameMatches(buffer, offset, componentStart,
                                  componentLength) {
                entryExtent = discU32(buffer, offset + 2)
                entrySize = discU32(buffer, offset + 10)
                entryIsDirectory = buffer[offset + 25] & 0x02 != 0
                entryFound = true
                return true
            }
            offset += recordLength
        }
        sectorIndex += 1
    }
    return false
}

/// The path resolution's outcome: found, or the honest reason
/// it was not — a name the disc does not hold, a file asked to
/// be a directory along the way, or a read the drive refused.
let pathFoundCode = 0
let pathMissingCode = 1
let pathNotDirectoryCode = 2
let pathReadErrorCode = 3

/// The resolved entry's facts, when the code says found.
var resolvedExtent: UInt32 = 0
var resolvedSize: UInt32 = 0
var resolvedIsDirectory = false

/// The last component's place in the path scratch, remembered
/// for the answers that name the file they were asked about.
var lastComponentStart = 0
var lastComponentLength = 0

/// Resolves the path in the scratch, component by component
/// from the root: slashes are forgiven in any number, a leading
/// one or none at all means the same root, and an empty path is
/// the root itself. Each component must be found in the
/// directory the walk is standing in; each but the last must
/// be a directory to walk into.
func isoResolvePath(_ length: Int) -> Int {
    return isoResolvePathIn(0, length)
}

/// The same walk over one reach of the scratch — the bytes from
/// `start` up to `end` — because milestone 10's `both` keeps two
/// paths in the one scratch and must resolve the second where it
/// lies. The components' places in the scratch are the absolute
/// ones the finder already speaks, so nothing else changes: the
/// bounds are the only new word.
func isoResolvePathIn(_ start: Int, _ end: Int) -> Int {
    let path = discPath()
    resolvedExtent = isoRootExtent
    resolvedSize = isoRootSize
    resolvedIsDirectory = true
    lastComponentStart = 0
    lastComponentLength = 0
    var index = start
    while index < end && path[index] == 0x2F { index += 1 }
    if index >= end { return pathFoundCode }
    while true {
        let componentStart = index
        while index < end && path[index] != 0x2F { index += 1 }
        let componentLength = index - componentStart
        lastComponentStart = componentStart
        lastComponentLength = componentLength
        discReadFailed = false
        if !isoFindEntry(resolvedExtent, resolvedSize,
                         componentStart, componentLength) {
            return discReadFailed ? pathReadErrorCode : pathMissingCode
        }
        // More components beyond the slashes?
        var next = index
        while next < end && path[next] == 0x2F { next += 1 }
        if next < end {
            if !entryIsDirectory { return pathNotDirectoryCode }
            resolvedExtent = entryExtent
            resolvedSize = entrySize
            index = next
        } else {
            resolvedExtent = entryExtent
            resolvedSize = entrySize
            resolvedIsDirectory = entryIsDirectory
            return pathFoundCode
        }
    }
}

/// Writes the path in the scratch, as the typist wrote it — the
/// answers that name a file name it as it was asked for.
func writePathArgument(_ length: Int) {
    let path = discPath()
    var index = 0
    while index < length {
        writeChar(path[index])
        index += 1
    }
}

/// Prints one directory entry for `ls`: two spaces, the name as
/// the disc keeps it minus its version suffix, padding to a
/// modest column, and then its size — or the directory mark.
/// The two nameless entries are not printed: a listing that
/// begins with "." and ".." tells the reader nothing the prompt
/// did not already say.
func printDirectoryEntry(_ buffer: UnsafeMutablePointer<UInt8>,
                         _ record: Int) {
    let nameLength = Int(buffer[record + 32])
    if nameLength == 1 && buffer[record + 33] <= 1 { return }
    var effective = nameLength
    var index = 0
    while index < nameLength {
        if buffer[record + 33 + index] == 0x3B {
            effective = index
            break
        }
        index += 1
    }
    writeChar(0x20)
    writeChar(0x20)
    index = 0
    while index < effective {
        writeChar(buffer[record + 33 + index])
        index += 1
    }
    var padding = 14 - effective
    if padding < 1 { padding = 1 }
    while padding > 0 {
        writeChar(0x20)
        padding -= 1
    }
    if buffer[record + 25] & 0x02 != 0 {
        writeLine(lsDirMark)
    } else {
        writeNumber(UInt64(discU32(buffer, record + 10)))
        writeNewline()
    }
}

/// `ls`'s work on one directory: a header naming the disc and
/// the path, then every entry the directory holds, walked the
/// same way the finder walks — or the word that the directory
/// holds nothing but its two nameless entries.
func listDirectory(_ extent: UInt32, _ size: UInt32,
                   _ argumentLength: Int) {
    writeStatic(lsHeaderPrefix)
    if argumentLength > 0 {
        writePathArgument(argumentLength)
    } else {
        writeChar(0x2F)
    }
    writeLine(lsHeaderSuffix)
    if size == 0 {
        writeLine(lsEmptyLine)
        return
    }
    let buffer = discBuffer()
    var printed = 0
    var sectorIndex: UInt32 = 0
    let sectorCount = (size + UInt32(discSectorBytes) - 1)
        / UInt32(discSectorBytes)
    while sectorIndex < sectorCount {
        if !discReadSector(extent + sectorIndex) {
            writeLine(discReadErrorLine)
            return
        }
        var inSector = discSectorBytes
        let remaining = size - sectorIndex * UInt32(discSectorBytes)
        if remaining < UInt32(discSectorBytes) {
            inSector = Int(remaining)
        }
        var offset = 0
        while offset < inSector {
            let recordLength = Int(buffer[offset])
            if recordLength == 0 { break }
            if recordLength >= 34 {
                let nameLength = Int(buffer[offset + 32])
                if !(nameLength == 1 && buffer[offset + 33] <= 1) {
                    printed += 1
                }
                printDirectoryEntry(buffer, offset)
            }
            offset += recordLength
        }
        sectorIndex += 1
    }
    if printed == 0 {
        writeLine(lsEmptyLine)
    }
}

/// ls's and cat's shared vocabulary: the answers to a missing
/// disc, a missing name, and a refused read.
let lsHeaderPrefix: StaticString = "Disc "
let lsHeaderSuffix: StaticString = ":"
let lsDirMark: StaticString = "<DIR>"
let lsEmptyLine: StaticString = "  (nothing here)"
let discReadErrorLine: StaticString = "The disc could not be read."
let notOnDiscPrefix: StaticString = "Not on the disc: "
let notDirectorySuffix: StaticString = " is not a directory."
let isDirectorySuffix: StaticString = " is a directory, not a file."
let catUsageLine: StaticString = "cat wants a file: cat /WELCOME.TXT"

/// The shell's argument, copied off the screen into the path
/// scratch: the typed line's bytes after its first word, trimmed
/// of the spaces at both ends, up to the scratch's capacity.
/// Returns the copied length — zero when the line held nothing
/// after its word, which `ls` takes as "the root" and `cat` as
/// a question it must answer with its usage.
func copyArgumentToScratch() -> Int {
    let start = lineStartRow * screenColumns + lineStartCol
    let end = cursorRow * screenColumns + cursorCol
    var cell = start
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    while cell < end && screenChar(cell: cell) != 0x20 { cell += 1 }
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    var last = end
    while last > cell && screenChar(cell: last - 1) == 0x20 {
        last -= 1
    }
    if discPathAddress == 0 { return 0 }
    let path = discPath()
    var length = 0
    while cell < last && length < discPathCapacity {
        path[length] = screenChar(cell: cell)
        length += 1
        cell += 1
    }
    return length
}

/// The first word of the typed line, against a command word:
/// the match the argument-carrying commands are found by,
/// where commandMatches' whole-line strictness would refuse
/// the argument that makes them useful.
func firstWordMatches(_ command: StaticString) -> Bool {
    let start = lineStartRow * screenColumns + lineStartCol
    let end = cursorRow * screenColumns + cursorCol
    var cell = start
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    var index = 0
    while command.utf8Start[index] != 0 {
        if cell >= end { return false }
        var character = screenChar(cell: cell)
        if character >= 0x41 && character <= 0x5A {
            character += 0x20
        }
        if character != command.utf8Start[index] { return false }
        cell += 1
        index += 1
    }
    return cell >= end || screenChar(cell: cell) == 0x20
}

/// `ls`: the root's listing with no argument, a directory's
/// with a path, and a file's own single line when the path
/// names a file — the answer is the disc's, in every case.
func runList() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    if !discIsoFound {
        writeLine(discUnknownFsLine)
        return
    }
    let length = copyArgumentToScratch()
    discReadFailed = false
    if length == 0 {
        listDirectory(isoRootExtent, isoRootSize, 0)
        return
    }
    let outcome = isoResolvePath(length)
    if outcome == pathMissingCode {
        writeStatic(notOnDiscPrefix)
        writePathArgument(length)
        writeNewline()
        return
    }
    if outcome == pathNotDirectoryCode {
        writePathArgument(length)
        writeLine(notDirectorySuffix)
        return
    }
    if outcome == pathReadErrorCode {
        writeLine(discReadErrorLine)
        return
    }
    if resolvedIsDirectory {
        listDirectory(resolvedExtent, resolvedSize, length)
        return
    }
    // A file: its own line — the name as asked, padded as the
    // listing pads, and its size.
    writeChar(0x20)
    writeChar(0x20)
    let path = discPath()
    var index = 0
    var written = 0
    while index < lastComponentLength {
        writeChar(path[lastComponentStart + index])
        index += 1
        written += 1
    }
    var padding = 14 - written
    if padding < 1 { padding = 1 }
    while padding > 0 {
        writeChar(0x20)
        padding -= 1
    }
    writeNumber(UInt64(resolvedSize))
    writeNewline()
}

/// `cat`: a file's whole contents, read off the disc sector by
/// sector and spoken through the one output door. Line feeds
/// end lines; carriage returns — the other half of some files'
/// endings — are let go; a tab steps to a plain space; any
/// other character the screen cannot honestly draw is passed
/// over, so a text file is itself and a binary file is not
/// mistaken for one.
func runCat() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    if !discIsoFound {
        writeLine(discUnknownFsLine)
        return
    }
    let length = copyArgumentToScratch()
    if length == 0 {
        writeLine(catUsageLine)
        return
    }
    discReadFailed = false
    let outcome = isoResolvePath(length)
    if outcome == pathMissingCode {
        writeStatic(notOnDiscPrefix)
        writePathArgument(length)
        writeNewline()
        return
    }
    if outcome == pathNotDirectoryCode {
        writePathArgument(length)
        writeLine(notDirectorySuffix)
        return
    }
    if outcome == pathReadErrorCode {
        writeLine(discReadErrorLine)
        return
    }
    if resolvedIsDirectory {
        writePathArgument(length)
        writeLine(isDirectorySuffix)
        return
    }
    let buffer = discBuffer()
    var printed: UInt32 = 0
    var sectorIndex: UInt32 = 0
    while printed < resolvedSize {
        if !discReadSector(resolvedExtent + sectorIndex) {
            writeNewline()
            writeLine(discReadErrorLine)
            return
        }
        var count = resolvedSize - printed
        if count > UInt32(discSectorBytes) {
            count = UInt32(discSectorBytes)
        }
        var index = 0
        while index < Int(count) {
            let byte = buffer[index]
            if byte == 0x0A {
                writeNewline()
            } else if byte == 0x09 {
                writeChar(0x20)
            } else if byte >= 0x20 && byte != 0x7F {
                writeChar(byte)
            }
            index += 1
        }
        printed += count
        sectorIndex += 1
    }
    writeNewline()
}

// ---------------------------------------------------------------------------
// Programs (milestone 9): the OS runs something that is not itself.
//
// Until now, every byte the processor ever executed was the kernel's.
// Now a file on the disc — a guest — can be given ground of its own
// and run. HELLO.BIN, COUNT.BIN and BAD.BIN are assembly sources in
// the tree's programs/ directory; the build assembles them into flat
// binaries and packs them onto the disc as files, exactly as
// WELCOME.TXT is packed. They are never linked into or embedded in
// the kernel: the only road from their bytes to the processor runs
// through `run`, the disc driver, and this section.
//
// A guest's estate — fixed, and published to the guests themselves
// in their sources:
//
//   0x40000000  the image's own pages: read and execute, never
//               writable. W^X holds for guests as for the kernel.
//   0x40010000  one scratch page, read and write: the guest's desk.
//   0x40011000  the stack, four pages, read and write; the guest
//               is entered with its stack pointer at 0x40015000.
//   Everything else is the kernel's whole map, present in the
//   guest's tables by descent but stamped supervisor along every
//   branch: the guest is shown the wall, and cannot climb it.
//
// The tables are the guest's own: a fresh root cloning the
// kernel's root, beneath it a private chain — page directory
// pointer table, page directory, page table — so exactly one
// branch, the one toward the estate, can carry the user bit while
// every sibling keeps the kernel's law. The guest runs in ring 3,
// entered by the floor's launch hand through iretq, on those tables.
//
// Its one door back is interrupt 0x80, the only IDT gate stamped
// for ring 3. rax names the service: 1 writes a string (rsi its
// address in the guest's own ground, rdx its length), 2 writes one
// character (rsi's low byte), 0 leaves (rdi the exit code).
// Services 1 and 2 are answered by syscallHandler below; the
// leaving is answered by the floor itself, which carries the
// machine home — kernel tables, the shell's stack, the interrupt
// gate open — and lets the launch return the code. Milestone 10
// adds a third service to the door — 3 yields — answered by the
// floor beside the leaving, in the pair machinery below.
//
// A guest that reaches where it may not faults in user mode, and
// the page-fault handler has a branch for exactly that: report
// the fault, abandon the guest where it stands, and return a
// verdict no exit code can be — all ones — which the shell answers
// with the stopping's own words and a fresh prompt. BAD.BIN exists
// to walk that road on purpose, reaching for the kernel's first
// byte at 0x100000.
//
// Honest edges, stated rather than hidden:
//   - The door validates a write-string's whole reach against the
//     estate before a byte of it is read; the kernel never reads
//     its own memory at a guest's word.
//   - The image is capped at sixteen pages, 64 KiB. A larger file
//     is refused plainly, never truncated.
//   - A fault of any other kind in ring 3 still meets the shared
//     exception handler, which reports and halts; only the page
//     fault — the reach the wall exists to stop — has the killing
//     branch.
//   - When a guest leaves or is stopped, its estate is taken back
//     leaf by leaf and table by table, every frame returned to the
//     allocator's pool.
//
// Milestone 10: two guests at once, taking turns. The command is
// `both`, and it does everything `run` does, twice — two files
// resolved off the disc, two estates built, two images loaded —
// and then hands the pair to the floor's pair launch, which
// keeps each guest's whole state (its tables, its stack, its
// place, its registers) in one of two books in its own storage
// and enters the first. A guest runs until it knocks: services 1
// and 2 are answered as ever, and it resumes; service 3 — yield —
// writes its state into its book and wakes its partner exactly
// where the partner last yielded; service 0 writes its exit code
// into its book and, if its partner still lives, wakes the
// partner to run on alone. When both books say finished — left,
// or stopped — the launch returns, the shell reads the standings
// and verdicts out of the floor's result bookmarks, reports each
// guest truly in the order they were named, takes both estates
// back frame by frame, and stands. A.BIN and B.BIN are the
// witnesses: five tokens against seven, yielding between, so the
// interleave can be read off the screen.
//
// The keeping is cooperative, honestly: a guest that never
// yields keeps the machine — the timer ticks, but no hand in
// this milestone answers it with a switch, and taking the
// machine by force (preemption) is a named later stone. Two
// guests exactly, likewise: the books are two, and no process
// table is pretended. And the wall stands under company as it
// stood alone — the page fault's pair road stops the guest that
// fell and carries the machine to its partner, which finishes
// its work in its own ground, undisturbed; `both /BAD.BIN
// /A.BIN` is the proof, BAD stopped at the wall and A counting
// out its five tokens in the same session.
// ---------------------------------------------------------------------------

/// The estate's fixed address: the guests' whole world begins here.
/// Its place in the tables is chosen to sit under the first branch
/// of every level — root 0, pointer table 1, directory 0 — ground
/// the kernel's own map leaves empty.
let programBase: UInt64 = 0x4000_0000

/// The scratch page's place in the estate's page table, and the
/// stack pages': the image fills the indices below the scratch,
/// so a guest's estate has the same shape whatever its size.
let programScratchIndex = 16
let programStackFirstIndex = 17
let programStackPages = 4

/// The stack's top: one past the stack's last page — the address
/// the guest is entered with in its stack pointer.
let programStackTop: UInt64 =
    programBase + UInt64(programStackFirstIndex + programStackPages) * pageSize

/// The estate's end: everything a guest may touch lies beneath it,
/// and the service door checks every address against this bound.
let programEstateTop: UInt64 = programStackTop

/// The largest image a guest may be: sixteen pages, 64 KiB. The
/// sample guests are two hundred bytes on their proudest day; the
/// cap exists so `run` can refuse plainly, not so it will be met.
let programMaxImageBytes: UInt64 = 16 * pageSize

/// Is a guest running? The page-fault handler reads this to choose
/// its road: while it stands, a user-mode fault is a guest's fall,
/// to be reported and stopped; without it, every fault keeps the
/// old road to the halt.
var programRunning = false

/// Is the running guest one of a pair (milestone 10)? The page-
/// fault handler reads this beside programRunning: while it
/// stands, a fallen guest is stopped by the floor's pair road,
/// which carries the machine to its partner instead of home.
var pairRunning = false

/// The standings the floor writes in a finished guest's book, and
/// copies into its result bookmarks for the shell to read: a
/// guest that left by the door, and a guest that was stopped.
/// (0, still alive, is the standing of a guest mid-session and is
/// never read here: the pair launch returns only when neither
/// guest wears it.)
let pairStatusExited: UInt64 = 1
let pairStatusStopped: UInt64 = 2

/// The two paths of a `both` line, as reaches of the one path
/// scratch: the first path is the bytes before bothFirstEnd, the
/// second the bytes from bothSecondStart to bothSecondEnd. The
/// splitter below leaves them; the resolver, the report and the
/// running line read them.
var bothFirstEnd = 0
var bothSecondStart = 0
var bothSecondEnd = 0

/// both's vocabulary: the usage, the running line's joints, and
/// the two reports — a leaving spoken with its code, a stopping
/// spoken plainly — each beside the path as it was typed.
let bothUsageLine: StaticString =
    "both wants two programs: both /A.BIN /B.BIN"
let bothAndWord: StaticString = " and "
let bothTogetherSuffix: StaticString = " together:"
let bothExitedWord: StaticString = " exited: "
let bothStoppedSuffix: StaticString = " was stopped."

/// The stopped guest's testimony, kept by the fault handler before
/// the abandon: the address it reached for and the error code's
/// word. The shell does not speak them — the report already stands
/// at the screen's top — but they are kept, because a stopping
/// should leave its facts where they can be read.
var programFaultAddress: UInt64 = 0
var programFaultError: UInt64 = 0

/// The verdict of a stopped guest: all ones — a value no honest
/// exit code is mistaken for, since the guests' door carries the
/// code in a register the shell reads whole. `run` answers this
/// verdict with the stopping's words, any other with the code.
let programKilledVerdict: UInt64 = 0xFFFF_FFFF_FFFF_FFFF

/// The live guest's page table address, remembered between the
/// building of its estate and the reading of its image off the
/// disc: the loader copies the file's bytes into the very frames
/// the table names.
var programTableAddress: UInt64 = 0

/// run's vocabulary: the usage, the refusals, and the two reports.
let runUsageLine: StaticString = "run wants a program: run /HELLO.BIN"
let runNoPagingLine: StaticString =
    "Paging is not standing; a guest needs the kernel's own tables."
let runEmptySuffix: StaticString = " is empty; there is nothing to run."
let runTooBigLine: StaticString =
    "That file is larger than the ground a guest may have (64 KiB)."
let runNoMemoryLine: StaticString =
    "Memory could not pay for the guest's ground."
let runRunningPrefix: StaticString = "Running "
let runRunningSuffix: StaticString = ":"
let programExitedPrefix: StaticString = "Program exited: "
let programKilledLine: StaticString =
    "The guest was stopped. The shell stands."

/// Wipes one frame clean, byte by byte — the guest's image frames
/// and desk and stack begin zeroed, so no byte of a previous
/// tenant, or of the pool's past, is part of a guest's world.
func wipeFrame(_ frame: UInt64) {
    let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(frame))!
    for index in 0 ..< Int(pageSize) {
        bytes[index] = 0
    }
}

/// Builds a guest's estate: its own page tables, cloned from the
/// kernel's and branched privately toward the estate, with the
/// image's pages, the scratch page and the stack pages laid in as
/// fresh frames under the laws the section header states. Returns
/// the estate's root on success; on any failure of the pool to
/// pay, takes back whatever was built and returns 0.
func buildProgramSpace(_ size: UInt32) -> UInt64 {
    let imagePages = Int((UInt64(size) + pageSize - 1) / pageSize)
    let root = pagingNewTable()
    if root == 0 { return 0 }
    let kernelRoot = pagingRootAddress
    for index in 0 ..< 512 {
        setPagingEntry(root, index, pagingEntry(kernelRoot, index))
    }
    let kernelPointerTable =
        pagingEntry(kernelRoot, 0) & pagingAddressMask
    let pointerTable = pagingNewTable()
    if pointerTable == 0 {
        freeFrame(root)
        return 0
    }
    for index in 0 ..< 512 {
        setPagingEntry(pointerTable, index,
                       pagingEntry(kernelPointerTable, index))
    }
    // The one branch opened to ring 3 above the estate: the root's
    // first entry now names the guest's own pointer table, under
    // the kernel entry's own flags with the user bit added. Every
    // other entry in both cloned tables still speaks with the
    // kernel's voice, so the ground behind them stays shut.
    setPagingEntry(root, 0,
                   pointerTable
                       | (pagingEntry(kernelRoot, 0) & 0xFFF)
                       | pteUser)
    let directory = pagingNewTable()
    if directory == 0 {
        teardownProgramSpace(root)
        return 0
    }
    setPagingEntry(pointerTable, 1,
                   directory | ptePresent | pteWritable | pteUser)
    let table = pagingNewTable()
    if table == 0 {
        teardownProgramSpace(root)
        return 0
    }
    setPagingEntry(directory, 0,
                   table | ptePresent | pteWritable | pteUser)
    programTableAddress = table
    var index = 0
    while index < imagePages {
        let frame = allocFrame()
        if frame == 0 {
            teardownProgramSpace(root)
            return 0
        }
        wipeFrame(frame)
        // The image: readable and executable, never writable —
        // and readable because a flat guest keeps its words in
        // its image, as the samples keep their greetings.
        setPagingEntry(table, index, frame | ptePresent | pteUser)
        index += 1
    }
    let scratch = allocFrame()
    if scratch == 0 {
        teardownProgramSpace(root)
        return 0
    }
    wipeFrame(scratch)
    setPagingEntry(table, programScratchIndex,
                   scratch | ptePresent | pteWritable | pteUser
                       | pteNoExecute)
    var stackIndex = 0
    while stackIndex < programStackPages {
        let frame = allocFrame()
        if frame == 0 {
            teardownProgramSpace(root)
            return 0
        }
        wipeFrame(frame)
        setPagingEntry(table, programStackFirstIndex + stackIndex,
                       frame | ptePresent | pteWritable | pteUser
                           | pteNoExecute)
        stackIndex += 1
    }
    return root
}

/// Takes a guest's estate back: every present leaf's frame, then
/// the page table, the directory, the pointer table and the root,
/// each returned to the pool. The shared tables the clones point
/// *into* — the kernel's own branches beneath the copied entries —
/// are never freed: they are recognised by their address, the one
/// pointer table that is not the guest's own. A half-built estate
/// takes the same road home, which is why the builder calls this
/// on its failures.
func teardownProgramSpace(_ root: UInt64) {
    if root == 0 { return }
    let kernelPointerTable =
        pagingEntry(pagingRootAddress, 0) & pagingAddressMask
    let pointerTable = pagingEntry(root, 0) & pagingAddressMask
    if pointerTable != 0 && pointerTable != kernelPointerTable {
        let directory = pagingEntry(pointerTable, 1) & pagingAddressMask
        if directory != 0 {
            let table = pagingEntry(directory, 0) & pagingAddressMask
            if table != 0 {
                for index in 0 ..< 512 {
                    let leaf = pagingEntry(table, index)
                    if leaf & ptePresent != 0 {
                        freeFrame(leaf & pagingAddressMask)
                    }
                }
                freeFrame(table)
            }
            freeFrame(directory)
        }
        freeFrame(pointerTable)
    }
    freeFrame(root)
    programTableAddress = 0
}

/// Reads a guest's image off the disc into the frames its page
/// table names: sector by sector through the milestone-8 driver,
/// byte by byte into the frames — which the kernel's identity map
/// lets it touch by their physical addresses while the guest's
/// own tables are still only a building, not yet the machine's
/// law. False when a sector refuses to be read.
func loadProgramImage(_ extent: UInt32, _ size: UInt32) -> Bool {
    let buffer = discBuffer()
    var written: UInt32 = 0
    var sectorIndex: UInt32 = 0
    while written < size {
        if !discReadSector(extent + sectorIndex) { return false }
        var count = size - written
        if count > UInt32(discSectorBytes) {
            count = UInt32(discSectorBytes)
        }
        var index = 0
        while index < Int(count) {
            let at = written + UInt32(index)
            let frame = pagingEntry(programTableAddress,
                                    Int(at / UInt32(pageSize)))
                & pagingAddressMask
            let destination = UnsafeMutablePointer<UInt8>(
                bitPattern: UInt(frame + UInt64(at % UInt32(pageSize))))!
            destination.pointee = buffer[index]
            index += 1
        }
        written += count
        sectorIndex += 1
    }
    return true
}

/// The service door's answering voice, called by the floor's stub
/// with the guest's registers translated into arguments: the
/// service number, then the guest's rsi and rdx. The answer rides
/// home in the guest's rax. The door's services, as the guests'
/// sources publish them:
///
///   1  write a string — the first argument is the string's
///      address in the guest's ground, the second its length.
///      The whole reach is checked against the estate before a
///      byte is read; refused reaches answer all-ones, the door's
///      no. Bytes are drawn by the screen's own rules, the ones
///      `cat` speaks by: line feeds end lines, tabs step to a
///      space, the undrawable are passed over.
///   2  write one character — the first argument's low byte,
///      under the same drawing rules.
///   Anything else: not a service; the answer is all-ones.
///
/// Service 0, the leaving, never arrives here: the floor answers
/// it, because coming home is stacks and table roots, not policy.
/// Service 3, the yielding (milestone 10), never arrives either,
/// for the same reason: whose turn it is is books and table
/// roots. What reaches this voice is speech — services 1 and 2 —
/// and anything else, which is answered no.
@_cdecl("cardnull_syscall_handler")
public func syscallHandler(_ service: UInt64, _ first: UInt64,
                           _ second: UInt64) -> UInt64 {
    if service == 1 {
        if first < programBase { return UInt64.max }
        let offset = first - programBase
        if second > programEstateTop - programBase { return UInt64.max }
        if offset > (programEstateTop - programBase) - second {
            return UInt64.max
        }
        var index: UInt64 = 0
        while index < second {
            let byte = UnsafePointer<UInt8>(
                bitPattern: UInt(first + index))!.pointee
            printGuestByte(byte)
            index += 1
        }
        return second
    }
    if service == 2 {
        printGuestByte(UInt8(truncatingIfNeeded: first))
        return 1
    }
    return UInt64.max
}

/// One byte of a guest's speech, drawn by the screen's rules —
/// the same ones `cat` prints files by.
func printGuestByte(_ byte: UInt8) {
    if byte == 0x0A {
        writeNewline()
    } else if byte == 0x09 {
        writeChar(0x20)
    } else if byte >= 0x20 && byte != 0x7F {
        writeChar(byte)
    }
}

/// `run`: the milestone's whole road in one walk — the file found
/// on the disc by the milestone-8 reader, its size weighed against
/// the estate's cap, a house of tables built for it, its bytes
/// read off the disc into that house, the floor's hand dropping
/// the machine into ring 3 at its first byte, and the report:
/// the exit code spoken truly when the guest leaves by the door,
/// the stopping's own words when it was stopped.
func runProgram() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    if !discIsoFound {
        writeLine(discUnknownFsLine)
        return
    }
    let length = copyArgumentToScratch()
    if length == 0 {
        writeLine(runUsageLine)
        return
    }
    if !pagingReady {
        writeLine(runNoPagingLine)
        return
    }
    discReadFailed = false
    let outcome = isoResolvePath(length)
    if outcome == pathMissingCode {
        writeStatic(notOnDiscPrefix)
        writePathArgument(length)
        writeNewline()
        return
    }
    if outcome == pathNotDirectoryCode {
        writePathArgument(length)
        writeLine(notDirectorySuffix)
        return
    }
    if outcome == pathReadErrorCode {
        writeLine(discReadErrorLine)
        return
    }
    if resolvedIsDirectory {
        writePathArgument(length)
        writeLine(isDirectorySuffix)
        return
    }
    // A feather is not a bare program (milestone 11): its card
    // stands in front of its bytes, and a raw loader executing
    // the card as code is exactly what the format exists to
    // prevent. The first sector is peeked at, and a package is
    // named, refused, and sent to its own command.
    if resolvedSize >= UInt32(featherMagicLength + 1)
        && discReadSector(resolvedExtent)
        && featherMagicAt(discBuffer(), 0,
                          resolvedSize < UInt32(discSectorBytes)
                              ? Int(resolvedSize) : discSectorBytes) {
        writePathArgument(length)
        writeStatic(runFeatherMiddle)
        writePathArgument(length)
        writeNewline()
        return
    }
    if resolvedSize == 0 {
        writePathArgument(length)
        writeLine(runEmptySuffix)
        return
    }
    if UInt64(resolvedSize) > programMaxImageBytes {
        writeLine(runTooBigLine)
        return
    }
    let root = buildProgramSpace(resolvedSize)
    if root == 0 {
        writeLine(runNoMemoryLine)
        return
    }
    if !loadProgramImage(resolvedExtent, resolvedSize) {
        teardownProgramSpace(root)
        writeLine(discReadErrorLine)
        return
    }
    writeStatic(runRunningPrefix)
    writePathArgument(length)
    writeLine(runRunningSuffix)
    programRunning = true
    let verdict = cardnullLaunchProgram(root, programBase, programStackTop)
    programRunning = false
    teardownProgramSpace(root)
    if verdict == programKilledVerdict {
        writeLine(programKilledLine)
    } else {
        writeStatic(programExitedPrefix)
        writeNumber(verdict)
        writeNewline()
    }
}

/// Writes one reach of the path scratch, as the typist wrote it:
/// the bytes from `start` up to `end`. `both` keeps two paths in
/// the one scratch, and its answers name each as it was asked
/// for, so the whole-scratch writer above is not enough.
func writePathSlice(_ start: Int, _ end: Int) {
    let path = discPath()
    var index = start
    while index < end {
        writeChar(path[index])
        index += 1
    }
}

/// Splits the argument already copied into the path scratch by
/// copyArgumentToScratch into exactly two tokens — no more, no
/// fewer, because `both` carries two guests and pretending
/// otherwise would be a quiet lie. The first token stands at the
/// scratch's head; the second's reach is left in bothSecondStart
/// and bothSecondEnd. False when the line does not hold exactly
/// two tokens; the caller answers with the usage.
func splitBothArguments(_ length: Int) -> Bool {
    let path = discPath()
    var index = 0
    while index < length && path[index] != 0x20 { index += 1 }
    bothFirstEnd = index
    if bothFirstEnd == 0 { return false }
    while index < length && path[index] == 0x20 { index += 1 }
    if index >= length { return false }
    bothSecondStart = index
    while index < length && path[index] != 0x20 { index += 1 }
    bothSecondEnd = index
    while index < length && path[index] == 0x20 { index += 1 }
    return index >= length
}

/// One guest file weighed for the road, in the reach of the
/// scratch where its path lies: resolved through the milestone-8
/// reader and measured against the estate's laws — a file, not a
/// directory; something in it; no more than the cap. The refusal
/// that fits is spoken, naming the path as typed, and false
/// returned; on success the resolved extent and size stand in
/// resolvedExtent and resolvedSize, as `run` leaves them. `run`
/// keeps its own inlined walk, word for word as milestone 9 left
/// it; this is `both`'s twin of it, shared by its two guests.
func resolveGuestFile(_ start: Int, _ end: Int) -> Bool {
    discReadFailed = false
    let outcome = isoResolvePathIn(start, end)
    if outcome == pathMissingCode {
        writeStatic(notOnDiscPrefix)
        writePathSlice(start, end)
        writeNewline()
        return false
    }
    if outcome == pathNotDirectoryCode {
        writePathSlice(start, end)
        writeLine(notDirectorySuffix)
        return false
    }
    if outcome == pathReadErrorCode {
        writeLine(discReadErrorLine)
        return false
    }
    if resolvedIsDirectory {
        writePathSlice(start, end)
        writeLine(isDirectorySuffix)
        return false
    }
    if resolvedSize == 0 {
        writePathSlice(start, end)
        writeLine(runEmptySuffix)
        return false
    }
    if UInt64(resolvedSize) > programMaxImageBytes {
        writeLine(runTooBigLine)
        return false
    }
    return true
}

/// One guest's report at a pair session's end, in the order the
/// guests were named: the path as typed, then its ending — the
/// exit code when it left by the door, the plain word when it
/// was stopped.
func reportBothGuest(_ start: Int, _ end: Int,
                     _ status: UInt64, _ verdict: UInt64) {
    writePathSlice(start, end)
    if status == pairStatusStopped {
        writeLine(bothStoppedSuffix)
    } else {
        writeStatic(bothExitedWord)
        writeNumber(verdict)
        writeNewline()
    }
}

/// `both`: milestone 10's whole road — `run`'s walk walked twice,
/// then the pair launch. Two files are weighed and read off the
/// disc, two estates built and filled; the floor's pair launch
/// enters the first guest and keeps the turning from there. When
/// it returns, both guests stand finished — left or stopped —
/// and the shell reads their standings and verdicts out of the
/// floor's result bookmarks, reports each truly, and takes both
/// estates back frame by frame, so `mem` reads the same numbers
/// before a session and after it, as it did for `run`.
func runBoth() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    if !discIsoFound {
        writeLine(discUnknownFsLine)
        return
    }
    let length = copyArgumentToScratch()
    if length == 0 || !splitBothArguments(length) {
        writeLine(bothUsageLine)
        return
    }
    if !pagingReady {
        writeLine(runNoPagingLine)
        return
    }
    if !resolveGuestFile(0, bothFirstEnd) { return }
    let extentA = resolvedExtent
    let sizeA = resolvedSize
    if !resolveGuestFile(bothSecondStart, bothSecondEnd) { return }
    let extentB = resolvedExtent
    let sizeB = resolvedSize
    let rootA = buildProgramSpace(sizeA)
    if rootA == 0 {
        writeLine(runNoMemoryLine)
        return
    }
    if !loadProgramImage(extentA, sizeA) {
        teardownProgramSpace(rootA)
        writeLine(discReadErrorLine)
        return
    }
    let rootB = buildProgramSpace(sizeB)
    if rootB == 0 {
        teardownProgramSpace(rootA)
        writeLine(runNoMemoryLine)
        return
    }
    if !loadProgramImage(extentB, sizeB) {
        teardownProgramSpace(rootB)
        teardownProgramSpace(rootA)
        writeLine(discReadErrorLine)
        return
    }
    writeStatic(runRunningPrefix)
    writePathSlice(0, bothFirstEnd)
    writeStatic(bothAndWord)
    writePathSlice(bothSecondStart, bothSecondEnd)
    writeLine(bothTogetherSuffix)
    programRunning = true
    pairRunning = true
    let verdictA = cardnullLaunchPair(rootA, programBase, programStackTop,
                                      rootB, programBase, programStackTop)
    pairRunning = false
    programRunning = false
    let statusA = cardnullPairStatusA()
    let statusB = cardnullPairStatusB()
    let verdictB = cardnullPairVerdictB()
    teardownProgramSpace(rootA)
    teardownProgramSpace(rootB)
    reportBothGuest(0, bothFirstEnd, statusA, verdictA)
    reportBothGuest(bothSecondStart, bothSecondEnd, statusB, verdictB)
}

// ---------------------------------------------------------------------------
// Feathers (milestone 11): the OS learns its own package format.
//
// A feather is one file on the disc: a plain-text card and,
// behind a line of three dashes, a program — a flat guest image
// of exactly the kind `run` loads. The format is written down
// in docs/FEATHER.md; what stands here is its handler. The card
// names the program before it runs — title, maker, version,
// and the maker's support line — and the packer's reckoning
// travels with it: the program's size and its FNV-1a 64
// checksum, which the handler reckons again over the bytes the
// disc actually delivered before a single one of them runs. A
// feather whose program does not match its card is refused,
// plainly, and not run.
//
// The checksum is an integrity check against corruption —
// nothing more. It is not a signature: anyone can recompute
// it, so it proves only that the program matches this card,
// never that Cardnull reviewed or vouches for either. The day
// feathers are reviewed and cryptographically signed by
// Cardnull — the store's day — a true signature will stand in
// the format; until then nothing here claims or imitates one,
// and the modesty is part of the format's document.
//
// `feather` walks `run`'s road with a reading first: the file
// resolved by the milestone-8 reader, weighed (the whole file
// may hold the card's utmost plus a program of the guest cap's
// utmost), read whole into a heap block, its card parsed and
// proven, its card printed, and only then the program laid
// into an estate and run — same tables, same door, same
// reports as a bare guest. The heap block is handed back on
// every road out and the estate by the teardown, so `mem` and
// `heap` read the same after a feather as before it.
//
// `run` knows the feather's first line too: pointed at a
// package it refuses, and names this command. A raw loader
// executing a card as code is exactly what the format exists
// to prevent.
// ---------------------------------------------------------------------------

/// The feather's shape, as docs/FEATHER.md lays it down: the
/// magic line that opens every feather, and the card's utmost
/// reach — a card that has not ended within the first 4 KiB is
/// not read further — so the whole file may hold at most the
/// card's utmost and a program of the guest cap's utmost.
let featherMagicLine: StaticString = "CARDNULL FEATHER 1"
let featherMagicLength = 18
let featherCardMaxBytes = 4096
let featherFileMaxBytes = featherCardMaxBytes + 65536

/// The card's keys, in the folded lowercase the parser folds
/// what it reads down to: the maker's four spoken words, and
/// the packer's two reckoned ones.
let featherTitleKey: StaticString = "title"
let featherMakerKey: StaticString = "maker"
let featherVersionKey: StaticString = "version"
let featherSupportKey: StaticString = "support"
let featherSizeKey: StaticString = "program-size"
let featherChecksumKey: StaticString = "program-fnva"

/// The parse's answers: the card stands, or the honest reason
/// it does not — no magic line to open it, a card that cannot
/// stand (a word missing, a measure disagreeing), or a program
/// that betrays its card's checksum.
let featherOKCode = 0
let featherNotCode = 1
let featherBrokenCode = 2
let featherTamperedCode = 3

/// The card the last parse read: the program's place in the
/// reading, and each spoken value's place — a start and a
/// length in the reading, the length -1 while the card has not
/// named it. The reckoned pair stand beside them.
var featherProgramStart = 0
var featherProgramLength = 0
var featherTitleStart = 0
var featherTitleLength = -1
var featherMakerStart = 0
var featherMakerLength = -1
var featherVersionStart = 0
var featherVersionLength = -1
var featherSupportStart = 0
var featherSupportLength = -1
var featherCardSize: UInt64 = 0
var featherCardChecksum: UInt64 = 0
var featherCardSizeFound = false
var featherCardChecksumFound = false

/// feather's vocabulary: the usage, the refusals, and the
/// card's printed labels — the honest label, read before the
/// run, with the checksum's modesty spoken in its own line.
let featherUsageLine: StaticString =
    "feather wants a package: feather /HELLO.FEATHER"
let featherTooBigLine: StaticString =
    "That file is larger than a feather may be (4 KiB of card, 64 KiB of program)."
let featherNoMemoryLine: StaticString =
    "Memory could not pay for the feather's reading."
let featherNotSuffix: StaticString = " is not a feather."
let featherBrokenLine: StaticString =
    "That feather's card cannot be read - it names too little, or its measures disagree. It was not run."
let featherTamperedLine: StaticString =
    "That feather's program does not match its card's checksum - it may be damaged or altered. It was not run."
let featherOpeningPrefix: StaticString = "Opening "
let featherOpeningSuffix: StaticString = ":"
let featherTitleLabel: StaticString = "  Title:   "
let featherMakerLabel: StaticString = "  Maker:   "
let featherVersionLabel: StaticString = "  Version: "
let featherSupportLabel: StaticString = "  Support: "
let featherIntegrityLine: StaticString =
    "  Integrity: checksum verified - an integrity check, not a signature."

/// run's word for a package, spoken between the path named
/// twice: the refusal, and the road to the right command.
let runFeatherMiddle: StaticString =
    " is a feather - a package with a card. Open it with: feather "

/// Folds one byte the way the card's keys are folded: a capital
/// becomes its small brother; every other byte stands as it is.
func featherFold(_ byte: UInt8) -> UInt8 {
    if byte >= 0x41 && byte <= 0x5A { return byte + 0x20 }
    return byte
}

/// True when the bytes at `start` open with the feather's magic
/// line — the format's name and version, whole, with a line
/// feed after them. A prefix is not enough: the line is the
/// signature of the shape, and it is matched entire.
func featherMagicAt(_ base: UnsafeMutablePointer<UInt8>,
                    _ start: Int, _ available: Int) -> Bool {
    if available < featherMagicLength + 1 { return false }
    var index = 0
    while index < featherMagicLength {
        if base[start + index] != featherMagicLine.utf8Start[index] {
            return false
        }
        index += 1
    }
    return base[start + featherMagicLength] == 0x0A
}

/// True when the reach at `start` in the reading spells the
/// key — the reading's side folded down, the key already small.
func featherKeyMatches(_ base: UnsafeMutablePointer<UInt8>,
                       _ start: Int, _ length: Int,
                       _ key: StaticString) -> Bool {
    var index = 0
    while key.utf8Start[index] != 0 {
        if index >= length { return false }
        if featherFold(base[start + index]) != key.utf8Start[index] {
            return false
        }
        index += 1
    }
    return index == length
}

/// Reads a plain decimal out of the reading: digits only, at
/// least one, and at most ten — room for any size this kernel
/// will hold, and no road to an overflowing reckoning.
func featherReadDecimal(_ base: UnsafeMutablePointer<UInt8>,
                        _ start: Int, _ length: Int) -> UInt64? {
    if length == 0 || length > 10 { return nil }
    var value: UInt64 = 0
    var index = 0
    while index < length {
        let byte = base[start + index]
        if byte < 0x30 || byte > 0x39 { return nil }
        value = value * 10 + UInt64(byte - 0x30)
        index += 1
    }
    return value
}

/// Reads the checksum's sixteen hex digits out of the reading,
/// either case honoured. Anything else is not a checksum.
func featherReadHex(_ base: UnsafeMutablePointer<UInt8>,
                    _ start: Int, _ length: Int) -> UInt64? {
    if length != 16 { return nil }
    var value: UInt64 = 0
    var index = 0
    while index < length {
        let byte = featherFold(base[start + index])
        let digit: UInt64
        if byte >= 0x30 && byte <= 0x39 {
            digit = UInt64(byte - 0x30)
        } else if byte >= 0x61 && byte <= 0x66 {
            digit = UInt64(byte - 0x61) + 10
        } else {
            return nil
        }
        value = value * 16 + digit
        index += 1
    }
    return value
}

/// Parses the card of the feather held in a reading — the
/// file's whole bytes at `base`, `size` of them — and leaves
/// what it finds in the globals above. The walk: the magic
/// line, then card lines until the separator, each a key, a
/// colon, a value; then the standing's proofs — every word
/// the card owes present and spoken, the packer's measures
/// present, the program's size within the guest cap, the
/// program standing exactly where the card ends and the file
/// ending exactly where the program does — and at last the
/// checksum, reckoned over the program's own bytes and
/// compared against the card's word.
func parseFeatherCard(_ base: UnsafeMutablePointer<UInt8>,
                      _ size: Int) -> Int {
    featherTitleLength = -1
    featherMakerLength = -1
    featherVersionLength = -1
    featherSupportLength = -1
    featherCardSizeFound = false
    featherCardChecksumFound = false
    featherProgramStart = 0
    featherProgramLength = 0
    if !featherMagicAt(base, 0, size) { return featherNotCode }
    var pos = featherMagicLength + 1
    let limit = size < featherCardMaxBytes ? size : featherCardMaxBytes
    var sawSeparator = false
    while pos < limit {
        var lineEnd = pos
        while lineEnd < size && base[lineEnd] != 0x0A {
            lineEnd += 1
        }
        var lineLength = lineEnd - pos
        if lineLength > 0 && base[pos + lineLength - 1] == 0x0D {
            lineLength -= 1   // a carriage return is forgiven
        }
        if lineLength == 3 && base[pos] == 0x2D
            && base[pos + 1] == 0x2D && base[pos + 2] == 0x2D {
            featherProgramStart = lineEnd < size ? lineEnd + 1 : size
            sawSeparator = true
            break
        }
        var colon = -1
        var scan = 0
        while scan < lineLength {
            if base[pos + scan] == 0x3A {   // ':'
                colon = scan
                break
            }
            scan += 1
        }
        if colon >= 0 {
            var keyLength = colon
            while keyLength > 0
                && base[pos + keyLength - 1] == 0x20 {
                keyLength -= 1
            }
            var valueStart = pos + colon + 1
            var valueLength = lineLength - (colon + 1)
            while valueLength > 0 && base[valueStart] == 0x20 {
                valueStart += 1
                valueLength -= 1
            }
            while valueLength > 0
                && base[valueStart + valueLength - 1] == 0x20 {
                valueLength -= 1
            }
            if featherKeyMatches(base, pos, keyLength, featherTitleKey) {
                featherTitleStart = valueStart
                featherTitleLength = valueLength
            } else if featherKeyMatches(base, pos, keyLength,
                                        featherMakerKey) {
                featherMakerStart = valueStart
                featherMakerLength = valueLength
            } else if featherKeyMatches(base, pos, keyLength,
                                        featherVersionKey) {
                featherVersionStart = valueStart
                featherVersionLength = valueLength
            } else if featherKeyMatches(base, pos, keyLength,
                                        featherSupportKey) {
                featherSupportStart = valueStart
                featherSupportLength = valueLength
            } else if featherKeyMatches(base, pos, keyLength,
                                        featherSizeKey) {
                if let reckoned = featherReadDecimal(
                    base, valueStart, valueLength) {
                    featherCardSize = reckoned
                    featherCardSizeFound = true
                }
            } else if featherKeyMatches(base, pos, keyLength,
                                        featherChecksumKey) {
                if let reckoned = featherReadHex(
                    base, valueStart, valueLength) {
                    featherCardChecksum = reckoned
                    featherCardChecksumFound = true
                }
            }
        }
        if lineEnd >= size { break }
        pos = lineEnd + 1
    }
    if !sawSeparator { return featherBrokenCode }
    if featherProgramStart > featherCardMaxBytes {
        return featherBrokenCode
    }
    if featherTitleLength < 1 || featherMakerLength < 1
        || featherVersionLength < 1 || featherSupportLength < 1 {
        return featherBrokenCode
    }
    if !featherCardSizeFound || !featherCardChecksumFound {
        return featherBrokenCode
    }
    if featherCardSize == 0
        || featherCardSize > programMaxImageBytes {
        return featherBrokenCode
    }
    if featherProgramStart + Int(featherCardSize) != size {
        return featherBrokenCode
    }
    featherProgramLength = Int(featherCardSize)
    // The checksum, reckoned over the program's own bytes:
    // FNV-1a, 64-bit, as docs/FEATHER.md lays it down and the
    // packer in tools/ reckons it — the same numbers, in the
    // same order, on both sides of the disc.
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    var index = 0
    while index < featherProgramLength {
        hash ^= UInt64(base[featherProgramStart + index])
        hash = hash &* 0x0000_0100_0000_01B3
        index += 1
    }
    if hash != featherCardChecksum { return featherTamperedCode }
    return featherOKCode
}

/// Reads a whole file off the disc into a block the caller
/// already holds: sector by sector through the milestone-8
/// driver, byte by byte into the block. False when a sector
/// refuses to be read.
func readWholeFileInto(_ base: UnsafeMutablePointer<UInt8>,
                       _ extent: UInt32, _ size: UInt32) -> Bool {
    let buffer = discBuffer()
    var written: UInt32 = 0
    var sectorIndex: UInt32 = 0
    while written < size {
        if !discReadSector(extent + sectorIndex) { return false }
        var count = size - written
        if count > UInt32(discSectorBytes) {
            count = UInt32(discSectorBytes)
        }
        var index = 0
        while index < Int(count) {
            base[Int(written) + index] = buffer[index]
            index += 1
        }
        written += count
        sectorIndex += 1
    }
    return true
}

/// Lays a program out of a reading into the frames its page
/// table names — loadProgramImage's twin, for bytes already
/// standing in the kernel's own memory: the feather's program,
/// lifted out of its package. The estate's frames were wiped
/// when they were built, so what lies past the program's end
/// in its last page is zeros, as it was for a guest read
/// straight off the disc.
func loadProgramImageFromReading(
    _ base: UnsafeMutablePointer<UInt8>,
    _ start: Int, _ size: UInt32
) {
    var at: UInt32 = 0
    while at < size {
        let frame = pagingEntry(programTableAddress,
                                Int(at / UInt32(pageSize)))
            & pagingAddressMask
        let destination = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(frame + UInt64(at % UInt32(pageSize))))!
        destination.pointee = base[start + Int(at)]
        at += 1
    }
}

/// Speaks one of the card's values, byte for byte as its maker
/// wrote it, and ends the line.
func writeFeatherValue(_ base: UnsafeMutablePointer<UInt8>,
                       _ start: Int, _ length: Int) {
    var index = 0
    while index < length {
        writeChar(base[start + index])
        index += 1
    }
    writeNewline()
}

/// `feather`: the package's whole road — the file found on the
/// disc, read whole, its card parsed and proven, its card
/// printed, and its program run down milestone 9's road, with
/// the report spoken truly. Every refusal on the road is
/// plain, and every one of them means the program did not run.
func runFeather() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    if !discIsoFound {
        writeLine(discUnknownFsLine)
        return
    }
    let length = copyArgumentToScratch()
    if length == 0 {
        writeLine(featherUsageLine)
        return
    }
    if !pagingReady {
        writeLine(runNoPagingLine)
        return
    }
    discReadFailed = false
    let outcome = isoResolvePath(length)
    if outcome == pathMissingCode {
        writeStatic(notOnDiscPrefix)
        writePathArgument(length)
        writeNewline()
        return
    }
    if outcome == pathNotDirectoryCode {
        writePathArgument(length)
        writeLine(notDirectorySuffix)
        return
    }
    if outcome == pathReadErrorCode {
        writeLine(discReadErrorLine)
        return
    }
    if resolvedIsDirectory {
        writePathArgument(length)
        writeLine(isDirectorySuffix)
        return
    }
    if resolvedSize == 0 {
        writePathArgument(length)
        writeLine(runEmptySuffix)
        return
    }
    if Int(resolvedSize) > featherFileMaxBytes {
        writeLine(featherTooBigLine)
        return
    }
    let address = heapAlloc(Int(resolvedSize))
    if address == 0 {
        writeLine(featherNoMemoryLine)
        return
    }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(address))!
    if !readWholeFileInto(base, resolvedExtent, resolvedSize) {
        heapFree(address)
        writeLine(discReadErrorLine)
        return
    }
    let parsed = parseFeatherCard(base, Int(resolvedSize))
    if parsed == featherNotCode {
        heapFree(address)
        writePathArgument(length)
        writeLine(featherNotSuffix)
        return
    }
    if parsed == featherBrokenCode {
        heapFree(address)
        writeLine(featherBrokenLine)
        return
    }
    if parsed == featherTamperedCode {
        heapFree(address)
        writeLine(featherTamperedLine)
        return
    }
    // The card, printed before the program runs: the honest
    // label, read first — and the checksum's modesty spoken in
    // its own line, so no reader mistakes it for a signature.
    writeStatic(featherOpeningPrefix)
    writePathArgument(length)
    writeLine(featherOpeningSuffix)
    writeStatic(featherTitleLabel)
    writeFeatherValue(base, featherTitleStart, featherTitleLength)
    writeStatic(featherMakerLabel)
    writeFeatherValue(base, featherMakerStart, featherMakerLength)
    writeStatic(featherVersionLabel)
    writeFeatherValue(base, featherVersionStart, featherVersionLength)
    writeStatic(featherSupportLabel)
    writeFeatherValue(base, featherSupportStart, featherSupportLength)
    writeLine(featherIntegrityLine)
    let root = buildProgramSpace(UInt32(featherProgramLength))
    if root == 0 {
        heapFree(address)
        writeLine(runNoMemoryLine)
        return
    }
    loadProgramImageFromReading(base, featherProgramStart,
                                UInt32(featherProgramLength))
    heapFree(address)
    writeStatic(runRunningPrefix)
    writePathArgument(length)
    writeLine(runRunningSuffix)
    programRunning = true
    let verdict = cardnullLaunchProgram(root, programBase,
                                        programStackTop)
    programRunning = false
    teardownProgramSpace(root)
    if verdict == programKilledVerdict {
        writeLine(programKilledLine)
    } else {
        writeStatic(programExitedPrefix)
        writeNumber(verdict)
        writeNewline()
    }
}

// ---------------------------------------------------------------------------
// The graphical face (milestone 12).
//
// The last stone of the first ladder: the OS gets a face. Since
// milestone 5 the screen has been a field of pixels with letters
// drawn on it; this milestone draws the rest — a desktop, one
// window standing on it, and a pointer that answers the mouse.
//
// The face is deliberately small, and its smallness is stated
// plainly: one window, in one place, that cannot be dragged or
// resized; one button that counts its clicks; one close box.
// There is no window manager here and no program but the kernel
// draws — graphical guests are a later era, and nothing in this
// section pretends otherwise.
//
// How it is put together:
//
//   Painting. The kernel draws straight into the framebuffer the
//   boot handed over — the same ground the text console paints
//   its grid into, already reserved out of the frame pool's reach
//   at boot. No back buffer is kept: the desktop is drawn once,
//   whole, and after that only small rects are ever repainted
//   (the button's face, the click count). The face therefore
//   takes NO frames and NO heap: entering and leaving it leaves
//   `mem` and `heap` reading exactly as they read before, which
//   the milestone's proof leans on.
//
//   Colour. A colour is reckoned once into the framebuffer's own
//   packing — each 8-bit channel scaled into the field the boot
//   tag named for it — and laid down as one raw word. At 24 bits
//   the "word" is the pixel's three bytes, each channel's byte in
//   its own slot. guiRawPixel is the only place that knows this.
//
//   The pointer. A twelve-by-sixteen arrow, drawn from the art
//   below. It is the only thing that ever moves across finished
//   painting, so it alone needs an undo: before it is drawn, the
//   pixels beneath it are lifted into the floor's cushion, and
//   when it moves or goes home they are laid back — no trail,
//   because the ground is restored, not repainted from memory.
//
//   The mouse. The PS/2 mouse is woken once at boot (initMouse,
//   in this section, called from kmain while the interrupt gate
//   is still closed) and speaks by IRQ12 into the mouse ring. The face
//   drains the ring and makes packets of the bytes: three to a
//   packet — buttons and signed motion first, then the X travel,
//   then the Y. The first byte always carries bit 3; a byte
//   without it is a byte astray and is let go, which is how the
//   face resynchronises if a byte is ever lost. The mouse
//   reckons up as forward; the screen reckons down, so the Y
//   travel is turned over. Clicks are read from the packet's own
//   button bit — the real PS/2 button state, nothing simulated.
//
//   The way home. Two doors, always open: the window's close
//   box, and Esc on the keyboard. While the face holds the room
//   it drains the key ring itself and answers nothing but Esc;
//   every other key is let go. Leaving restores the console
//   exactly: the text grid was never touched — the conversation
//   stands in it still — so the whole pixel field is blackened
//   (the desktop ranged past the grid's rows) and the grid is
//   painted back through the screen, and the shell's prompt
//   opens beneath it in the same session.
// ---------------------------------------------------------------------------

/// The face's palette. Each colour is a plain 0xRRGGBB word here;
/// guiRawPixel translates it into the screen's own packing.
let guiDesktopTopColor: UInt32 = 0x3D0D1A     // deep cardinal
let guiDesktopBottomColor: UInt32 = 0x100308  // settling to near black
let guiGoldColor: UInt32 = 0xD9B36A
let guiHintColor: UInt32 = 0xCBB9A0
let guiParchmentColor: UInt32 = 0xF4EDDE
let guiCardinalColor: UInt32 = 0x7A1220
let guiCloseColor: UInt32 = 0xA01828
let guiBorderColor: UInt32 = 0x2A1A12
let guiShadowColor: UInt32 = 0x0A0206
let guiInkColor: UInt32 = 0x241A12
let guiButtonColor: UInt32 = 0xE4D9C2
let guiPressedColor: UInt32 = 0xC9B184
let guiWhiteColor: UInt32 = 0xFFFFFF
let guiPointerEdgeColor: UInt32 = 0x101010

/// The face's words.
let guiDesktopName: StaticString = "Cardnull OS"
let guiHintLine: StaticString = "Click the button. Esc brings you home."
let guiWindowTitle: StaticString = "Welcome"
let guiGreetingLine: StaticString = "Welcome to Cardnull OS."
let guiVerseLine1: StaticString = "In the beginning was the Word, and"
let guiVerseLine2: StaticString = "the Word was with God, and the Word"
let guiVerseLine3: StaticString = "was God."
let guiVerseAttribution: StaticString = "- John 1:1 (Douay-Rheims)"
let guiButtonText: StaticString = "Click me"
let guiClicksLabel: StaticString = "Clicks: "
let guiNoScreenLine: StaticString =
    "The boot brought no graphics screen; the desktop cannot open."

/// Scales one 8-bit colour channel into the width the framebuffer
/// keeps for it: the component spread over the field's whole
/// range, so full brightness is the field filled with ones.
func guiPackChannel(_ component: UInt32, _ position: Int,
                    _ size: Int) -> UInt32 {
    if size == 0 { return 0 }
    let full = (UInt32(1) << UInt32(size)) - 1
    return ((component * full + 127) / 255) << UInt32(position)
}

/// Reckons one colour (0xRRGGBB) into the raw word the
/// framebuffer keeps for it: at 32 bits, the channels packed in
/// their named fields; at 24, each channel's full byte laid in
/// its own byte slot — which is the same reckoning, read as
/// bytes, since a 24-bit field is exactly a byte wide.
func guiRawPixel(_ rgb: UInt32) -> UInt32 {
    guiPackChannel((rgb >> 16) & 0xFF, framebufferRedPosition,
                   framebufferRedSize)
        | guiPackChannel((rgb >> 8) & 0xFF, framebufferGreenPosition,
                         framebufferGreenSize)
        | guiPackChannel(rgb & 0xFF, framebufferBluePosition,
                         framebufferBlueSize)
}

/// Lays one raw pixel word into the framebuffer. No clipping —
/// the callers keep the face on the screen, and the two readers
/// and writers of raw words are used by nothing else.
@inline(__always)
func guiWriteRaw(_ x: Int, _ y: Int, _ raw: UInt32) {
    let rowStart = framebufferAddress + UInt64(y * framebufferPitch)
    if framebufferBpp == 32 {
        let pixel = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(rowStart + UInt64(x * 4)))!
        pixel.pointee = raw
    } else {
        let pixel = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(rowStart + UInt64(x * 3)))!
        pixel[0] = UInt8(raw & 0xFF)
        pixel[1] = UInt8((raw >> 8) & 0xFF)
        pixel[2] = UInt8((raw >> 16) & 0xFF)
    }
}

/// Takes one raw pixel word back out of the framebuffer — the
/// pointer's cushion is filled through this hand.
@inline(__always)
func guiReadRaw(_ x: Int, _ y: Int) -> UInt32 {
    let rowStart = framebufferAddress + UInt64(y * framebufferPitch)
    if framebufferBpp == 32 {
        let pixel = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(rowStart + UInt64(x * 4)))!
        return pixel.pointee
    }
    let pixel = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(rowStart + UInt64(x * 3)))!
    return UInt32(pixel[0]) | UInt32(pixel[1]) << 8
        | UInt32(pixel[2]) << 16
}

/// Fills a rect with one colour, clipped to the screen. The
/// colour is reckoned into the screen's packing once, however
/// many pixels the rect holds.
func guiFillRect(_ x: Int, _ y: Int, _ width: Int, _ height: Int,
                 _ rgb: UInt32) {
    let x0 = max(x, 0)
    let y0 = max(y, 0)
    let x1 = min(x + width, framebufferWidth)
    let y1 = min(y + height, framebufferHeight)
    if x1 <= x0 || y1 <= y0 { return }
    let raw = guiRawPixel(rgb)
    for row in y0 ..< y1 {
        for col in x0 ..< x1 {
            guiWriteRaw(col, row, raw)
        }
    }
}

/// Draws one glyph of the floor's 8x8 font at a magnification,
/// in one colour, over whatever is already painted — the
/// unpainted pixels of the glyph are left exactly as they were,
/// so text can stand on any ground the face has laid.
func guiDrawGlyph(_ x: Int, _ y: Int, _ scale: Int,
                  _ character: UInt8, _ rgb: UInt32) {
    let glyph = Int(character & 0x7F)
    let font = cardnullFont8x8()
    for glyphY in 0 ..< 8 {
        let bits = font[glyph * 8 + glyphY]
        if bits == 0 { continue }
        for glyphX in 0 ..< 8 {
            if bits & (UInt8(1) << UInt8(glyphX)) != 0 {
                guiFillRect(x + glyphX * scale, y + glyphY * scale,
                            scale, scale, rgb)
            }
        }
    }
}

/// Draws a line of text, and returns the column just past its
/// last glyph — so a number can be set beside its label, the
/// way the fault report's hands do it on the grid.
@discardableResult
func guiDrawText(_ x: Int, _ y: Int, _ scale: Int,
                 _ text: StaticString, _ rgb: UInt32) -> Int {
    var penX = x
    var index = 0
    while true {
        let character = text.utf8Start[index]
        if character == 0 { break }
        guiDrawGlyph(penX, y, scale, character, rgb)
        penX += 8 * scale
        index += 1
    }
    return penX
}

/// Draws a value in decimal: the digits reckoned by a falling
/// divisor and set down one at a time, like writeDecimalAt on
/// the grid — here in pixels, for the click count.
func guiDrawDecimal(_ x: Int, _ y: Int, _ scale: Int,
                    _ value: UInt64, _ rgb: UInt32) {
    var divisor: UInt64 = 1
    while value / divisor >= 10 { divisor *= 10 }
    var remaining = value
    var penX = x
    while true {
        guiDrawGlyph(penX, y, scale, 0x30 + UInt8(remaining / divisor),
                     rgb)
        penX += 8 * scale
        remaining %= divisor
        if divisor == 1 { break }
        divisor /= 10
    }
}

// ---------------------------------------------------------------------------
// The window: one window, in one place. Its geometry is reckoned
// at the face's opening from the screen's own size — 680 x 400
// where the screen has room for it, less where it does not, and
// centred either way. Every part's place is a fixed offset from
// the window's corner, so the painting hands and the click's
// hit-tests read the same numbers and cannot disagree.
// ---------------------------------------------------------------------------

var guiWinX = 0
var guiWinY = 0
var guiWinW = 0
var guiWinH = 0

/// The close box: the title bar's right-hand end, 40 x 28,
/// standing 8 from the window's right edge and 4 below its top.
func guiCloseBoxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWinX + guiWinW - 48 && x < guiWinX + guiWinW - 8
        && y >= guiWinY + 4 && y < guiWinY + 32
}

/// The button: 220 x 48, standing 32 from the window's left edge
/// and 52 above its bottom.
func guiButtonContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWinX + 32 && x < guiWinX + 252
        && y >= guiWinY + guiWinH - 100
        && y < guiWinY + guiWinH - 52
}

/// Paints the close box: its face, and the X across it — two
/// diagonals, each drawn two pixels thick so it reads at a
/// glance.
func guiPaintCloseBox() {
    let boxX = guiWinX + guiWinW - 48
    let boxY = guiWinY + 4
    guiFillRect(boxX, boxY, 40, 28, guiCloseColor)
    for step in 0 ..< 14 {
        guiFillRect(boxX + 13 + step, boxY + 7 + step, 2, 2,
                    guiWhiteColor)
        guiFillRect(boxX + 26 - step, boxY + 7 + step, 2, 2,
                    guiWhiteColor)
    }
}

/// Paints the button, in its resting face or its pressed one —
/// the pressed face stands from the click until the button is
/// released, the face's one piece of theatre, and honest
/// theatre: it is the real button state that paints it.
func guiPaintButton() {
    let buttonX = guiWinX + 32
    let buttonY = guiWinY + guiWinH - 100
    guiFillRect(buttonX, buttonY, 220, 48,
                guiButtonHeld ? guiPressedColor : guiButtonColor)
    guiFillRect(buttonX, buttonY, 220, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY + 46, 220, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY, 2, 48, guiBorderColor)
    guiFillRect(buttonX + 218, buttonY, 2, 48, guiBorderColor)
    guiDrawText(buttonX + 46, buttonY + 16, 2, guiButtonText,
                guiInkColor)
}

/// Paints the click count beside the button: the label and the
/// number, over a fresh patch of the window's parchment — the
/// patch is repainted whole each time, so a shrinking count
/// leaves no ghost of its longer self behind.
func guiPaintClicks() {
    let clicksX = guiWinX + 272
    let clicksY = guiWinY + guiWinH - 92
    guiFillRect(clicksX, clicksY, 260, 32, guiParchmentColor)
    let endX = guiDrawText(clicksX + 8, clicksY + 8, 2,
                           guiClicksLabel, guiInkColor)
    guiDrawDecimal(endX + 4, clicksY + 8, 2, UInt64(guiClickCount),
                   guiInkColor)
}

/// Paints the window whole: its shadow, its parchment body and
/// border, the cardinal title bar with its name and close box,
/// the greeting, the house verse in its three lines with its
/// attribution, and the button with its count beside it.
func guiPaintWindow() {
    guiFillRect(guiWinX + 10, guiWinY + 12, guiWinW, guiWinH,
                guiShadowColor)
    guiFillRect(guiWinX, guiWinY, guiWinW, guiWinH,
                guiParchmentColor)
    guiFillRect(guiWinX, guiWinY, guiWinW, 2, guiBorderColor)
    guiFillRect(guiWinX, guiWinY + guiWinH - 2, guiWinW, 2,
                guiBorderColor)
    guiFillRect(guiWinX, guiWinY, 2, guiWinH, guiBorderColor)
    guiFillRect(guiWinX + guiWinW - 2, guiWinY, 2, guiWinH,
                guiBorderColor)
    guiFillRect(guiWinX, guiWinY, guiWinW, 36, guiCardinalColor)
    guiDrawText(guiWinX + 16, guiWinY + 10, 2, guiWindowTitle,
                guiWhiteColor)
    guiPaintCloseBox()
    guiDrawText(guiWinX + 32, guiWinY + 64, 2, guiGreetingLine,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 112, 2, guiVerseLine1,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 140, 2, guiVerseLine2,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 168, 2, guiVerseLine3,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 196, 2, guiVerseAttribution,
                guiInkColor)
    guiPaintButton()
    guiPaintClicks()
}

/// Paints the desktop whole: the gradient — deep cardinal at
/// the top settling toward near-black at the bottom, each row's
/// colour mixed once and laid across the row — then the OS's
/// name standing large above the window, the hint along the
/// bottom, and the window itself.
func guiPaintDesktop() {
    let span = max(framebufferHeight - 1, 1)
    for row in 0 ..< framebufferHeight {
        let red = 0x3D + (0x10 - 0x3D) * row / span
        let green = 0x0D + (0x03 - 0x0D) * row / span
        let blue = 0x1A + (0x08 - 0x1A) * row / span
        let rgb = UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
        guiFillRect(0, row, framebufferWidth, 1, rgb)
    }
    // Eleven glyphs at fourfold size: 352 pixels of name,
    // centred over the screen.
    guiDrawText((framebufferWidth - 352) / 2, 40, 4, guiDesktopName,
                guiGoldColor)
    guiDrawText(24, framebufferHeight - 44, 2, guiHintLine,
                guiHintColor)
    guiPaintWindow()
}

// ---------------------------------------------------------------------------
// The pointer: a twelve-by-sixteen arrow. In the art below, '#'
// is its dark edge, 'W' its white body, and '.' is no pixel at
// all — the ground shows through. Its point — the top-left
// corner, the pixel the clicks are reckoned by — is the place
// the mouse's travels are added to.
//
//     #...........
//     ##..........
//     #W#.........
//     #WW#........
//     #WWW#.......
//     #WWWW#......
//     #WWWWW#.....
//     #WWWWWW#....
//     #WWWWW#.....
//     #WW##W#.....
//     #W#.#W#.....
//     #..#WW#.....
//     ....#WW#....
//     ....#WW#....
//     .....#W#....
//     ......#.....
// ---------------------------------------------------------------------------

let pointerArtWidth = 12
let pointerArtHeight = 16
let pointerArt: StaticString =
    "#...........##..........#W#.........#WW#........#WWW#.......#WWWW#......#WWWWW#.....#WWWWWW#....#WWWWW#.....#WW##W#.....#W#.#W#.....#..#WW#.........#WW#........#WW#.........#W#..........#....."

/// Where the pointer's point stands, and whether it is drawn.
var pointerX = 0
var pointerY = 0
var pointerIsDrawn = false

/// The rect the cushion currently holds: the pointer's last
/// drawn place, clipped to the screen.
var pointerUnderX = 0
var pointerUnderY = 0
var pointerUnderW = 0
var pointerUnderH = 0

/// Lays the cushion back: the ground the pointer was standing
/// on is restored, pixel for pixel, and the pointer is nowhere.
func pointerHide() {
    if !pointerIsDrawn { return }
    let cushion = cardnullGuiCushion()
    for row in 0 ..< pointerUnderH {
        for col in 0 ..< pointerUnderW {
            guiWriteRaw(pointerUnderX + col, pointerUnderY + row,
                        cushion[row * pointerArtWidth + col])
        }
    }
    pointerIsDrawn = false
}

/// Draws the pointer where it stands: first the ground beneath
/// it is lifted into the cushion, then the arrow is laid over.
func pointerShow() {
    let width = min(pointerArtWidth, framebufferWidth - pointerX)
    let height = min(pointerArtHeight, framebufferHeight - pointerY)
    if width <= 0 || height <= 0 { return }
    pointerUnderX = pointerX
    pointerUnderY = pointerY
    pointerUnderW = width
    pointerUnderH = height
    let cushion = cardnullGuiCushion()
    for row in 0 ..< height {
        for col in 0 ..< width {
            cushion[row * pointerArtWidth + col] =
                guiReadRaw(pointerX + col, pointerY + row)
        }
    }
    for row in 0 ..< height {
        for col in 0 ..< width {
            let cell = pointerArt.utf8Start[row * pointerArtWidth + col]
            if cell == 0x23 {          // '#'
                guiFillRect(pointerX + col, pointerY + row, 1, 1,
                            guiPointerEdgeColor)
            } else if cell == 0x57 {   // 'W'
                guiFillRect(pointerX + col, pointerY + row, 1, 1,
                            guiWhiteColor)
            }
        }
    }
    pointerIsDrawn = true
}

// ---------------------------------------------------------------------------
// The mouse's conversation: packets, clicks, and the door home.
// ---------------------------------------------------------------------------

/// The packet assembly: which byte of the three is expected
/// next, and the first two bytes held while the third is coming.
var mouseStage = 0
var mouseFirstByte: UInt8 = 0
var mouseSecondByte: UInt8 = 0

/// The left button's last known state, so a press is the edge —
/// the change — and not the holding.
var mouseLeftWasDown = false

/// The face's books: how many times the button has been clicked,
/// whether it stands pressed, and whether the way home has been
/// asked for — by the close box or by Esc, both roads land here.
var guiClickCount = 0
var guiButtonHeld = false
var guiWantsHome = false

/// A press at the pointer's point. The close box is asked first
/// — leaving is always the senior road — then the button: the
/// count rises, the button takes its pressed face, and both are
/// repainted with the pointer lifted and laid back over them.
func guiPressAt(_ x: Int, _ y: Int) {
    if guiCloseBoxContains(x, y) {
        guiWantsHome = true
        return
    }
    if guiButtonContains(x, y) {
        guiClickCount += 1
        guiButtonHeld = true
        pointerHide()
        guiPaintButton()
        guiPaintClicks()
        pointerShow()
    }
}

/// A release: if the button stood pressed, it takes its resting
/// face again.
func guiRelease() {
    if guiButtonHeld {
        guiButtonHeld = false
        pointerHide()
        guiPaintButton()
        pointerShow()
    }
}

/// Takes one byte of the mouse's conversation. The first byte of
/// a packet always carries bit 3, and the stage only advances
/// on it — a byte without it is astray (a leftover, a lost
/// partner) and is let go, which is how the assembly finds its
/// feet again after any stumble. A whole packet moves the
/// pointer — restoring its old ground and drawing it new — and
/// answers the button's edges.
func guiTakeMouseByte(_ byte: UInt8) {
    if mouseStage == 0 {
        if byte & 0x08 == 0 { return }
        mouseFirstByte = byte
        mouseStage = 1
        return
    }
    if mouseStage == 1 {
        mouseSecondByte = byte
        mouseStage = 2
        return
    }
    mouseStage = 0
    var travelX = Int(mouseSecondByte)
    if mouseFirstByte & 0x10 != 0 { travelX -= 256 }
    var travelY = Int(byte)
    if mouseFirstByte & 0x20 != 0 { travelY -= 256 }
    // The mouse reckons up as forward; the screen reckons down,
    // so the Y travel is turned over as it is added.
    let newX = min(max(pointerX + travelX, 0), framebufferWidth - 1)
    let newY = min(max(pointerY - travelY, 0), framebufferHeight - 1)
    if newX != pointerX || newY != pointerY {
        pointerHide()
        pointerX = newX
        pointerY = newY
        pointerShow()
    }
    let leftDown = mouseFirstByte & 0x01 != 0
    if leftDown && !mouseLeftWasDown {
        guiPressAt(pointerX, pointerY)
    } else if !leftDown && mouseLeftWasDown {
        guiRelease()
    }
    mouseLeftWasDown = leftDown
}

/// Waits, with a bound, for the controller to be ready to be
/// spoken to — its input buffer empty. The bound matters: a
/// machine with no mouse must not hang the boot on a courtesy.
func mouseWaitWrite() {
    var spins = 0
    while cardnullInb(0x64) & 0x02 != 0 && spins < 100000 {
        spins += 1
    }
}

/// Waits, with the same bound, for the controller to have
/// something to say — its output buffer full — and reports
/// whether it did.
func mouseWaitRead() -> Bool {
    var spins = 0
    while cardnullInb(0x64) & 0x01 == 0 && spins < 100000 {
        spins += 1
    }
    return cardnullInb(0x64) & 0x01 != 0
}

/// Speaks one byte to the mouse itself, through the controller's
/// 0xD4 prefix — the next byte written to the data port is for
/// the mouse, not the keyboard — and takes its answer (0xFA,
/// understood) and lets it go. No answer is not a failure: the
/// polls simply run out, and the boot walks on.
func mouseSendToMouse(_ byte: UInt8) {
    mouseWaitWrite()
    cardnullOutb(0x64, 0xD4)
    mouseWaitWrite()
    cardnullOutb(0x60, byte)
    if mouseWaitRead() {
        _ = cardnullInb(0x60)
    }
}

/// Wakes the mouse, once, at boot — called from kmain with the
/// interrupt gate still closed, because the waking is a polled
/// conversation on the same data port the keyboard speaks
/// through, and no IRQ may reach into the middle of it. The
/// steps are the PS/2 controller's old ceremony, in order:
///
///   - whatever the controller still holds from the bootloader's
///     day is taken out and let go, so the answers read below
///     are the mouse's own;
///   - the auxiliary port — the mouse's side of the controller —
///     is enabled (0xA8);
///   - the configuration byte is read (ask with 0x20, then take
///     it), amended — the mouse's IRQ may knock, and its clock
///     runs — and written back (0x60);
///   - the mouse is told its defaults (0xF6) and then to begin
///     reporting (0xF4): from there, motion and buttons arrive
///     as packets, one IRQ12 per byte.
///
/// If no mouse answers, nothing above hangs and nothing fails:
/// every wait is bounded, and the face will still open — Esc
/// alone brings it home on a mouseless machine.
func initMouse() {
    var guardCount = 0
    while cardnullInb(0x64) & 0x01 != 0 && guardCount < 32 {
        _ = cardnullInb(0x60)
        guardCount += 1
    }
    mouseWaitWrite()
    cardnullOutb(0x64, 0xA8)
    mouseWaitWrite()
    cardnullOutb(0x64, 0x20)
    var config: UInt8 = 0x47
    if mouseWaitRead() {
        config = cardnullInb(0x60)
    }
    config |= 0x02        // the mouse's IRQ (IRQ12) may knock
    config &= ~0x20       // the mouse's clock runs
    mouseWaitWrite()
    cardnullOutb(0x64, 0x60)
    mouseWaitWrite()
    cardnullOutb(0x60, config)
    mouseSendToMouse(0xF6)
    mouseSendToMouse(0xF4)
}

/// The `gui` command's work: open the face, keep it until the
/// way home is asked for, and restore the console exactly.
///
/// On a boot that brought no framebuffer there is no face to
/// open — the VGA text grid keeps pixels for no one — and the
/// command says so plainly, in the shell, and that is all.
func runGui() {
    if !useFramebuffer {
        writeLine(guiNoScreenLine)
        return
    }
    guiWinW = min(680, framebufferWidth - 40)
    guiWinH = min(400, framebufferHeight - 40)
    guiWinX = (framebufferWidth - guiWinW) / 2
    guiWinY = (framebufferHeight - guiWinH) / 2
    guiClickCount = 0
    guiButtonHeld = false
    guiWantsHome = false
    mouseStage = 0
    mouseLeftWasDown = false
    // The mouse may have spoken while the shell held the room.
    // That is old news: the ring is drained, so the face opens
    // on a clean ring and a whole packet boundary.
    while nextMouseByte() != nil {}
    // The pointer opens at the screen's centre — a known place,
    // so its first standing can be witnessed, not guessed.
    pointerX = framebufferWidth / 2
    pointerY = framebufferHeight / 2
    pointerIsDrawn = false
    guiPaintDesktop()
    pointerShow()
    // The face's whole work: drain the mouse's ring into
    // packets, drain the keyboard's ring looking only for Esc,
    // and rest in `hlt` whenever both are quiet — the timer's
    // heartbeat wakes the resting a hundred times a second,
    // which no hand will ever notice.
    while !guiWantsHome {
        var worked = false
        while let byte = nextMouseByte() {
            guiTakeMouseByte(byte)
            worked = true
            if guiWantsHome { break }
        }
        if guiWantsHome { break }
        while let code = nextScancode() {
            worked = true
            if code == 0x01 {          // Esc, pressed
                guiWantsHome = true
            }
        }
        if !worked {
            cardnullHltOnce()
        }
    }
    pointerHide()
    // The way home. The text grid was never touched — the whole
    // conversation still stands in it — so blacken the whole
    // pixel field, the desktop having ranged past the grid's
    // rows, and paint the grid back through the screen. The
    // shell's own hands then open the next prompt beneath it.
    for row in 0 ..< framebufferHeight {
        for col in 0 ..< framebufferWidth {
            putPixel(x: col, y: row, white: false)
        }
    }
    repaintScreen()
    moveHardwareCursor()
}

//
// Milestone 3's heart: the prompt stops merely echoing and begins to
// answer. When Enter closes a line, the kernel reads the typed bytes
// straight off the screen — from the prompt's end to the cursor —
// folds capital letters down, trims the spaces at both ends, and
// compares what remains against the handful of commands it knows.
// Four answers, for now:
//
//   help    the list of commands
//   about   what this operating system is
//   verse   a verse of Scripture (John 1:1, Douay-Rheims)
//   clear   a clean screen and a fresh prompt
//   uptime  how long the kernel has been awake (milestone 4: the
//           answer is read off the timer interrupt's tick count)
//   mem     the machine's memory, counted from the bootloader's
//           own map (milestone 6: the frame allocator's books;
//           `memory` is taken as the same command)
//   heap    the kernel heap's books: its field, and how the work
//           stands in it (milestone 7)
//   faulttest  the one command whose work is to fail — reaching
//           for an address no page covers, so the page fault's
//           report can be witnessed instead of merely believed
//           (milestone 7; the machine halts on its answer)
//   ls      the disc's contents, listed from its own directory
//           (milestone 8: the ATAPI driver's drive, the ISO9660
//           reader's walk; a path names the directory — or the
//           file — to list)
//   cat     a file's contents, printed off the disc itself
//           (milestone 8; the first argument-carrying command,
//           so these two are matched by their first word and the
//           rest of the line is theirs)
//   run     a program from the disc, loaded into ground of its
//           own and run in ring 3 (milestone 9; matched by its
//           first word, like ls and cat, the path being its own)
//   both    two programs from the disc, loaded into ground of
//           their own and run in ring 3, taking turns by the
//           door's yield service until both have finished
//           (milestone 10; matched by its first word, the two
//           paths being its own)
//   feather a package from the disc — a card that names its
//           program, proven against its checksum, printed, and
//           only then run in ring 3 down run's own road
//           (milestone 11; matched by its first word, the path
//           being its own)
//   gui     the graphical face: a drawn desktop, one window, and
//           a pointer that answers the PS/2 mouse, until the
//           close box or Esc brings the shell home (milestone 12)
//
// An empty line earns only a fresh prompt. Anything else is answered
// plainly: it is not a command the kernel knows. Matching is done on
// raw bytes against StaticString tables — Embedded Swift has no heap
// and no String, and a shell this young needs neither.
// ---------------------------------------------------------------------------

/// The command words, in the lowercase the matcher folds capitals to.
let helpCommand: StaticString = "help"
let aboutCommand: StaticString = "about"
let verseCommand: StaticString = "verse"
let clearCommand: StaticString = "clear"
let uptimeCommand: StaticString = "uptime"
let memCommand: StaticString = "mem"
let memoryCommand: StaticString = "memory"
let heapCommand: StaticString = "heap"
let faulttestCommand: StaticString = "faulttest"
let lsCommand: StaticString = "ls"
let catCommand: StaticString = "cat"
let runCommand: StaticString = "run"
let bothCommand: StaticString = "both"
let featherCommand: StaticString = "feather"
let guiCommand: StaticString = "gui"

/// help's answer: the list itself.
let helpTitle: StaticString = "Commands:"
let helpHelpLine: StaticString = "  help    show this list"
let helpAboutLine: StaticString = "  about   what Cardnull OS is"
let helpVerseLine: StaticString = "  verse   a verse of Scripture"
let helpClearLine: StaticString = "  clear   clear the screen"
let helpUptimeLine: StaticString = "  uptime  how long the kernel has been awake"
let helpMemLine: StaticString = "  mem     the machine's memory, counted from its map"
let helpHeapLine: StaticString = "  heap    the kernel heap, counted from its books"
let helpFaultLine: StaticString = "  faulttest  take a page fault on purpose"
let helpLsLine: StaticString = "  ls      list the disc's files (ls /path)"
let helpCatLine: StaticString = "  cat     print a file from the disc (cat /path)"
let helpRunLine: StaticString = "  run     run a program from the disc (run /path)"
let helpBothLine: StaticString =
    "  both    run two programs, taking turns (both /A.BIN /B.BIN)"
let helpFeatherLine: StaticString =
    "  feather open a feather package and run it (feather /path)"
let helpGuiLine: StaticString =
    "  gui     open the graphical desktop (Esc brings you home)"

/// about's answer: a few honest lines, and no more than the truth.
let aboutLine1: StaticString =
    "Cardnull OS: a from-scratch operating system, written in Swift."
let aboutLine2: StaticString =
    "Public domain. Built by Tyler Kovalevich and Noki for Cardnull,"
let aboutLine3: StaticString =
    "a Catholic computer and software company."
let aboutLine4: StaticString =
    "The computer that points to Jesus."

/// verse's answer: John 1:1 in the Douay-Rheims wording, with its
/// attribution beneath. The attribution's dash is a plain hyphen —
/// neither the VGA text font nor the 8x8 framebuffer font carries an
/// em dash, and the verse itself loses nothing by its citation
/// wearing ASCII.
let verseLine: StaticString =
    "In the beginning was the Word, and the Word was with God, and the Word was God."
let verseAttribution: StaticString = "- John 1:1 (Douay-Rheims)"

/// The answer to everything else.
let unknownLine: StaticString =
    "Unknown command. Type 'help' and press Enter."

/// uptime's vocabulary. The units are whole words with their plural
/// kept beside them, because "1 seconds" is not how this house talks.
let awakeWord: StaticString = "Awake"
let hourWord: StaticString = " hour"
let hoursWord: StaticString = " hours"
let minuteWord: StaticString = " minute"
let minutesWord: StaticString = " minutes"
let secondWord: StaticString = " second"
let secondsWord: StaticString = " seconds"

/// Writes a number in decimal, through the one output door. The
/// digits are reckoned by recursion — divide away the higher places,
/// then speak the lowest — so no scratch storage is needed, only the
/// stack, and never more than twenty calls deep.
func writeNumber(_ value: UInt64) {
    if value >= 10 {
        writeNumber(value / 10)
    }
    writeChar(0x30 + UInt8(value % 10))
}

/// uptime's answer: the tick count, read once and rendered as the
/// time it is — "Awake 3 minutes 12 seconds", with the singular
/// where the count is one and the hours named when there are any.
/// A hundred ticks to the second is the heartbeat's rate, set by
/// the floor's divisor when the PIT was programmed.
func printUptime() {
    let totalSeconds = ticks / 100
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    writeStatic(awakeWord)
    if hours > 0 {
        writeChar(0x20)
        writeNumber(hours)
        writeStatic(hours == 1 ? hourWord : hoursWord)
    }
    if hours > 0 || minutes > 0 {
        writeChar(0x20)
        writeNumber(minutes)
        writeStatic(minutes == 1 ? minuteWord : minutesWord)
    }
    writeChar(0x20)
    writeNumber(seconds)
    writeStatic(seconds == 1 ? secondWord : secondsWord)
    writeNewline()
}

/// mem's vocabulary: labels and closings, with the numbers spoken
/// between them by writeNumber.
let memTitle: StaticString = "Memory:"
let memRamLabel: StaticString = "  Usable RAM: "
let memMiBWord: StaticString = " MiB ("
let memBytesWord: StaticString = " bytes)"
let memFramesLabel: StaticString = "  Frames of 4 KiB: "
let memTotalWord: StaticString = " total, "
let memFreeWord: StaticString = " free, "
let memUsedWord: StaticString = " used"
let memSelfTestPassedLine: StaticString =
    "  Allocator self-test: passed"
let memSelfTestFailedLine: StaticString =
    "  Allocator self-test: FAILED"
let memNoMapLine: StaticString =
    "No memory map came from the bootloader."

/// mem's answer: the machine's memory as the bootloader's map and
/// the allocator's books agree it stands — the usable RAM in full
/// bytes (and whole mebibytes beside it), the frame estate and its
/// division, and the self-test's verdict. Every number was reckoned
/// at boot from the real map; nothing here is remembered from the
/// machine that built the kernel.
func printMemory() {
    if !memMapFound {
        writeLine(memNoMapLine)
        return
    }
    writeLine(memTitle)
    writeStatic(memRamLabel)
    writeNumber(memTotalUsableBytes / 1048576)
    writeStatic(memMiBWord)
    writeNumber(memTotalUsableBytes)
    writeLine(memBytesWord)
    writeStatic(memFramesLabel)
    writeNumber(memTotalFrames)
    writeStatic(memTotalWord)
    writeNumber(memFreeFrames)
    writeStatic(memFreeWord)
    writeNumber(memTotalFrames - memFreeFrames)
    writeLine(memUsedWord)
    writeLine(memSelfTestOK ? memSelfTestPassedLine : memSelfTestFailedLine)
}

/// heap's vocabulary: labels and units, with the numbers spoken
/// between them by writeNumber. Block counts keep their plural
/// honest, the way uptime's units do.
let heapTitle: StaticString = "Heap:"
let heapRegionLabel: StaticString = "  Region: "
let heapBytesParen: StaticString = " bytes ("
let heapMiBClose: StaticString = " MiB)"
let heapUsedLabel: StaticString = "  Used: "
let heapFreeLabel: StaticString = "  Free: "
let heapBytesIn: StaticString = " bytes in "
let heapBlockWord: StaticString = " block"
let heapBlocksWord: StaticString = " blocks"
let heapSelfTestPassedLine: StaticString = "  Heap self-test: passed"
let heapSelfTestFailedLine: StaticString = "  Heap self-test: FAILED"
let heapNoHeapLine: StaticString = "No heap was raised."

/// heap's answer: the heap's field and how the work stands in it —
/// the region's size, the used and free bytes with their block
/// counts beside them (whole-block bytes, headers included: used
/// plus free is the region, exactly), and the self-test's verdict.
/// Every number is the block chain's own reading, re-reckoned at
/// every change; nothing here is remembered from the build machine.
func printHeap() {
    if !heapReady {
        writeLine(heapNoHeapLine)
        return
    }
    writeLine(heapTitle)
    writeStatic(heapRegionLabel)
    writeNumber(heapRegionBytes)
    writeStatic(heapBytesParen)
    writeNumber(heapRegionBytes / 1048576)
    writeLine(heapMiBClose)
    writeStatic(heapUsedLabel)
    writeNumber(heapUsedBytes)
    writeStatic(heapBytesIn)
    writeNumber(heapUsedBlocks)
    writeLine(heapUsedBlocks == 1 ? heapBlockWord : heapBlocksWord)
    writeStatic(heapFreeLabel)
    writeNumber(heapFreeBytes)
    writeStatic(heapBytesIn)
    writeNumber(heapFreeBlocks)
    writeLine(heapFreeBlocks == 1 ? heapBlockWord : heapBlocksWord)
    writeLine(heapSelfTestOK ? heapSelfTestPassedLine
                             : heapSelfTestFailedLine)
}

/// faulttest's words: the announcement before the reach (the
/// report itself will overwrite the screen's top rows when it
/// comes), the honest word when paging is not standing and there
/// is no fault to take, and — against every expectation — the word
/// for the reach having been answered.
let faultAnnounceLine: StaticString =
    "Reaching for an address no page covers: 0xDEAD0000."
let faultExpectLine: StaticString =
    "If the kernel's tables are honest, the fault reports itself and halts."
let faultNoPagingLine: StaticString =
    "Paging is not standing; on the borrowed map, everything answers."
let faultSurvivedLine: StaticString =
    "No fault came. The address answered: "

/// faulttest's work: announce the reach, then take it. Under the
/// kernel's own tables the touch faults, the handler writes its
/// report across the top of the screen, and the machine halts —
/// this function never comes back. It can only return to be
/// answered here if the address somehow answered, and then it
/// says so, plainly: that, too, would be a truth worth hearing.
func runFaultTest() {
    if !pagingReady {
        writeLine(faultNoPagingLine)
        return
    }
    writeLine(faultAnnounceLine)
    writeLine(faultExpectLine)
    let value = touchUnmapped()
    writeStatic(faultSurvivedLine)
    writeNumber(UInt64(value))
    writeNewline()
}

/// True when the typed line is nothing but spaces — the typist
/// pressed Enter on an empty line, which earns only a fresh prompt.
func lineIsBlank() -> Bool {
    let start = lineStartRow * screenColumns + lineStartCol
    let end = cursorRow * screenColumns + cursorCol
    var cell = start
    while cell < end {
        if screenChar(cell: cell) != 0x20 { return false }
        cell += 1
    }
    return true
}

/// True when the typed line, trimmed of the spaces at both ends and
/// folded to lowercase, is exactly the given command word — so HELP,
/// Help, and help with room around them are all the same command.
func commandMatches(_ command: StaticString) -> Bool {
    let start = lineStartRow * screenColumns + lineStartCol
    let end = cursorRow * screenColumns + cursorCol
    var cell = start
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    var index = 0
    while command.utf8Start[index] != 0 {
        if cell >= end { return false }
        var character = screenChar(cell: cell)
        if character >= 0x41 && character <= 0x5A {
            character += 0x20   // A ... Z -> a ... z
        }
        if character != command.utf8Start[index] { return false }
        cell += 1
        index += 1
    }
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    return cell == end
}

/// The clear command's work: wipe the whole screen and open a fresh
/// prompt at the very top. The grid is emptied and repainted; on the
/// framebuffer the whole pixel field is blackened first, margins
/// included, so nothing of the old conversation survives anywhere.
/// Nothing is kept — that is what clear means.
func clearScreen() {
    let grid = cardnullTextGrid()
    for cell in 0 ..< (screenColumns * screenRows) {
        grid[cell] = 0x20
    }
    if useFramebuffer {
        for y in 0 ..< framebufferHeight {
            for x in 0 ..< framebufferWidth {
                putPixel(x: x, y: y, white: false)
            }
        }
    }
    repaintScreen()
    cursorRow = 0
    cursorCol = 0
    startLine()
}

/// Enter: the line is finished — read it, answer it, and open the
/// next prompt beneath the answer. All the matching is done before
/// the cursor moves, while the typed line still stands untouched
/// between its prompt and the cursor.
func submitLine() {
    if commandMatches(clearCommand) {
        clearScreen()
        return
    }
    let blank = lineIsBlank()
    let isHelp = commandMatches(helpCommand)
    let isAbout = commandMatches(aboutCommand)
    let isVerse = commandMatches(verseCommand)
    let isUptime = commandMatches(uptimeCommand)
    let isMem = commandMatches(memCommand) || commandMatches(memoryCommand)
    let isHeap = commandMatches(heapCommand)
    let isFaulttest = commandMatches(faulttestCommand)
    let isLs = firstWordMatches(lsCommand)
    let isCat = firstWordMatches(catCommand)
    let isRun = firstWordMatches(runCommand)
    let isBoth = firstWordMatches(bothCommand)
    let isFeather = firstWordMatches(featherCommand)
    let isGui = commandMatches(guiCommand)

    writeNewline()
    if !blank {
        if isHelp {
            writeLine(helpTitle)
            writeLine(helpHelpLine)
            writeLine(helpAboutLine)
            writeLine(helpVerseLine)
            writeLine(helpClearLine)
            writeLine(helpUptimeLine)
            writeLine(helpMemLine)
            writeLine(helpHeapLine)
            writeLine(helpFaultLine)
            writeLine(helpLsLine)
            writeLine(helpCatLine)
            writeLine(helpRunLine)
            writeLine(helpBothLine)
            writeLine(helpFeatherLine)
            writeLine(helpGuiLine)
        } else if isAbout {
            writeLine(aboutLine1)
            writeLine(aboutLine2)
            writeLine(aboutLine3)
            writeLine(aboutLine4)
        } else if isVerse {
            writeLine(verseLine)
            writeLine(verseAttribution)
        } else if isUptime {
            printUptime()
        } else if isMem {
            printMemory()
        } else if isHeap {
            printHeap()
        } else if isFaulttest {
            runFaultTest()
        } else if isLs {
            runList()
        } else if isCat {
            runCat()
        } else if isRun {
            runProgram()
        } else if isBoth {
            runBoth()
        } else if isFeather {
            runFeather()
        } else if isGui {
            runGui()
        } else {
            writeLine(unknownLine)
        }
    }
    startLine()
}

/// Acts on one scancode from the keyboard: shift and caps-lock
/// bookkeeping, Enter (which now submits the line to the shell),
/// Backspace, and the ordinary characters. Every other key — and
/// every key release but Shift's — is ignored, silently, by design.
func handleScancode(_ code: UInt8) {
    if extendedPrefix {
        extendedPrefix = false
        return
    }
    if code == 0xE0 {
        extendedPrefix = true
        return
    }

    switch code {
    case 0x2A, 0x36:            // left / right Shift pressed
        shiftHeld = true
    case 0xAA, 0xB6:            // left / right Shift released
        shiftHeld = false
    case 0x3A:                  // Caps Lock pressed: latch flips
        capsLock = !capsLock
    case 0x0E:                  // Backspace
        backspace()
    case 0x1C:                  // Enter: the shell answers
        submitLine()
    case 0x80 ... 0xFF:         // any other key's release: not our affair
        break
    default:
        let character = ascii(forScancode: code)
        if character != 0 {
            writeChar(character)
        }
    }
    moveHardwareCursor()
}

/// Kernel entry point. Called once by the boot floor; never returns —
/// an operating system that finishes has stopped being one.
///
/// Milestone 1 put CARDNULL on the screen; milestone 2 left it there
/// and listened; milestone 3 made the screen a scrolling terminal and
/// the prompt a shell that answers. Milestone 4 changes how the
/// kernel waits: the interrupt machinery is raised after the first
/// prompt, and from then on the kernel *rests* — sleeping in `hlt`
/// until the timer's heartbeat or a keypress wakes it, draining the
/// keyboard ring through the same hands the polling years used. The
/// commands do not change; the waiting does. Milestone 5 changes
/// where the screen lives: the floor hands over the Multiboot2
/// information address as kmain's argument, the kernel reads the
/// framebuffer tag from it before anything is drawn, and the same
/// shell then speaks through whichever screen the boot provided —
/// the VGA text grid behind the BIOS door, drawn pixels behind the
/// UEFI door — with the characters kept in the kernel's own grid
/// either way, so nothing above the painting layer can tell the two
/// doors apart.
@_cdecl("kmain")
public func kmain(_ multibootInfo: UInt64) {
    // Choose the screen before anything is drawn: read the
    // bootloader's information for a usable framebuffer.
    chooseScreen(infoAddress: multibootInfo)

    // Read the bootloader's other word (milestone 6): the memory
    // map. The frame allocator is raised over it now — reservations
    // laid, self-test run — so the `mem` command can speak the
    // machine's true numbers from the shell's first breath. The
    // framebuffer's range is one of the reservations, which is why
    // this waits until the screen is chosen.
    initMemory(infoAddress: multibootInfo)

    // Raise the ring-3 furniture (milestone 9) while the floor's
    // borrowed map still stands: the task state segment and its
    // GDT descriptor live in the kernel's read-only span, which
    // the borrowed map leaves writable and milestone 7's tables
    // will not. No guest exists yet — the furniture is simply
    // ready before the house changes hands.
    cardnullSetupUserMode()

    // Move into our own house (milestone 7): page tables of the
    // kernel's building, raised out of the allocator's frames —
    // the usable RAM identity-mapped under W^X, the kernel's text
    // executable and unwritable, everything else writable and
    // unexecutable, the dark left unmapped — and then, on the far
    // side of the CR3 switch, the heap: one unbroken field of
    // frames with a chain of blocks in it, self-tested before the
    // shell opens. Both buildings happen under the floor's map and
    // the closed interrupt gate; the screen is not yet wiped, and
    // nothing has been promised that a failure here could break —
    // if either raising fails, its command simply says so.
    initPaging(infoAddress: multibootInfo)
    initHeap()

    // Wipe the screen the bootloader left behind: the grid emptied
    // and repainted — and on the framebuffer, the whole pixel field
    // blackened first — so the first word stands on a clean field.
    let grid = cardnullTextGrid()
    for cell in 0 ..< (screenColumns * screenRows) {
        grid[cell] = 0x20
    }
    if useFramebuffer {
        for y in 0 ..< framebufferHeight {
            for x in 0 ..< framebufferWidth {
                putPixel(x: x, y: y, white: false)
            }
        }
    }
    repaintScreen()

    // The banner, at the top-left cell. A StaticString's bytes are
    // stored NUL-terminated in read-only data (Embedded Swift's trimmed
    // StaticString offers the pointer but not the length), so walk to
    // the terminator — and never past the edge of the first row.
    var cell = 0
    while cell < screenColumns {
        let character = cardnullBanner.utf8Start[cell]
        if character == 0 { break }
        putCell(row: 0, col: cell, character: character)
        cell += 1
    }

    // Ask the disc its name (milestone 8): the probe walks the
    // four IDE positions and keeps the first ATAPI drive that
    // answers, and the reader checks the disc's own signature.
    // The report is spoken now, on the banner's clean field, so
    // the shell opens beneath the news of what machine it is
    // running on — or the plain word that no drive answered,
    // which `ls` and `cat` will repeat when asked.
    initDisc()
    printDiscReport()

    // The first prompt, and the cursor resting just past it.
    startLine()
    moveHardwareCursor()

    // Wake the mouse (milestone 12), while the interrupt gate is
    // still closed: its waking is a polled conversation on the
    // PS/2 controller's data port — the same port the keyboard
    // speaks through — and no IRQ may reach into the middle of
    // it. From here the mouse reports its packets on its own;
    // IRQ12's gate is raised with the rest, just below.
    initMouse()

    // Raise the interrupts: IDT, PICs, the 100 Hz heartbeat, and an
    // open gate. From here the machine can speak first — a keypress
    // no longer waits to be asked after, and the tick counts whether
    // anyone is watching or not.
    cardnullSetupInterrupts()

    // The kernel's whole work, from here on: drain whatever the
    // keyboard handler has laid in the ring — echoing the typing and
    // answering the finished lines, exactly as the polling loop did —
    // and when the ring is empty, sleep until the next interrupt. A
    // keystroke that lands in the breath between the last look and
    // the sleep waits at most for the next heartbeat, a hundredth of
    // a second away, which no finger will ever notice.
    while true {
        while let code = nextScancode() {
            handleScancode(code)
        }
        cardnullHltOnce()
    }
}
