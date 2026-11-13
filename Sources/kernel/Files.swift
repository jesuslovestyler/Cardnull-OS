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
// Milestone 19: the desktop file manager — the disc gets a face.
//
// Until now the disc could be read only in words: `ls` named
// its files in the shell, `cat` spoke one, `run` and `feather`
// carried programs off it. This stone gives the disc a window.
// The Files window stands on the desktop beside the Terminal
// and the Welcome card — a sibling in every mechanic the face
// knows: it is called up from its own launcher in the bottom
// bar (a third now, reckoned by the same layout budget: the
// gaps give first, the furniture never), or by a new shell
// command, `files`; it drags by its title bar under the same
// outline and the same clamp; it maximizes and restores by
// its box and by a title double-click; it closes by its box
// alone; and it takes the room — the bright title bar and the
// top of the painting order — by the same reckoning the two
// elder windows keep, now gone four-way in guiRoomHolder.
//
// The list is the disc's own truth, read through the disc
// machinery `ls` uses — the same ATAPI drive, the same
// ISO9660 walk over the root's records, the same forgiving of
// the ";1" suffix, the same two nameless entries passed over
// — gathered into the floor's keeping (cardnullFilesKeeping)
// when the window opens, so the window and `ls` can never
// disagree: they read the one disc by the one road. Each entry
// wears a small drawn mark of its kind — a folder for a
// folder, a page for a text file, a cardinal play-square for
// a program, a quill for a feather, a grey chip for the files
// that are part of Cardnull itself — its true name as the
// disc keeps it, and its size in plain words ("1,749 bytes";
// a folder's line says "Folder", as `ls`'s says <DIR>). A
// status line at the window's foot counts the disc's files,
// in words. The disc is read-only this stone: the list is
// read when the window opens, and opening it again reads it
// again — that reopening is the whole of the refresh, stated
// plainly rather than dressed as machinery.
//
// A double-click opens, by kind:
//   - a text file opens the Reader: a fourth window, titled
//     with the file's name, holding the file's actual bytes
//     read off the disc, wrapped at its width and scrollable;
//     its close box returns to the desktop with the Files
//     window still standing;
//   - a feather or a program is *launched through the
//     Terminal*, by the most honest road the house has: the
//     Files window gives the Terminal the room and types the
//     very command a hand would type — "feather /FACE.FEATHER",
//     "run /SPIN.BIN" — letter by letter through the shell's
//     own typing hand, and presses Enter by calling the
//     shell's answering hand. The conversation therefore shows
//     the card and the run because the card and the run truly
//     happen there, down milestone 9's and 11's roads with
//     every validation standing; a graphical feather takes
//     the whole screen under milestone 18's rules and returns
//     to a desktop whose windows stand as they were; and Esc
//     stops a session launched this way exactly as it stops
//     a typed one. If the Terminal's line is not blank — a
//     half-typed command of the user's own — the window does
//     not type over it: it says so in its status line and
//     opens nothing.
//   - anything else does not open, and the window does not
//     guess: a folder's double-click is answered in the status
//     line ("... is a folder - this window shows the top of
//     the disc."), and a file of the machine's own kind with
//     "... is part of Cardnull itself and doesn't open." —
//     BOOT.CATALOG, EFI.IMG and their kin are listed honestly
//     and left alone, exactly as a hand is told about them.
//
// Scrolling, for the list that outgrows its window (the root
// holds twenty entries; the window shows ten): the arrows at
// the list's right edge, clicked a line at a time; and while
// the window holds the room, the keyboard's arrow keys move
// a line and its page keys a windowful — answered by the
// face's loop out of the extended codes, the one piece of
// keyboard the new windows take. The Reader scrolls by the
// same machinery over its wrapped lines. The wheel is not
// pretended: the mouse's waking does not ask for it, so no
// window claims it.
//
// The keeping's honest bounds, stated rather than hidden:
// forty-eight entries at most, a name's first thirty-one
// letters (the disc's longest name is sixteen), and the
// Reader holds a file's first 9,760 bytes — a longer page is
// shown to that bound with a plain closing line saying the
// file goes on. The windows take no frames and no heap: the
// keeping is the floor's lending, and the list's reading is
// the disc driver's ordinary work, so `mem` reads the same
// after a visit as before it — the kernel's grown image
// aside, as every milestone confesses.
// ---------------------------------------------------------------------------

/// The keeping's shape, agreed with the floor's lending:
/// the entries at its head, the status line's bytes after
/// them, the Reader's file name after that, and the Reader's
/// page filling the rest.
let filesKeepingBytes = 12288
let filesMaxEntries = 48
let filesEntryStride = 48
let filesEntryNameCap = 31
let filesListOffset = 0
let filesStatusOffset = 2304          // filesMaxEntries * stride
let filesStatusCap = 160
let readerNameOffset = 2464
let readerNameCap = 64
let readerTextOffset = 2528
let readerTextCap = 9760              // filesKeepingBytes - 2528

/// The entry kinds, by the mark each wears.
let filesKindFolder = 0
let filesKindText = 1
let filesKindProgram = 2
let filesKindFeather = 3
let filesKindSystem = 4

/// The Files window's place and shape, reckoned at the
/// face's opening beside its siblings'.
var guiFilesX = 0
var guiFilesY = 0
var guiFilesW = 0
var guiFilesH = 0

/// Whether the Files window stands, and whether it holds
/// the room.
var filesOpen = false
var guiFocusFiles = false

/// The Files window's maximize bookkeeping, as the
/// Terminal's: whether it stands maximized, and the place
/// restore returns it to.
var filesMaximized = false
var filesSavedX = 0
var filesSavedY = 0
var filesSavedW = 0
var filesSavedH = 0

/// The list's books: how many entries the keeping holds,
/// which of them stands first in the window, and which one
/// the hand last chose.
var filesCount = 0
var filesScroll = 0
var filesSelected = -1

/// The status line's length, in the keeping.
var filesStatusLength = 0

/// The double-clicks' bookkeeping for the Files window, kept
/// as the Terminal's is: the title bar's pairing (a press
/// within half a second of the last trades maximize for
/// restore), and the list's own — the row the last press
/// chose, and when, so a second press on the same row inside
/// the same window of ticks is the double-click that opens.
var filesTitlePressTick: UInt64 = 0
var filesTitlePressArmed = false
var filesPressTick: UInt64 = 0
var filesPressArmed = false
var filesPressRow = -1

/// The `files` command's word to the face: set when the
/// command is answered at the text console, taken and
/// cleared by runGui at its door.
var filesWantedAtFace = false

