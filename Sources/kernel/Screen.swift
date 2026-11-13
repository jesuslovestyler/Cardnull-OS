// Cardnull OS — the kernel, in parts.
//
// This file is one part of the kernel module, split from the
// single Kernel.swift at milestone 33.5 ("The Split"): the
// same code, moved — no behavior changed. The module's files
// are named for their subsystems; Kernel.swift keeps the
// boot and the entry. Written in Embedded Swift, in the
// open, in the public domain.
//
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
// Milestone 13: the shell has two homes — the console's own grid,
// and the Terminal window's smaller grid on the desktop. The four
// marks above belong to whichever home is active; each home's
// marks are kept aside while the other is in use, and the output
// door (writeChar and its kin) opens onto the active home alone.
// The Terminal's grid is 40 x 31: at the face's twofold glyph
// size that is a window a shell can honestly live in.
// ---------------------------------------------------------------------------

/// True while the output door opens onto the Terminal window's
/// grid — set exactly while the desktop stands with the window
/// open. Everything else in the kernel neither knows nor cares.
var consoleInTerminal = false

/// The Terminal grid's keeping and its visible shape. The
/// keeping is fixed — a stride of termStrideColumns and room
/// for termRowsCapacity rows, agreed with the floor — and the
/// storage never changes its layout. The visible shape,
/// termColumns by termRows, is reckoned from the Terminal
/// window's size whenever the window changes its shape
/// (milestone 14: it opens large, and can be maximized and
/// restored): only the visible window into the keeping moves,
/// and the cells beyond the visible shape are kept spaces, so
/// a typed line read back across a row's end meets nothing but
/// the spaces a wrapped line would imply. In milestone 13 the
/// two were one and the same — a fixed 40 x 31.
let termStrideColumns = 120
let termRowsCapacity = 64
var termColumns = 40
var termRows = 31

/// Each home's four marks, kept aside while the other is in use.
var textSavedCursorRow = typingTopRow
var textSavedCursorCol = 0
var textSavedLineStartRow = typingTopRow
var textSavedLineStartCol = 2
var termSavedCursorRow = 0
var termSavedCursorCol = 0
var termSavedLineStartRow = 0
var termSavedLineStartCol = 2

/// Whether the Terminal's conversation has been opened even
/// once: its first opening wipes its grid and lays its first
/// prompt; later openings take up its kept marks instead.
var termStarted = false

/// The Terminal's repaint bookkeeping: the span of its rows the
/// writing hands have touched since the face last painted them,
/// or -1 when the window stands exactly as painted. The face
/// repaints only the span — a keystroke's echo never repaints
/// the whole window.
var termDirtyTop = -1
var termDirtyBottom = -1

// ---------------------------------------------------------------------------
// Milestone 26: the Terminal's memory. Until now a line that
// lifted off the grid's top was gone — the conversation could
// not be read back, and Tyler's wheel, turned over the
// Terminal on his own desk, asked for a view the window did
// not keep. The keeping (the floor's cardnullTermHistory) now
// holds the lifted lines, and the window's view can stand
// lifted into them: the wheel turns it, the page keys walk
// it, and a keypress brings it home to the live end before
// the key is answered, so typing always lands in the present.
// ---------------------------------------------------------------------------

/// How many lifted lines the floor's keeping holds.
let termHistoryLines = 128

/// The lines that have lifted off the Terminal grid's top and
/// stand in the keeping, oldest first.
var termHistoryCount = 0

/// The view's lift: how many of the conversation's newest
/// lines stand hidden below the window while it reads older
/// ones. 0 is the live view — the conversation as it stands.
/// The lift is a distance from the conversation's end, and it
/// keeps that distance as new lines arrive: an arriving line
/// moves the read lines down a line, the way the page itself
/// moves — the view never pretends the conversation stood
/// still beneath it.
var termViewOffset = 0

/// Keeps one line that is lifting off the Terminal grid's
/// top: the whole stride-row moves into the keeping, and a
/// keeping already full lets its eldest go. Called by
/// scrollUp's Terminal road before the grid itself lifts.
func termHistoryKeepTopLine() {
    let grid = cardnullTermGrid()
    let history = cardnullTermHistory()
    if termHistoryCount == termHistoryLines {
        for line in 1 ..< termHistoryLines {
            for col in 0 ..< termStrideColumns {
                history[(line - 1) * termStrideColumns + col] =
                    history[line * termStrideColumns + col]
            }
        }
    } else {
        termHistoryCount += 1
    }
    let slot = (termHistoryCount - 1) * termStrideColumns
    for col in 0 ..< termStrideColumns {
        history[slot + col] = grid[col]
    }
}

