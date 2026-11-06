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
// milestone 2 kept a small conversation with the grid. Milestone 3
// makes it a true terminal: one door for all output (typed echo and
// the shell's answers walk through the same writeChar), and when the
// last row fills, the whole page lifts — scrolling, the way every
// terminal since the teletype has made room for the next line.
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

/// Writes one character cell into the VGA text buffer, through a raw
/// pointer; on bare metal, that is not recklessness, it is the
/// hardware manual.
@inline(__always)
func vgaWrite(cell offset: Int, character: UInt8, attribute: UInt8) {
    let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
    buffer[offset] = UInt16(attribute) << 8 | UInt16(character)
}

/// Reads back the character half of one cell of the text buffer. The
/// shell reads the typed line straight off the screen this way — what
/// the typist sees is literally what the kernel obeys, and no separate
/// line buffer exists to disagree with it.
@inline(__always)
func vgaChar(cell offset: Int) -> UInt8 {
    let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
    return UInt8(truncatingIfNeeded: buffer[offset])
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

/// Lifts the whole page by one row: every row takes the row beneath
/// it, and the last row is wiped clean for whatever comes next. The
/// banner scrolls away with everything else when the conversation
/// outgrows one screen — a real terminal keeps no favorites.
func scrollUp() {
    let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
    for row in 1 ..< screenRows {
        for col in 0 ..< screenColumns {
            buffer[(row - 1) * screenColumns + col] =
                buffer[row * screenColumns + col]
        }
    }
    for col in 0 ..< screenColumns {
        buffer[(screenRows - 1) * screenColumns + col] =
            UInt16(textAttribute) << 8 | 0x20
    }
    if lineStartRow > 0 {
        lineStartRow -= 1
    } else {
        lineStartCol = 0
    }
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
// The kernel listens to a PS/2 keyboard by *polling*: it asks the
// controller, over and over, whether a key has spoken. No interrupts,
// no IDT — those are a later milestone, and the README says so. The
// controller answers through two ports:
//
//   0x64  status: its lowest bit is set while a byte waits.
//   0x60  data:   the byte itself — a scancode, set 1.
//
// A key press sends its *make* code; a release sends the same code
// with the top bit set (the *break* code). Shift is tracked by hand:
// its makes set the flag, its breaks clear it. Caps Lock is a toggle:
// each press flips it, and it joins with Shift the way typewriters
// taught us — a letter is capital when exactly one of them is active.
// Milestone 3 completes the typewriter: every punctuation key of the
// main block, plain and shifted, joins the letters, digits, and space
// that milestone 2 took.
// ---------------------------------------------------------------------------

/// The keyboard controller's two doors.
let keyboardStatusPort: UInt16 = 0x64
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

/// help's answer: the list itself.
let helpTitle: StaticString = "Commands:"
let helpHelpLine: StaticString = "  help    show this list"
let helpAboutLine: StaticString = "  about   what Cardnull OS is"
let helpVerseLine: StaticString = "  verse   a verse of Scripture"
let helpClearLine: StaticString = "  clear   clear the screen"

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
/// the VGA text font this kernel writes in carries no em dash, and
/// the verse itself loses nothing by its citation wearing ASCII.
let verseLine: StaticString =
    "In the beginning was the Word, and the Word was with God, and the Word was God."
let verseAttribution: StaticString = "- John 1:1 (Douay-Rheims)"

/// The answer to everything else.
let unknownLine: StaticString =
    "Unknown command. Type 'help' and press Enter."

/// True when the typed line is nothing but spaces — the typist
/// pressed Enter on an empty line, which earns only a fresh prompt.
func lineIsBlank() -> Bool {
    let start = lineStartRow * screenColumns + lineStartCol
    let end = cursorRow * screenColumns + cursorCol
    var cell = start
    while cell < end {
        if vgaChar(cell: cell) != 0x20 { return false }
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
    while cell < end && vgaChar(cell: cell) == 0x20 { cell += 1 }
    var index = 0
    while command.utf8Start[index] != 0 {
        if cell >= end { return false }
        var character = vgaChar(cell: cell)
        if character >= 0x41 && character <= 0x5A {
            character += 0x20   // A ... Z -> a ... z
        }
        if character != command.utf8Start[index] { return false }
        cell += 1
        index += 1
    }
    while cell < end && vgaChar(cell: cell) == 0x20 { cell += 1 }
    return cell == end
}

/// The clear command's work: wipe the whole screen and open a fresh
/// prompt at the very top. Nothing is kept — that is what clear means.
func clearScreen() {
    for cell in 0 ..< (screenColumns * screenRows) {
        vgaWrite(cell: cell, character: 0x20, attribute: textAttribute)
    }
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

    writeNewline()
    if !blank {
        if isHelp {
            writeLine(helpTitle)
            writeLine(helpHelpLine)
            writeLine(helpAboutLine)
            writeLine(helpVerseLine)
            writeLine(helpClearLine)
        } else if isAbout {
            writeLine(aboutLine1)
            writeLine(aboutLine2)
            writeLine(aboutLine3)
            writeLine(aboutLine4)
        } else if isVerse {
            writeLine(verseLine)
            writeLine(verseAttribution)
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
/// and listened; milestone 3 makes the screen a scrolling terminal and
/// the prompt a shell that answers. The banner stands, a prompt opens
/// beneath it, and the kernel spends its life asking the keyboard what
/// was typed — echoing the typing, and answering the finished lines.
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