/// The Reader window's place and shape.
var guiReaderX = 0
var guiReaderY = 0
var guiReaderW = 0
var guiReaderH = 0

/// Whether the Reader stands, and whether it holds the room.
var readerOpen = false
var guiFocusReader = false

/// The Reader's maximize bookkeeping.
var readerMaximized = false
var readerSavedX = 0
var readerSavedY = 0
var readerSavedW = 0
var readerSavedH = 0

/// The Reader's page: the file name's length in its keeping,
/// the text's length in its own, whether the file goes on
/// past the keeping, and the first wrapped line the window
/// shows.
var readerNameLength = 0
var readerTextLength = 0
var readerTruncated = false
var readerScroll = 0

/// The Reader title bar's double-click pairing.
var readerTitlePressTick: UInt64 = 0
var readerTitlePressArmed = false

/// The windows' words.
let filesFolderWord: StaticString = "Folder"
let filesFolderSuffix: StaticString =
    " is a folder - this window shows the top of the disc."
let filesSystemSuffix: StaticString =
    " is part of Cardnull itself and doesn't open."
let filesTerminalBusyLine: StaticString =
    "The Terminal has an unfinished line - this opens when it is clear."
let readerTruncatedLine: StaticString =
    "The file goes on past what this window can hold."

/// Which window holds the room, as one reckoning the
/// painters and the press both read: 1 the Welcome side (the
/// elder default — bare desktop included), 2 the Terminal,
/// 3 the Files window, 4 the Reader — and 6 the Write
/// window since milestone 31, checked first among the
/// document windows below, since exactly one focus flag
/// ever stands at a time (the feather's 5 stands above all
/// of them, as it always has). At most one of the younger
/// standings ever stands; every hand that gives the room
/// clears the others as it takes it.
func guiRoomHolder() -> Int {
    if guiFocusFeather { return 5 }
    if guiFocusWrite { return 6 }
    if guiFocusBible { return 7 }
    if guiFocusReader { return 4 }
    if guiFocusFiles { return 3 }
    if guiFocusTerminal { return 2 }
    return 1
}