/// The character one of the window's displayed rows shows at
/// a column, under the view's present lift: the lift's own
/// rows read the keeping's tail; the rows beneath read the
/// grid, shifted by the lift. The lift is clamped to the
/// keeping first — a view can never stand taller than the
/// memory that feeds it.
func termDisplayChar(_ displayRow: Int, _ col: Int) -> UInt8 {
    if termViewOffset > 0 {
        let lift = min(termViewOffset, termHistoryCount)
        if displayRow < lift {
            let line = termHistoryCount - lift + displayRow
            if line < 0 { return 0x20 }
            return cardnullTermHistory()[
                line * termStrideColumns + col]
        }
        return cardnullTermGrid()[
            (displayRow - lift) * termStrideColumns + col]
    }
    return cardnullTermGrid()[displayRow * termStrideColumns + col]
}

/// Scrolls the Terminal's view by whole lines — positive
/// toward the older lines, negative back toward the live
/// end — clamped at both ends of the conversation and
/// repainted whole where it stands, down filesScrollBy's
/// road: a scroll that cannot move paints nothing. While the
/// view stands lifted, the writing hands' dirty marks gather
/// unanswered (the face's loop leaves them standing); the
/// return to the live end answers them by wiping the slate —
/// the whole window has just been repainted from the grid.
func termScrollBy(_ lines: Int) {
    let target = min(max(termViewOffset + lines, 0),
                     termHistoryCount)
    if target == termViewOffset { return }
    termViewOffset = target
    pointerHide()
    guiPaintTerminal()
    pointerShow()
    if termViewOffset == 0 {
        termDirtyTop = -1
        termDirtyBottom = -1
    }
}

/// The active home's width and height — the one reckoning every
/// console hand below shares, so the shell's arithmetic is the
/// same in either home and only the numbers differ.
@inline(__always)
func consoleCols() -> Int {
    consoleInTerminal ? termColumns : screenColumns
}

@inline(__always)
func consoleRows() -> Int {
    consoleInTerminal ? termRows : screenRows
}

/// The active home's grid itself.
@inline(__always)
func activeGrid() -> UnsafeMutablePointer<UInt8> {
    consoleInTerminal ? cardnullTermGrid() : cardnullTextGrid()
}

/// The linear offset of one cell of the active home — the
/// stride being the grid's own keeping-width: the text grid's
/// 80, the Terminal keeping's fixed 120. The shell reads its
/// typed lines back by walking offsets reckoned here, so the
/// reading and the storage can never disagree when the
/// Terminal's visible width changes with its window.
@inline(__always)
func cellOffset(_ row: Int, _ col: Int) -> Int {
    row * (consoleInTerminal ? termStrideColumns : screenColumns) + col
}

/// Notes one Terminal row as touched by the writing hands.
func termMarkDirty(_ row: Int) {
    if termDirtyTop < 0 || row < termDirtyTop { termDirtyTop = row }
    if row > termDirtyBottom { termDirtyBottom = row }
}

/// Notes the whole Terminal grid as touched.
func termMarkAllDirty() {
    termDirtyTop = 0
    termDirtyBottom = termRows - 1
}

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
    activeGrid()[offset]
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
    if consoleInTerminal {
        cardnullTermGrid()[row * termStrideColumns + col] = character
        termMarkDirty(row)
        return
    }
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
    if consoleInTerminal {
        // The face paints the Terminal's cursor itself; the
        // console's cursor machinery must not draw over it.
        return
    }
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
    let position = cursorRow * consoleCols() + cursorCol
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
    if consoleInTerminal {
        // The Terminal's road (milestone 26): the line that
        // lifts off the top is kept before it goes — the
        // conversation can be read back now.
        termHistoryKeepTopLine()
        let grid = cardnullTermGrid()
        for row in 1 ..< termRows {
            for col in 0 ..< termColumns {
                grid[(row - 1) * termStrideColumns + col] =
                    grid[row * termStrideColumns + col]
            }
        }
        for col in 0 ..< termColumns {
            grid[(termRows - 1) * termStrideColumns + col] = 0x20
        }
        if lineStartRow > 0 {
            lineStartRow -= 1
        } else {
            lineStartCol = 0
        }
        termMarkAllDirty()
        return
    }
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
    if cursorCol == consoleCols() {
        cursorCol = 0
        cursorRow += 1
        if cursorRow == consoleRows() {
            scrollUp()
            cursorRow = consoleRows() - 1
        }
    }
}

/// Steps to the start of the next row, scrolling if the screen is
/// full. Output and prompts both begin a line this way.
func writeNewline() {
    cursorCol = 0
    cursorRow += 1
    if cursorRow == consoleRows() {
        scrollUp()
        cursorRow = consoleRows() - 1
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
        cursorCol = consoleCols() - 1
    } else {
        cursorCol -= 1
    }
    putCell(row: cursorRow, col: cursorCol, character: 0x20)
}

