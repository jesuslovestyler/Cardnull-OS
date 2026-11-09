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
/// pushed and the CR2 address. Writes the report — title, faulting
/// address, error code in hex and in words — and halts, cleanly,
/// with the gate closed. Never returns.
@_cdecl("cardnull_page_fault_handler")
public func pageFaultHandler(_ errorCode: UInt64, _ faultAddress: UInt64) {
    cardnullCli()
    _ = writeStaticAt(0, 0, pageFaultTitle)
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
    cardnullHalt()
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
// rule reckons the strictest word along the walk. User pages do
// not exist yet — there are no users; every page is the kernel's,
// supervisor-only, until milestone 9 has programs to protect.
// ---------------------------------------------------------------------------

/// The leaf flags of the kernel's three countries.
let ptePresent: UInt64 = 0x1
let pteWritable: UInt64 = 0x2
let pteNoExecute: UInt64 = 0x8000_0000_0000_0000

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
    let path = discPath()
    resolvedExtent = isoRootExtent
    resolvedSize = isoRootSize
    resolvedIsDirectory = true
    lastComponentStart = 0
    lastComponentLength = 0
    var index = 0
    while index < length && path[index] == 0x2F { index += 1 }
    if index >= length { return pathFoundCode }
    while true {
        let componentStart = index
        while index < length && path[index] != 0x2F { index += 1 }
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
        while next < length && path[next] == 0x2F { next += 1 }
        if next < length {
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