/// Gives the room to the Files window: the whole desktop is
/// repainted in the new standing, as guiSetFocus repaints it
/// for the elder two.
func guiSetFocusFiles() {
    if guiFocusFiles && !guiFocusTerminal && !guiFocusReader
        && !guiFocusWrite && !guiFocusBible {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = true
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Gives the room to the Reader, by the same road.
func guiSetFocusReader() {
    if guiFocusReader && !guiFocusTerminal && !guiFocusFiles
        && !guiFocusWrite && !guiFocusBible {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = true
    guiFocusWrite = false
    guiFocusBible = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

// ---------------------------------------------------------------------------
// The keeping's reading hands: one entry's facts, by its
// number. An entry is forty-eight bytes: the name's letters
// at its head (at most filesEntryNameCap of them), the
// name's length at +32, its kind at +33, its size in little
// endian at +36, and its extent — where its bytes live on
// the disc — at +40.
// ---------------------------------------------------------------------------

func filesEntryNameLength(_ entry: Int) -> Int {
    Int(cardnullFilesKeeping()[entry * filesEntryStride + 32])
}

func filesEntryKind(_ entry: Int) -> Int {
    Int(cardnullFilesKeeping()[entry * filesEntryStride + 33])
}

func filesEntrySize(_ entry: Int) -> UInt32 {
    let base = cardnullFilesKeeping()
    let at = entry * filesEntryStride + 36
    return UInt32(base[at]) | UInt32(base[at + 1]) << 8
        | UInt32(base[at + 2]) << 16 | UInt32(base[at + 3]) << 24
}

func filesEntryExtent(_ entry: Int) -> UInt32 {
    let base = cardnullFilesKeeping()
    let at = entry * filesEntryStride + 40
    return UInt32(base[at]) | UInt32(base[at + 1]) << 8
        | UInt32(base[at + 2]) << 16 | UInt32(base[at + 3]) << 24
}

/// A name's kind, judged by its ending the way a hand judges
/// it: a folder first, whatever its name; then the endings
/// the window knows how to open — TXT a page, BIN a program,
/// FEATHER a package — and everything else the machine's own
/// kind. The comparison folds small letters up, as the disc
/// reader's matching does.
func filesClassify(_ base: UnsafeMutablePointer<UInt8>,
                   _ entryBase: Int, _ nameLength: Int,
                   _ isDirectory: Bool) -> Int {
    if isDirectory { return filesKindFolder }
    var dot = -1
    var index = 0
    while index < nameLength {
        if base[entryBase + index] == 0x2E { dot = index }
        index += 1
    }
    if dot < 0 { return filesKindSystem }
    let extStart = entryBase + dot + 1
    let extLength = nameLength - dot - 1
    if filesExtensionMatches(base, extStart, extLength, "TXT") {
        return filesKindText
    }
    if filesExtensionMatches(base, extStart, extLength, "BIN") {
        return filesKindProgram
    }
    if filesExtensionMatches(base, extStart, extLength, "FEATHER") {
        return filesKindFeather
    }
    return filesKindSystem
}

/// One ending against a word, letter for letter with case
/// folded — the extension's whole length must be the word's.
func filesExtensionMatches(_ base: UnsafeMutablePointer<UInt8>,
                           _ start: Int, _ length: Int,
                           _ word: StaticString) -> Bool {
    var index = 0
    while true {
        let wanted = word.utf8Start[index]
        if wanted == 0 { return index == length }
        if index >= length { return false }
        var byte = base[start + index]
        if byte >= 0x61 && byte <= 0x7A { byte -= 0x20 }
        if byte != wanted { return false }
        index += 1
    }
}

/// Reads the disc's root into the keeping: the walk
/// listDirectory makes, record by record over the root's
/// sectors — a record's own length saying where the next
/// begins, a zero length ending the sector, the two nameless
/// entries passed over, the ";1" suffix forgiven exactly as
/// `ls` forgives it — gathering instead of printing. The
/// window's list is therefore the shell's list, read by the
/// one road; the proof holds the two screenshots side by
/// side. The status line is set as the reading ends: the
/// count in plain words, or the disc's own answer when there
/// is no disc to read, or the reading failed — in which case
/// the entries gathered before the failure stand, as `ls`'s
/// partial listing stands.
func filesReadRootList() {
    filesCount = 0
    if bundleValid {
        filesReadBundleList()
        return
    }
    if !discDriveFound {
        filesSetStatus(discAbsentLine)
        return
    }
    if !discIsoFound {
        filesSetStatus(discUnknownFsLine)
        return
    }
    let base = cardnullFilesKeeping()
    let buffer = discBuffer()
    var failed = false
    let size = isoRootSize
    if size > 0 {
        var sectorIndex: UInt32 = 0
        let sectorCount = (size + UInt32(discSectorBytes) - 1)
            / UInt32(discSectorBytes)
        while sectorIndex < sectorCount && !failed {
            if !discReadSector(isoRootExtent + sectorIndex) {
                failed = true
                break
            }
            var inSector = discSectorBytes
            let remaining = size
                - sectorIndex * UInt32(discSectorBytes)
            if remaining < UInt32(discSectorBytes) {
                inSector = Int(remaining)
            }
            var offset = 0
            while offset < inSector {
                let recordLength = Int(buffer[offset])
                if recordLength == 0 { break }
                if recordLength >= 34
                    && filesCount < filesMaxEntries {
                    let nameLength = Int(buffer[offset + 32])
                    if !(nameLength == 1
                        && buffer[offset + 33] <= 1) {
                        filesStoreEntry(base, buffer, offset)
                    }
                }
                offset += recordLength
            }
            sectorIndex += 1
        }
    }
    if failed {
        filesSetStatus(discReadErrorLine)
    } else {
        filesSetCountStatus()
    }
}

/// Gathers the bundle's table into the keeping — the Files
/// window's list when a proven bundle serves (milestone 23):
/// the same entries `ls` prints from memory, in the same
/// order, so the window's list and the shell's list are one
/// list. The keeping's extent field holds the file's bundle
/// offset; the Reader reads by it through the serving layer,
/// which knows which meaning the field carries by which
/// source is serving.
func filesReadBundleList() {
    let base = cardnullFilesKeeping()
    var index = 0
    while index < bundleFileCount && filesCount < filesMaxEntries {
        if bundleEntryAt(index) {
            filesStoreBundleEntry(base)
        }
        index += 1
    }
    filesSetCountStatus()
}

/// Gathers one bundle entry into the keeping, at the next
/// entry's place: the name as the bundle keeps it (at most
/// the keeping's cap of letters), its kind by the window's
/// own classifying, its size, and its bundle offset in the
/// extent field.
func filesStoreBundleEntry(
    _ base: UnsafeMutablePointer<UInt8>
) {
    let entryBase = filesListOffset
        + filesCount * filesEntryStride
    let bundle = bundleBase()
    let copyLength = min(bundleEntryNameLength,
                         filesEntryNameCap)
    var index = 0
    while index < copyLength {
        base[entryBase + index] =
            bundle[bundleEntryNameOffset + index]
        index += 1
    }
    base[entryBase + 32] = UInt8(copyLength)
    base[entryBase + 33] = UInt8(filesClassify(
        base, entryBase, copyLength, false))
    let size = bundleEntryLength
    base[entryBase + 36] = UInt8(size & 0xFF)
    base[entryBase + 37] = UInt8((size >> 8) & 0xFF)
    base[entryBase + 38] = UInt8((size >> 16) & 0xFF)
    base[entryBase + 39] = UInt8((size >> 24) & 0xFF)
    let offset = bundleEntryOffset
    base[entryBase + 40] = UInt8(offset & 0xFF)
    base[entryBase + 41] = UInt8((offset >> 8) & 0xFF)
    base[entryBase + 42] = UInt8((offset >> 16) & 0xFF)
    base[entryBase + 43] = UInt8((offset >> 24) & 0xFF)
    filesCount += 1
}

/// Gathers one directory record into the keeping, at the
/// next entry's place: the name's effective letters (its
/// ";1" forgiven, at most the keeping's cap of them), its
/// kind, its size, and its extent.
func filesStoreEntry(_ base: UnsafeMutablePointer<UInt8>,
                     _ buffer: UnsafeMutablePointer<UInt8>,
                     _ record: Int) {
    let entryBase = filesListOffset
        + filesCount * filesEntryStride
    let nameLength = Int(buffer[record + 32])
    var effective = nameLength
    var index = 0
    while index < nameLength {
        if buffer[record + 33 + index] == 0x3B {   // ';'
            effective = index
            break
        }
        index += 1
    }
    let copyLength = min(effective, filesEntryNameCap)
    index = 0
    while index < copyLength {
        base[entryBase + index] = buffer[record + 33 + index]
        index += 1
    }
    base[entryBase + 32] = UInt8(copyLength)
    let isDirectory = buffer[record + 25] & 0x02 != 0
    base[entryBase + 33] = UInt8(filesClassify(
        base, entryBase, copyLength, isDirectory))
    let size = discU32(buffer, record + 10)
    base[entryBase + 36] = UInt8(size & 0xFF)
    base[entryBase + 37] = UInt8((size >> 8) & 0xFF)
    base[entryBase + 38] = UInt8((size >> 16) & 0xFF)
    base[entryBase + 39] = UInt8((size >> 24) & 0xFF)
    let extent = discU32(buffer, record + 2)
    base[entryBase + 40] = UInt8(extent & 0xFF)
    base[entryBase + 41] = UInt8((extent >> 8) & 0xFF)
    base[entryBase + 42] = UInt8((extent >> 16) & 0xFF)
    base[entryBase + 43] = UInt8((extent >> 24) & 0xFF)
    filesCount += 1
}

// ---------------------------------------------------------------------------
// The status line: the window's one sentence, kept as bytes
// in the keeping and painted at its foot, wrapped over two
// lines — and standing in the body when the list is empty,
// so the window's answer is never nowhere.
// ---------------------------------------------------------------------------

/// Sets the status to a standing sentence's words.
func filesSetStatus(_ text: StaticString) {
    let base = cardnullFilesKeeping()
    var pen = 0
    while text.utf8Start[pen] != 0 && pen < filesStatusCap {
        base[filesStatusOffset + pen] = text.utf8Start[pen]
        pen += 1
    }
    filesStatusLength = pen
}

/// Sets the status to the count, in plain words: "20 files
/// on the disc." (and "1 file", because this house conjugates).
func filesSetCountStatus() {
    let base = cardnullFilesKeeping()
    var pen = 0
    var divisor: UInt32 = 1
    var rest = UInt32(filesCount)
    while rest / divisor >= 10 { divisor *= 10 }
    while true {
        base[filesStatusOffset + pen] = 0x30 + UInt8(rest / divisor)
        pen += 1
        rest %= divisor
        if divisor == 1 { break }
        divisor /= 10
    }
    let tail: StaticString
    if bundleValid {
        tail = filesCount == 1 ? " file carried in memory."
                               : " files carried in memory."
    } else {
        tail = filesCount == 1 ? " file on the disc."
                               : " files on the disc."
    }
    var index = 0
    while tail.utf8Start[index] != 0 {
        base[filesStatusOffset + pen] = tail.utf8Start[index]
        pen += 1
        index += 1
    }
    filesStatusLength = pen
}

/// Sets the status to a sentence about one entry: its true
/// name, then the suffix's words — the folder's answer, or
/// the machine's-own answer.
func filesSetStatusNameSentence(_ entry: Int,
                                _ suffix: StaticString) {
    let base = cardnullFilesKeeping()
    var pen = 0
    let nameLength = filesEntryNameLength(entry)
    var index = 0
    while index < nameLength && pen < filesStatusCap {
        base[filesStatusOffset + pen]
            = base[entry * filesEntryStride + index]
        pen += 1
        index += 1
    }
    index = 0
    while suffix.utf8Start[index] != 0 && pen < filesStatusCap {
        base[filesStatusOffset + pen] = suffix.utf8Start[index]
        pen += 1
        index += 1
    }
    filesStatusLength = pen
}

/// Paints the status line's words at a place, wrapped by
/// words over at most two lines of twofold letters. A word
/// that cannot stand whole on a fresh line is drawn to the
/// line's end and the sentence rests there — the window's
/// sentences are written to fit their two lines, and the
/// walk never paints past them.
func guiPaintStatusLines(_ x: Int, _ y: Int) {
    let base = cardnullFilesKeeping()
    let cols = (guiFilesW - 24) / 16
    var line = 0
    var col = 0
    var index = 0
    while index < filesStatusLength && line < 2 {
        let byte = base[filesStatusOffset + index]
        if byte == 0x20 {
            index += 1
            if col > 0 { col += 1 }
            continue
        }
        var wordLength = 0
        while index + wordLength < filesStatusLength
            && base[filesStatusOffset + index + wordLength] != 0x20 {
            wordLength += 1
        }
        if col + wordLength > cols && col > 0 {
            line += 1
            col = 0
            if line >= 2 { return }
            continue
        }
        var step = 0
        while step < wordLength && col < cols {
            guiDrawGlyph(x + col * 16, y + line * 20, 2,
                         base[filesStatusOffset + index + step],
                         guiInkColor)
            col += 1
            step += 1
        }
        index += wordLength
    }
}

// ---------------------------------------------------------------------------
// Drawing hands the two windows share with no elder sibling:
// letters read out of a keeping, and a size in decimal with
// its thousands gathered — "2,949,120" — because a size on
// the desktop is a fact spoken plainly, commas and all.
// ---------------------------------------------------------------------------

/// Draws letters held in a keeping, from a place and for a
/// length, and returns the column just past the last one —
/// guiDrawText's twin for bytes that are not a StaticString:
/// a file's name, wherever it must stand.
@discardableResult
func guiDrawBytes(_ x: Int, _ y: Int, _ scale: Int,
                  _ base: UnsafeMutablePointer<UInt8>,
                  _ start: Int, _ length: Int,
                  _ rgb: UInt32) -> Int {
    var penX = x
    var index = 0
    while index < length {
        let byte = base[start + index]
        if byte >= 0x20 && byte != 0x7F {
            guiDrawGlyph(penX, y, scale, byte, rgb)
        }
        penX += 8 * scale
        index += 1
    }
    return penX
}

/// Draws a value in decimal with a comma wherever the
/// thousands gather, and returns the pen's end — the size's
/// drawing hand, so the number a window speaks is the number
/// `ls` speaks, dressed for the desktop.
@discardableResult
func guiDrawGroupedDecimal(_ x: Int, _ y: Int, _ scale: Int,
                           _ value: UInt64,
                           _ rgb: UInt32) -> Int {
    var divisor: UInt64 = 1
    var digits = 1
    while value / divisor >= 10 { divisor *= 10; digits += 1 }
    var penX = x
    var remaining = value
    var digitIndex = 0
    while true {
        guiDrawGlyph(penX, y, scale,
                     0x30 + UInt8(remaining / divisor), rgb)
        penX += 8 * scale
        digitIndex += 1
        remaining %= divisor
        if divisor == 1 { break }
        divisor /= 10
        if (digits - digitIndex) % 3 == 0 {
            guiDrawGlyph(penX, y, scale, 0x2C, rgb)   // ','
            penX += 8 * scale
        }
    }
    return penX
}

/// Draws one entry's size at a row's right end: the grouped
/// number and its word — " bytes", or " byte" for the one
/// lonesome case — ending where the row's reckoning says
/// sizes end, so the column stands straight down the list.
func guiDrawSizeRight(_ endX: Int, _ y: Int, _ size: UInt32) {
    var digits = 1
    var reckon = size
    while reckon >= 10 { digits += 1; reckon /= 10 }
    let commas = (digits - 1) / 3
    let word: StaticString = size == 1 ? " byte" : " bytes"
    let wordGlyphs = size == 1 ? 5 : 6
    let startX = endX - (digits + commas + wordGlyphs) * 16
    let after = guiDrawGroupedDecimal(startX, y, 2,
                                      UInt64(size), guiInkColor)
    guiDrawText(after, y, 2, word, guiInkColor)
}

/// Paints one scroll button: a bar button's small cousin,
/// 28 x 28, carrying a triangle of honest rectangles — up or
/// down — in ink when the way it points can be travelled,
/// and in a dimmed ink when it cannot, so the button never
/// promises a road that is not there.
func guiPaintScrollButton(_ bx: Int, _ by: Int, _ up: Bool,
                          _ enabled: Bool) {
    guiFillRect(bx, by, 28, 28, guiButtonColor)
    guiFillRect(bx, by, 28, 2, guiBorderColor)
    guiFillRect(bx, by + 26, 28, 2, guiBorderColor)
    guiFillRect(bx, by, 2, 28, guiBorderColor)
    guiFillRect(bx + 26, by, 2, 28, guiBorderColor)
    let ink: UInt32 = enabled ? guiInkColor : 0x9A8B74
    var row = 0
    while row < 8 {
        let width = up ? 2 * (row + 1) : 2 * (8 - row)
        guiFillRect(bx + 14 - width / 2, by + 6 + row * 2,
                    width, 2, ink)
        row += 1
    }
}

// ---------------------------------------------------------------------------
// The Files window. Its layout, all of it reckoned from its
// own rect like its siblings': the title strip across the
// head (36, the house measure); the list from 48 below the
// top, in rows of 32 — a 24 mark, a name at twofold, a size
// at the right — down to the status strip's divider; and
// the status strip, 56 at the foot, holding the window's
// sentence over two lines. The scroll buttons stand in a
// rail at the list's right: up at the list's head, down
// above the divider, each exactly the square that is
// painted, as the boxes in the title are.
// ---------------------------------------------------------------------------

/// One list row's height: the mark's 24 with air above and
/// below, and the name's twofold letters centred in it.
let filesRowHeight = 32

func filesListTop() -> Int { guiFilesY + 48 }
func filesStatusTop() -> Int { guiFilesY + guiFilesH - 56 }

/// How many rows the list can show whole, as the window
/// stands — the reckoning every scroll is clamped by.
func filesVisibleRows() -> Int {
    max(1, (filesStatusTop() - filesListTop()) / filesRowHeight)
}

/// The scroll buttons' left edge: the rail at the window's
/// right, inside its border.
func filesRailX() -> Int { guiFilesX + guiFilesW - 40 }

func guiFilesContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiFilesX && x < guiFilesX + guiFilesW
        && y >= guiFilesY && y < guiFilesY + guiFilesH
}

func guiFilesCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiFilesX, guiFilesW)
        && x < guiCloseBoxX(guiFilesX, guiFilesW) + guiBoxW
        && y >= guiFilesY + guiBoxTop
        && y < guiFilesY + guiBoxTop + guiBoxH
}

func guiFilesMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiFilesX, guiFilesW)
        && x < guiMaxBoxX(guiFilesX, guiFilesW) + guiBoxW
        && y >= guiFilesY + guiBoxTop
        && y < guiFilesY + guiBoxTop + guiBoxH
}

func guiFilesTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiFilesX && x < guiFilesX + guiFilesW
        && y >= guiFilesY && y < guiFilesY + 36
}

func guiFilesUpContains(_ x: Int, _ y: Int) -> Bool {
    x >= filesRailX() && x < filesRailX() + 28
        && y >= filesListTop() && y < filesListTop() + 28
}

func guiFilesDownContains(_ x: Int, _ y: Int) -> Bool {
    x >= filesRailX() && x < filesRailX() + 28
        && y >= filesStatusTop() - 36
        && y < filesStatusTop() - 8
}

/// The list's own ground: the rows' field, from the list's
/// head to its foot, clear of the rail at its right.
func guiFilesListContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiFilesX + 8 && x < guiFilesX + guiFilesW - 48
        && y >= filesListTop()
        && y < filesListTop() + filesVisibleRows() * filesRowHeight
}

/// The entry a list press at this height lands on, or -1
/// when the press stands below the disc's last entry.
func filesRowAt(_ y: Int) -> Int {
    let slot = (y - filesListTop()) / filesRowHeight
    let entry = filesScroll + slot
    return entry < filesCount ? entry : -1
}

/// Paints the Files window's maximize box, as the Terminal's
/// is painted: one square at rest, two while maximized.
func guiPaintFilesMaxBox() {
    let boxX = guiMaxBoxX(guiFilesX, guiFilesW)
    let boxY = guiFilesY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if filesMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Files window's title strip alone, in the
/// colour of its standing, with its name and both its boxes —
/// the whole-window painter lays its strip through this same
/// hand, as its siblings' painters do.
func guiPaintFilesTitleBar(_ held: Bool) {
    guiFillRect(guiFilesX, guiFilesY, guiFilesW, 36,
                held ? guiHeldBarColor
                    : (guiFocusFiles ? guiCardinalColor
                                     : guiDimBarColor))
    guiDrawText(guiFilesX + 16, guiFilesY + 10, 2, guiFilesTitle,
                guiWhiteColor)
    guiPaintFilesMaxBox()
    guiPaintXBox(guiCloseBoxX(guiFilesX, guiFilesW),
                 guiFilesY + guiBoxTop)
}

/// Paints one entry's mark, in a 24 x 24 field: honest
/// rectangles and nothing borrowed, a mark per kind — a
/// folder in gold and parchment, a page with its folded
/// corner and its written lines, a program's cardinal square
/// carrying a gold play-triangle, a feather's quill in gold
/// on a cardinal stem, and a grey chip for the files that
/// are Cardnull itself.
func guiPaintFileIcon(_ ix: Int, _ iy: Int, _ kind: Int) {
    if kind == filesKindFolder {
        guiFillRect(ix + 2, iy + 5, 20, 15, guiGoldColor)
        guiFillRect(ix + 2, iy + 2, 9, 4, guiGoldColor)
        guiFillRect(ix + 2, iy + 10, 20, 10, guiButtonColor)
        guiFillRect(ix + 2, iy + 10, 20, 2, guiBorderColor)
    } else if kind == filesKindText {
        guiFillRect(ix + 4, iy + 1, 16, 22, guiWhiteColor)
        guiFillRect(ix + 4, iy + 1, 16, 2, guiBorderColor)
        guiFillRect(ix + 4, iy + 21, 16, 2, guiBorderColor)
        guiFillRect(ix + 4, iy + 1, 2, 22, guiBorderColor)
        guiFillRect(ix + 18, iy + 1, 2, 22, guiBorderColor)
        guiFillRect(ix + 15, iy + 1, 5, 5, guiCardinalColor)
        guiFillRect(ix + 7, iy + 9, 10, 2, guiInkColor)
        guiFillRect(ix + 7, iy + 13, 10, 2, guiInkColor)
        guiFillRect(ix + 7, iy + 17, 6, 2, guiInkColor)
    } else if kind == filesKindProgram {
        guiFillRect(ix + 2, iy + 2, 20, 20, guiCardinalColor)
        var row = 0
        while row < 10 {
            let width = row < 5 ? row + 1 : 10 - row
            guiFillRect(ix + 9, iy + 7 + row, width, 1,
                        guiGoldColor)
            row += 1
        }
    } else if kind == filesKindFeather {
        var row = 0
        while row < 16 {
            let width = row < 8 ? 2 + row : 2 + (15 - row)
            guiFillRect(ix + 12 - width / 2, iy + 3 + row,
                        width, 1, guiGoldColor)
            row += 1
        }
        guiFillRect(ix + 11, iy + 3, 2, 18, guiCardinalColor)
    } else {
        guiFillRect(ix + 3, iy + 3, 18, 18, 0x8A8A8A)
        guiFillRect(ix + 8, iy + 8, 8, 8, guiInkColor)
        var pin = 0
        while pin < 3 {
            guiFillRect(ix + 5 + pin * 6, iy + 1, 2, 2, 0x8A8A8A)
            guiFillRect(ix + 5 + pin * 6, iy + 21, 2, 2, 0x8A8A8A)
            guiFillRect(ix + 1, iy + 5 + pin * 6, 2, 2, 0x8A8A8A)
            guiFillRect(ix + 21, iy + 5 + pin * 6, 2, 2, 0x8A8A8A)
            pin += 1
        }
    }
}

/// Paints the Files window whole: shadow, parchment body and
/// border, the title strip, the list as it stands scrolled —
/// the chosen entry wearing the pressed-button tan the
/// Welcome card's button wears held — the scroll rail, and
/// the status strip with its sentence. The scroll is first
/// clamped home inside the window's present shape, as the
/// Terminal's marks are clamped at a resize: a maximize may
/// have made the standing scroll a lie, and the painter
/// does not paint lies.
func guiPaintFilesWindow() {
    let maxScroll = max(0, filesCount - filesVisibleRows())
    if filesScroll > maxScroll { filesScroll = maxScroll }
    if filesScroll < 0 { filesScroll = 0 }
    guiFillRect(guiFilesX + 10, guiFilesY + 12, guiFilesW,
                guiFilesH, guiShadowColor)
    guiFillRect(guiFilesX, guiFilesY, guiFilesW, guiFilesH,
                guiParchmentColor)
    guiFillRect(guiFilesX, guiFilesY, guiFilesW, 2, guiBorderColor)
    guiFillRect(guiFilesX, guiFilesY + guiFilesH - 2, guiFilesW,
                2, guiBorderColor)
    guiFillRect(guiFilesX, guiFilesY, 2, guiFilesH, guiBorderColor)
    guiFillRect(guiFilesX + guiFilesW - 2, guiFilesY, 2,
                guiFilesH, guiBorderColor)
    guiPaintFilesTitleBar(false)
    guiFillRect(guiFilesX + 2, filesStatusTop(), guiFilesW - 4,
                2, guiBorderColor)
    let base = cardnullFilesKeeping()
    if filesCount == 0 {
        // Nothing to list: the status's words stand in the
        // body, where the eye looks for the list.
        guiPaintStatusLines(guiFilesX + 12, filesListTop() + 4)
    }
    var slot = 0
    while slot < filesVisibleRows() {
        let entry = filesScroll + slot
        if entry >= filesCount { break }
        let rowY = filesListTop() + slot * filesRowHeight
        if entry == filesSelected {
            guiFillRect(guiFilesX + 8, rowY, guiFilesW - 56,
                        filesRowHeight, guiPressedColor)
        }
        guiPaintFileIcon(guiFilesX + 12, rowY + 4,
                         filesEntryKind(entry))
        guiDrawBytes(guiFilesX + 48, rowY + 8, 2, base,
                     entry * filesEntryStride,
                     filesEntryNameLength(entry), guiInkColor)
        if filesEntryKind(entry) == filesKindFolder {
            let wordX = guiFilesX + guiFilesW - 56
                - guiTextGlyphs(filesFolderWord) * 16
            guiDrawText(wordX, rowY + 8, 2, filesFolderWord,
                        guiInkColor)
        } else {
            guiDrawSizeRight(guiFilesX + guiFilesW - 56,
                             rowY + 8, filesEntrySize(entry))
        }
        slot += 1
    }
    guiPaintScrollButton(filesRailX(), filesListTop(), true,
                         filesScroll > 0)
    guiPaintScrollButton(filesRailX(), filesStatusTop() - 36,
                         false, filesScroll < maxScroll)
    if filesCount > 0 {
        guiPaintStatusLines(guiFilesX + 12, filesStatusTop() + 8)
    }
}

/// Scrolls the list by whole lines — a step from a button or
/// an arrow key, a windowful from a page key — clamped at
/// both ends of the disc's truth, and repainted where it
/// stands. A scroll that cannot move paints nothing.
func filesScrollBy(_ lines: Int) {
    let maxScroll = max(0, filesCount - filesVisibleRows())
    let target = min(max(filesScroll + lines, 0), maxScroll)
    if target == filesScroll { return }
    filesScroll = target
    pointerHide()
    guiPaintFilesWindow()
    pointerShow()
}

/// The Files window's maximize and restore, one control,
/// down the Terminal's own road: the whole work area, or its
/// own place back, the list's reckoning following its shape.
func guiToggleFilesMaximize() {
    if filesMaximized {
        guiFilesX = filesSavedX
        guiFilesY = filesSavedY
        guiFilesW = filesSavedW
        guiFilesH = filesSavedH
        filesMaximized = false
    } else {
        filesSavedX = guiFilesX
        filesSavedY = guiFilesY
        filesSavedW = guiFilesW
        filesSavedH = guiFilesH
        guiFilesX = 0
        guiFilesY = guiWorkTop
        guiFilesW = framebufferWidth
        guiFilesH = guiBarTop() - guiWorkTop
        filesMaximized = true
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Files window: the disc's list is read afresh —
/// the opening is the refresh, as the section's head states —
/// the window stands at its first page with nothing chosen,
/// and takes the room.
func guiOpenFiles() {
    filesReadRootList()
    filesOpen = true
    filesScroll = 0
    filesSelected = -1
    filesPressArmed = false
    guiSetFocusFiles()
    pointerHide()
    guiPaintFilesWindow()
    pointerShow()
}

// ---------------------------------------------------------------------------
// The Reader window: a text file, open as a page. Its text
// stands in the keeping (the file's first readerTextCap
// bytes, read off the disc by the Reader's opening); its
// layout is a walk over those bytes, reckoned fresh at every
// painting from the window's present width, so a maximize
// re-wraps the page the way a resize re-wraps any honest
// page. The wrapping keeps `cat`'s manners, because the two
// are the same file wearing two faces: line feeds end lines,
// carriage returns are let go, a tab steps to a plain space,
// and any other byte the screen cannot honestly draw is
// passed over — occupying no column, in the reckoning or in
// the painting, so the two never disagree. Within a line of
// the file, the wrapping breaks at the last space that fits,
// as words are wrapped everywhere; a word longer than the
// page's whole width is broken where it stands, there being
// no space to break at.
// ---------------------------------------------------------------------------

func readerTextX() -> Int { guiReaderX + 16 }
func readerTextTop() -> Int { guiReaderY + 52 }
func readerRailX() -> Int { guiReaderX + guiReaderW - 40 }
func readerBottom() -> Int { guiReaderY + guiReaderH - 16 }

/// The page's width in letters: the window's width less its
/// margins and the scroll rail, at twofold letters.
func readerCols() -> Int {
    max(8, (guiReaderW - 64) / 16)
}

/// The page's height in lines, as the window stands.
func readerVisibleRows() -> Int {
    max(1, (readerBottom() - readerTextTop()) / 16)
}

func guiReaderContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiReaderX && x < guiReaderX + guiReaderW
        && y >= guiReaderY && y < guiReaderY + guiReaderH
}

func guiReaderCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiReaderX, guiReaderW)
        && x < guiCloseBoxX(guiReaderX, guiReaderW) + guiBoxW
        && y >= guiReaderY + guiBoxTop
        && y < guiReaderY + guiBoxTop + guiBoxH
}

func guiReaderMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiReaderX, guiReaderW)
        && x < guiMaxBoxX(guiReaderX, guiReaderW) + guiBoxW
        && y >= guiReaderY + guiBoxTop
        && y < guiReaderY + guiBoxTop + guiBoxH
}

func guiReaderTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiReaderX && x < guiReaderX + guiReaderW
        && y >= guiReaderY && y < guiReaderY + 36
}

func guiReaderUpContains(_ x: Int, _ y: Int) -> Bool {
    x >= readerRailX() && x < readerRailX() + 28
        && y >= readerTextTop() && y < readerTextTop() + 28
}

func guiReaderDownContains(_ x: Int, _ y: Int) -> Bool {
    x >= readerRailX() && x < readerRailX() + 28
        && y >= readerBottom() - 28 && y < readerBottom()
}

/// One display line's span, from the byte where it begins:
/// the byte one past its last drawn letter, and the byte
/// where the next line begins (-1 when the text is spent).
/// The reckoning walks the file's own line first (to its
/// line feed or the text's end), wrapping it at the page's
/// width with the break at the last space that fit — or,
/// there being none, a hard break at the width. Bytes the
/// page cannot draw are passed over without a column, the
/// tab alone stepping in as a space: `cat`'s manners, kept.
func readerLineSpan(_ pos: Int, _ cols: Int) -> (end: Int,
                                                 next: Int) {
    let base = cardnullFilesKeeping()
    var index = pos
    var col = 0
    var breakEnd = -1      // the last space's place, if broken there
    var breakNext = -1     // and the byte after it
    while index < readerTextLength {
        let byte = base[readerTextOffset + index]
        if byte == 0x0A {
            return (index, index + 1)
        }
        if byte == 0x0D || (byte < 0x20 && byte != 0x09)
            || byte == 0x7F {
            index += 1            // let go: no column, not drawn
            continue
        }
        if col == cols {
            if breakNext > pos { return (breakEnd, breakNext) }
            return (index, index)
        }
        col += 1
        index += 1
        if byte == 0x20 || byte == 0x09 {
            breakEnd = index - 1
            breakNext = index
        }
    }
    return (index, -1)
}

