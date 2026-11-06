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
// The PC text screen is a memory-mapped grid at physical address
// 0xB8000: 80 columns x 25 rows, two bytes per cell — the character,
// then its attribute (color). Milestone 1 wrote the banner and rested;
// milestone 2 keeps a small conversation with the grid: a typing area
// under the banner, a prompt at the start of each line, and a cursor
// that follows the typing.
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

/// Where the next typed character will land.
var cursorRow = typingTopRow
var cursorCol = 0

/// Where the current input line began: the row of its prompt, and the
/// column just past it. Backspace never eats past this point, so a
/// prompt — and everything above the typing area — cannot be erased.
var lineStartRow = typingTopRow
var lineStartCol = 2

/// True once the screen's very last cell has been written. From there
/// the kernel takes no new characters until backspace makes room.
/// Scrolling is a later milestone's work; a full page simply waits.
var pageFull = false

/// Writes one character cell into the VGA text buffer, through a raw
/// pointer; on bare metal, that is not recklessness, it is the
/// hardware manual.
@inline(__always)
func vgaWrite(cell offset: Int, character: UInt8, attribute: UInt8) {
    let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
    buffer[offset] = UInt16(attribute) << 8 | UInt16(character)
}

/// Writes one character at a row and column of the text grid.
@inline(__always)
func putCell(row: Int, col: Int, character: UInt8) {
    vgaWrite(cell: row * screenColumns + col,
             character: character, attribute: textAttribute)
}

/// Moves the screen's own blinking cursor to the typing position, so
/// the eye can see where the next letter will land. The cursor's
/// address lives in the display controller, spoken to through ports
/// 0x3D4 (which register) and 0x3D5 (its value): register 0x0F takes
/// the low byte of the cell offset, 0x0E the high byte.
func moveHardwareCursor() {
    let position = cursorRow * screenColumns + cursorCol
    cardnullOutb(0x3D4, 0x0F)
    cardnullOutb(0x3D5, UInt8(truncatingIfNeeded: position))
    cardnullOutb(0x3D4, 0x0E)
    cardnullOutb(0x3D5, UInt8(truncatingIfNeeded: position >> 8))
}

/// Opens a fresh input line at the cursor's row: writes the "> "
/// prompt and remembers where this line's typing began, so backspace
/// knows its limit. The cursor must be at column 0 on entry.
func startLine() {
    putCell(row: cursorRow, col: 0, character: 0x3E)   // '>'
    putCell(row: cursorRow, col: 1, character: 0x20)   // ' '
    cursorCol = 2
    lineStartRow = cursorRow
    lineStartCol = 2
}

/// Echoes one typed character at the cursor and advances. Advancing
/// off the right edge wraps to the next row; advancing off the last
/// cell of the screen fills the page — the cursor rests on that cell
/// and further characters are turned away until backspace frees it.
func echo(_ character: UInt8) {
    if pageFull { return }
    putCell(row: cursorRow, col: cursorCol, character: character)
    cursorCol += 1
    if cursorCol == screenColumns {
        cursorCol = 0
        cursorRow += 1
        if cursorRow == screenRows {
            cursorRow = screenRows - 1
            cursorCol = screenColumns - 1
            pageFull = true
        }
    }
}

/// Enter: close the current line and open a fresh one beneath it.
/// On the last row there is no beneath — the key is simply set aside.
/// Lifting a full screen upward is scrolling, a later milestone.
func newline() {
    if pageFull || cursorRow == screenRows - 1 { return }
    cursorRow += 1
    cursorCol = 0
    startLine()
}

/// Backspace: take back the last character typed, and only ever a
/// typed character — never the prompt, never the banner, never
/// anything above the typing area.
func backspace() {
    if pageFull {
        // The cursor rests on the full page's last cell, which holds
        // the last character typed. Erase it; the page has room again.
        putCell(row: cursorRow, col: cursorCol, character: 0x20)
        pageFull = false
        return
    }
    if cursorCol == 0 {
        // At the start of a screen row, the character before is the
        // last cell of the row above — but only when this input line
        // began on an earlier row and wrapped onto this one.
        if cursorRow <= lineStartRow { return }
        cursorRow -= 1
        cursorCol = screenColumns - 1
    } else {
        if cursorRow == lineStartRow && cursorCol == lineStartCol { return }
        cursorCol -= 1
    }
    putCell(row: cursorRow, col: cursorCol, character: 0x20)
}

