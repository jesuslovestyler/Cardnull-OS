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
// The shell.
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

/// help's answer: the list itself.
let helpTitle: StaticString = "Commands:"
let helpHelpLine: StaticString = "  help    show this list"
let helpAboutLine: StaticString = "  about   what Cardnull OS is"
let helpVerseLine: StaticString = "  verse   a verse of Scripture"
let helpClearLine: StaticString = "  clear   clear the screen"
let helpUptimeLine: StaticString = "  uptime  how long the kernel has been awake"
let helpMemLine: StaticString = "  mem     the machine's memory, counted from its map"

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