/// The page's whole count of display lines, walked end to
/// end — the number every Reader scroll is clamped by,
/// together with the closing note's line when the file goes
/// on past the keeping.
func readerCountLines() -> Int {
    if readerTextLength == 0 { return 0 }
    let cols = readerCols()
    var count = 0
    var pos = 0
    while pos < readerTextLength {
        let span = readerLineSpan(pos, cols)
        count += 1
        if span.next < 0 { break }
        pos = span.next
    }
    return count
}

func readerTotalLines() -> Int {
    readerCountLines() + (readerTruncated ? 1 : 0)
}

/// Paints the Reader's page: the wrapped lines as they stand
/// scrolled, walked from the text's head each time — the
/// text is a few thousand bytes, and a fresh honest walk
/// beats a kept index that a resize could make a liar. The
/// closing note stands as the page's last line when the file
/// goes on past the keeping.
func guiPaintReaderBody() {
    let base = cardnullFilesKeeping()
    let cols = readerCols()
    let rows = readerVisibleRows()
    let wrapped = readerCountLines()
    var pos = 0
    var line = 0
    while line < readerScroll && pos < readerTextLength {
        let span = readerLineSpan(pos, cols)
        if span.next < 0 {
            pos = readerTextLength
            break
        }
        pos = span.next
        line += 1
    }
    var row = 0
    while row < rows {
        let y = readerTextTop() + row * 16
        if line < wrapped {
            let span = readerLineSpan(pos, cols)
            var col = 0
            var index = pos
            while index < span.end {
                let byte = base[readerTextOffset + index]
                if byte == 0x0D || (byte < 0x20 && byte != 0x09)
                    || byte == 0x7F {
                    index += 1
                    continue
                }
                let glyph: UInt8 = byte == 0x09 ? 0x20 : byte
                guiDrawGlyph(readerTextX() + col * 16, y, 2,
                             glyph, guiInkColor)
                col += 1
                index += 1
            }
            if span.next < 0 { break }
            pos = span.next
        } else if readerTruncated && line == wrapped {
            guiDrawText(readerTextX(), y, 2, readerTruncatedLine,
                        0x6B5636)
        } else {
            break
        }
        line += 1
        row += 1
    }
}