// ---------------------------------------------------------------------------
// The keyboard.
//
// Milestone 2 listens to a PS/2 keyboard by *polling*: the kernel asks
// the controller, over and over, whether a key has spoken. No
// interrupts, no IDT — those are a later milestone, and the README
// says so. The controller answers through two ports:
//
//   0x64  status: its lowest bit is set while a byte waits.
//   0x60  data:   the byte itself — a scancode, set 1.
//
// A key press sends its *make* code; a release sends the same code
// with the top bit set (the *break* code). Shift is tracked by hand:
// its makes set the flag, its breaks clear it.
// ---------------------------------------------------------------------------

/// The keyboard controller's two doors.
let keyboardStatusPort: UInt16 = 0x64
let keyboardDataPort: UInt16 = 0x60

/// Is either Shift key currently held?
var shiftHeld = false

/// True after a 0xE0 byte: extended keys (the keypad's Enter, the
/// arrow keys, ...) announce themselves with that prefix and a second
/// code. Milestone 2 has no work for them, so the second code is
/// swallowed whole rather than mistaken for an ordinary key.
var extendedPrefix = false

/// The letter rows of the keyboard, in scancode order, as raw bytes.
let topRowLetters: StaticString = "qwertyuiop"     // codes 0x10 ... 0x19
let homeRowLetters: StaticString = "asdfghjkl"     // codes 0x1E ... 0x26
let bottomRowLetters: StaticString = "zxcvbnm"     // codes 0x2C ... 0x32

/// The digit row, plain and shifted, in scancode order (0x02 ... 0x0B).
let digitRow: StaticString = "1234567890"
let digitRowShifted: StaticString = "!@#$%^&*()"

/// One letter from a row table, capitalized while Shift is held.
func letter(from table: StaticString, at index: Int) -> UInt8 {
    var character = table.utf8Start[index]
    if shiftHeld && character >= 0x61 && character <= 0x7A {
        character -= 0x20   // a ... z -> A ... Z
    }
    return character
}

/// Translates a scancode set 1 make code to the character it types,
/// or 0 for a key milestone 2 does not take. Letters, digits, and
/// space are the whole alphabet for now — an honest small set.
func ascii(forScancode code: UInt8) -> UInt8 {
    switch code {
    case 0x02 ... 0x0B:
        let index = Int(code - 0x02)
        return shiftHeld ? digitRowShifted.utf8Start[index]
                         : digitRow.utf8Start[index]
    case 0x10 ... 0x19:
        return letter(from: topRowLetters, at: Int(code - 0x10))
    case 0x1E ... 0x26:
        return letter(from: homeRowLetters, at: Int(code - 0x1E))
    case 0x2C ... 0x32:
        return letter(from: bottomRowLetters, at: Int(code - 0x2C))
    case 0x39:
        return 0x20   // space
    default:
        return 0
    }
}

/// Acts on one scancode from the keyboard: shift bookkeeping, Enter,
/// Backspace, and the ordinary characters. Every other key — and every
/// key release but Shift's — is ignored, silently, by design.
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
    case 0x0E:                  // Backspace
        backspace()
    case 0x1C:                  // Enter
        newline()
    case 0x80 ... 0xFF:         // any other key's release: not our affair
        break
    default:
        let character = ascii(forScancode: code)
        if character != 0 {
            echo(character)
        }
    }
    moveHardwareCursor()
}

/// Kernel entry point. Called once by the boot floor; never returns —
/// an operating system that finishes has stopped being one.
///
/// Milestone 1 put CARDNULL on the screen, and milestone 2 leaves it
/// there: the banner stands, a prompt opens beneath it, and the kernel
/// spends its life asking the keyboard what was typed and writing the
/// answer on the screen.
@_cdecl("kmain")
public func kmain() {
    // Wipe the screen the bootloader left behind: 80 x 25 blank cells,
    // so the first word stands on a clean field.
    for cell in 0 ..< (screenColumns * screenRows) {
        vgaWrite(cell: cell, character: 0x20, attribute: textAttribute)
    }

    // The banner, at the top-left cell. A StaticString's bytes are
    // stored NUL-terminated in read-only data (Embedded Swift's trimmed
    // StaticString offers the pointer but not the length), so walk to
    // the terminator — and never past the edge of the first row.
    var cell = 0
    while cell < screenColumns {
        let character = cardnullBanner.utf8Start[cell]
        if character == 0 { break }
        vgaWrite(cell: cell, character: character, attribute: textAttribute)
        cell += 1
    }

    // The first prompt, and the cursor resting just past it.
    startLine()
    moveHardwareCursor()

    // The kernel's whole work, from here on: poll the keyboard. While
    // the status port says a byte waits, read it and answer it on the
    // screen. There are no interrupts to wake us, so we ask, and ask,
    // and ask — simple, honest, and fast enough for fingers.
    while true {
        if cardnullInb(keyboardStatusPort) & 0x01 != 0 {
            handleScancode(cardnullInb(keyboardDataPort))
        }
    }
}