/// Paints the Reader's maximize box, as its siblings'.
func guiPaintReaderMaxBox() {
    let boxX = guiMaxBoxX(guiReaderX, guiReaderW)
    let boxY = guiReaderY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if readerMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Reader's title strip alone: its name is the
/// file's, read out of the keeping — the one title on the
/// desktop that is not a standing word — with both its boxes.
func guiPaintReaderTitleBar(_ held: Bool) {
    guiFillRect(guiReaderX, guiReaderY, guiReaderW, 36,
                held ? guiHeldBarColor
                    : (guiFocusReader ? guiCardinalColor
                                      : guiDimBarColor))
    guiDrawBytes(guiReaderX + 16, guiReaderY + 10, 2,
                 cardnullFilesKeeping(), readerNameOffset,
                 readerNameLength, guiWhiteColor)
    guiPaintReaderMaxBox()
    guiPaintXBox(guiCloseBoxX(guiReaderX, guiReaderW),
                 guiReaderY + guiBoxTop)
}

/// Paints the Reader window whole: shadow, parchment body
/// and border — a page's colours, as the Welcome card wears —
/// its title strip, its wrapped page, and its scroll rail.
func guiPaintReaderWindow() {
    let maxScroll = max(0, readerTotalLines()
                        - readerVisibleRows())
    if readerScroll > maxScroll { readerScroll = maxScroll }
    if readerScroll < 0 { readerScroll = 0 }
    guiFillRect(guiReaderX + 10, guiReaderY + 12, guiReaderW,
                guiReaderH, guiShadowColor)
    guiFillRect(guiReaderX, guiReaderY, guiReaderW, guiReaderH,
                guiParchmentColor)
    guiFillRect(guiReaderX, guiReaderY, guiReaderW, 2,
                guiBorderColor)
    guiFillRect(guiReaderX, guiReaderY + guiReaderH - 2,
                guiReaderW, 2, guiBorderColor)
    guiFillRect(guiReaderX, guiReaderY, 2, guiReaderH,
                guiBorderColor)
    guiFillRect(guiReaderX + guiReaderW - 2, guiReaderY, 2,
                guiReaderH, guiBorderColor)
    guiPaintReaderTitleBar(false)
    guiPaintReaderBody()
    guiPaintScrollButton(readerRailX(), readerTextTop(), true,
                         readerScroll > 0)
    guiPaintScrollButton(readerRailX(), readerBottom() - 28,
                         false, readerScroll < maxScroll)
}

/// Paints the feather window's title strip alone, in the
/// colour of its standing: its name is the feather's own,
/// read out of the card's keeping the session holds open —
/// the Reader's road, a title that is not a standing word.
/// The name is cut at the room the strip leaves it, short
/// of the close box: furniture never crunches (the desktop
/// design law), and a long name is shortened, never spilt.
func guiPaintFeatherTitleBar(_ held: Bool) {
    guiFillRect(guiFeatherX, guiFeatherY, guiFeatherW, 36,
                held ? guiHeldBarColor
                    : (guiFocusFeather ? guiCardinalColor
                                       : guiDimBarColor))
    if let base = featherWinTitleBase {
        let room = (guiFeatherW - 8 - guiBoxW - 16) / (8 * 2)
        let count = min(featherWinTitleLength, max(room, 0))
        guiDrawBytes(guiFeatherX + 16, guiFeatherY + 10, 2,
                     base, featherWinTitleStart, count,
                     guiWhiteColor)
    }
    guiPaintXBox(guiCloseBoxX(guiFeatherX, guiFeatherW),
                 guiFeatherY + guiBoxTop)
}

/// Paints the feather window whole (milestone 25): shadow,
/// body and border, the title strip, and the canvas laid
/// with its ground — the Terminal's own dark earth, the
/// ground a face expects before it paints. Laying the
/// ground IS the kernel's invalidation of the guest's
/// canvas, so this painter sets the repaint owing: the
/// guest's next service-9 ask hears that its face is owed
/// and paints it whole again. A whole paint happens when
/// the window opens, when the room changes hands, or when
/// it is set down from a drag — exactly the moments the
/// canvas must be owed.
func guiPaintFeatherWindow() {
    guiFillRect(guiFeatherX + 10, guiFeatherY + 12, guiFeatherW,
                guiFeatherH, guiShadowColor)
    guiFillRect(guiFeatherX, guiFeatherY, guiFeatherW,
                guiFeatherH, guiParchmentColor)
    guiFillRect(guiFeatherX, guiFeatherY, guiFeatherW, 2,
                guiBorderColor)
    guiFillRect(guiFeatherX, guiFeatherY + guiFeatherH - 2,
                guiFeatherW, 2, guiBorderColor)
    guiFillRect(guiFeatherX, guiFeatherY, 2, guiFeatherH,
                guiBorderColor)
    guiFillRect(guiFeatherX + guiFeatherW - 2, guiFeatherY, 2,
                guiFeatherH, guiBorderColor)
    guiPaintFeatherTitleBar(false)
    guiFillRect(guestCanvasOriginX(), guestCanvasOriginY(),
                guiFeatherW - 4, guiFeatherH - 2 - 36,
                guiTermBgColor)
    guestRepaintOwed = true
}

/// Scrolls the page by whole lines, clamped and repainted,
/// down filesScrollBy's road.
func readerScrollBy(_ lines: Int) {
    let maxScroll = max(0, readerTotalLines()
                        - readerVisibleRows())
    let target = min(max(readerScroll + lines, 0), maxScroll)
    if target == readerScroll { return }
    readerScroll = target
    pointerHide()
    guiPaintReaderWindow()
    pointerShow()
}

/// The Reader's maximize and restore, one control, down the
/// Terminal's own road — the page re-wraps at its new width
/// because the layout is a walk, not a keeping.
func guiToggleReaderMaximize() {
    if readerMaximized {
        guiReaderX = readerSavedX
        guiReaderY = readerSavedY
        guiReaderW = readerSavedW
        guiReaderH = readerSavedH
        readerMaximized = false
    } else {
        readerSavedX = guiReaderX
        readerSavedY = guiReaderY
        readerSavedW = guiReaderW
        readerSavedH = guiReaderH
        guiReaderX = 0
        guiReaderY = guiWorkTop
        guiReaderW = framebufferWidth
        guiReaderH = guiBarTop() - guiWorkTop
        readerMaximized = true
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Reader on one entry: its name is kept, and its
/// bytes are read off the disc sector by sector — `cat`'s
/// own reading, into the keeping instead of onto the screen —
/// to the keeping's bound, the going-on marked when the file
/// is longer. A read the drive refuses opens nothing: the
/// Files window's status line carries the disc's answer, and
/// the desktop stands as it stood.
func guiOpenReader(_ entry: Int) {
    let base = cardnullFilesKeeping()
    let nameLength = filesEntryNameLength(entry)
    var index = 0
    while index < nameLength && index < readerNameCap {
        base[readerNameOffset + index]
            = base[entry * filesEntryStride + index]
        index += 1
    }
    readerNameLength = index
    let size = filesEntrySize(entry)
    let extent = filesEntryExtent(entry)
    let wanted = size < UInt32(readerTextCap)
        ? size : UInt32(readerTextCap)
    readerTruncated = size > wanted
    let buffer = discBuffer()
    var read: UInt32 = 0
    var sectorIndex: UInt32 = 0
    while read < wanted {
        // The entry's extent field holds a disc sector when
        // the disc serves and a bundle offset when the bundle
        // does (milestone 23); the serving layer reads it by
        // whichever source is serving.
        if !serveReadChunk(bundleValid, extent, extent, size,
                           sectorIndex) {
            filesSetStatus(discReadErrorLine)
            pointerHide()
            guiPaintFilesWindow()
            pointerShow()
            return
        }
        var count = wanted - read
        if count > UInt32(discSectorBytes) {
            count = UInt32(discSectorBytes)
        }
        var step = 0
        while step < Int(count) {
            base[readerTextOffset + Int(read) + step]
                = buffer[step]
            step += 1
        }
        read += count
        sectorIndex += 1
    }
    readerTextLength = Int(wanted)
    readerScroll = 0
    readerOpen = true
    guiSetFocusReader()
    pointerHide()
    guiPaintReaderWindow()
    pointerShow()
}

