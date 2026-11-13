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
// Milestone 31: the Write window, and the door learns files.
//
// The desktop gains a sixth window, and the service door
// gains two services, and the two halves of the stone are
// one thought: Cardnull's files can now be *made* on the
// desktop, not only read there — and a feather can keep a
// small file of its own on the Cardnull disk and read it
// back, by the same road the editor walks.
//
// The Write window (window 6) stands where the Reader
// stands in the house's affections: a document window. It
// is called up from its own launcher in the bottom bar — a
// fourth now, between Files and Welcome, reckoned by the
// bar's own budget, the gaps giving before the furniture
// ever does — or by a new shell command, `write`, which
// walks the `files` command's own road (in the Terminal the
// window opens where the conversation stands; at the text
// console the face opens with the window standing on it).
// It drags by its title bar under the same outline and the
// same clamp, maximizes and restores by its box and by a
// title double-click, closes by its box alone, takes the
// room by guiRoomHolder's reckoning — the feather's 5 above
// it, as the feather stands above every elder — and scrolls
// by the wheel, three lines to a notch over whichever face
// it is wearing. Its title bar is the house measure, 36;
// beneath it a strip of 40 carries its furniture: in its
// typing face, the buttons New, Open and Save, drawn as
// the bar's buttons are drawn, and the document's standing
// in plain words beside them — its name when it has one,
// "New writing" when it has none, and " - saved" or
// " - not saved" by its dirtiness; a message from the
// window's own work, when one stands, replaces that
// standing until the next keypress or button press, which
// is the message's whole life. The buttons act on the
// press, as every piece of furniture in this house acts —
// the Files window's scroll buttons and list, the Welcome
// card's button, all of them answer the press, and the
// Write window keeps the house's manners.
//
// The words themselves are kept as plain bytes in a
// keeping the floor lends (cardnullWriteKeeping, 16,384
// bytes): the text at its head, up to 8,192 bytes — one
// page, honestly bounded, and a fuller page refuses more
// with its own message and changes nothing; the Open
// list's entries after it, up to forty-eight in the Files
// entries' own shape; the name being typed after them; and
// the strip's message after that. Enter lays a line feed,
// Backspace rubs out the byte before the caret, Delete the
// byte at it, and the printable keys arrive by the shell's
// own table — ascii(forScancode:) — with Shift and Caps
// Lock kept exactly as handleScancode keeps them, so the
// faces of the letters are the faces the whole house
// types. The caret walks by byte left and right, crossing
// lines as bytes do, and by display line up and down,
// keeping its column as the wrapped spans allow; Home and
// End take it to its display line's ends, and the page keys
// move a windowful. The display lines are the Reader's own
// wrapping — break at the last space that fits, cut plainly
// where there is none — reckoned by writeLineSpan over the
// text keeping, the Reader's reckoning kept a second time
// rather than shared, because the Reader's page and this
// page are two keepings and two lengths, and a shared hand
// would have to be told whose it was holding at every call.
// The caret is a cardinal block at its cell, laid under its
// glyph, which is then drawn over it in the paper colour —
// the bench can find it by its colour alone.
//
// Three faces (writeMode): 0, typing — the page and its
// caret; 1, the Open list — the disk's entries, names left
// and sizes in plain words right, one click choosing and
// opening on the same press (a single click opens in this
// list: the Files window's double-click law is for
// launching programs, and this list only opens text into
// the editor); 2, the naming — no buttons, the strip
// asking "Name your writing:" and the name growing beneath
// the asking with its caret block. Esc keeps the house law
// with the window's own exceptions: in the naming it sets
// the saving aside and returns to typing; in the Open list
// it returns to typing; in typing it asks for the way home,
// as Esc does everywhere on this face.
//
// Closing the window loses nothing: the document in
// progress stands in the keeping, and reopening the window
// finds it exactly as it was left — words are not lost by
// closing a window. Opening a file onto a document with
// unsaved words is refused with its own message, and New
// over unsaved words asks twice, the second press being
// the setting aside — no road out of this window loses a
// word silently; that is the grandma law, and it is kept.
//
// The disk road beneath both halves is one new hand,
// hdCreateFile, standing beside runDsave rather than
// inside it: runDsave's printed behaviour is the M30
// family's standing word and is not touched, so the flow
// is walked twice in the tree, honestly, the way the house
// has kept twins before. hdCreateFile judges the name by
// the family's rules, raises the disk and reads its state
// fresh, stages the sought name in the path scratch — the
// shell's line scratch, idle in both contexts this hand is
// called from: the face's loop, where no command runs
// while the Write window holds the room, and the door,
// where the shell stands blocked inside a launch — scans
// the directory for the name, and writes in the format's
// order: the data's sectors first, then the directory's
// entry, then the superblock, then the flush. Its answers
// are small numbers the callers translate: 0 written, 1 no
// ready disk (a writing the disk refused answers here too
// — the disk did not stand to the writing, and no finer
// word is honest), 2 the name taken, 3 no room — no free
// slot, or no data room — 4 a name this house cannot keep.
//
// The editor's Save walks three roads. A named document
// whose new length fits its standing run is written back
// into that same run, its entry remade with the new
// length, the superblock rewritten with the same count and
// the same next free sector — the file keeps its ground. A
// named document that has outgrown its run is refused with
// its own message and its slot forgotten, so the next Save
// press treats it as unnamed and asks for a name: the words
// are never at risk, only the place is. An unnamed document
// goes to the naming, whose confirming is hdCreateFile with
// the name as typed — the disk stores it as typed, as dls
// shows names as stored, and dcat folds case for the
// meeting as it always has. A Save pressed with no ready
// disk answers "No Cardnull disk yet. Your words are still
// here." and changes nothing — not even the naming is
// entered.
//
// The door's two new services are flat, answered for pair
// and windowed guests alike — the file road does not care
// about the face:
//   10 read a file — rsi the name's address, rdx its
//      length, rcx the destination's address, r8 the room
//      there. The name's reach is proven against the estate
//      before a byte of it is read, exactly service 1's
//      discipline; the name is judged by the family's rules;
//      the disk is judged fresh; the file's length, known
//      only once the directory is read, governs the
//      destination's proof, which is made for exactly the
//      file's length before the file's sector is read into
//      the disk's field and copied out. The answer is the
//      byte count. A file longer than 512 bytes — one disk
//      sector, the keeping's honest size, stated as such —
//      or longer than the room offered is refused whole,
//      nothing copied.
//   11 write a file — rsi the name, rdx its length, rcx the
//      source, r8 the byte count, 0 to 512. Both reaches
//      are proven before a byte is read, and the writing is
//      hdCreateFile's own: a fresh file, under a name that
//      does not stand. There is no overwrite anywhere in
//      this format, and the door makes none; and there is
//      no signature — the directory's checksum-proven
//      superblock is the disk's integrity, as it has been
//      since milestone 21, and a feather's file is a file
//      like any other, nothing holier claimed for it.
// The answers wear the door's all-ones family: all-ones
// itself for a bad reach or a bad name; one less for no
// ready disk; two less for a name not found (service 10)
// or already standing (service 11); three less for a file
// too long for the bound or the room (service 10); four
// less for no room (service 11).
//
// The windows take no frames and no heap: the keeping is
// the floor's lending, and the disk hands work in the disk
// driver's own fields, taken at its raising as they have
// been since milestone 21 — so `mem` reads the same after
// a visit as before it, the kernel's grown image aside, as
// every milestone confesses.
// ---------------------------------------------------------------------------

/// Provided by the boot floor (support.c): the Write
/// window's keeping — 16,384 bytes the floor lends for the
/// text being written, the Open list gathered off the hard
/// disk, the name being typed, and the strip's message. The
/// layout is the kernel's business, in the constants below;
/// the floor only keeps the memory, as with every keeping
/// before it.
@_silgen_name("cardnull_write_keeping")
func cardnullWriteKeeping() -> UnsafeMutablePointer<UInt8>

/// The Write keeping's shape, agreed with the floor's
/// lending: the text at its head, the Open list's entries
/// after it in the Files entries' own shape (a name's
/// letters, their length at +32, the size at +36, a stride
/// of 48), the name-entry field after the list, and the
/// strip's message after that; the rest is slack the
/// keeping does not pretend to use.
let writeKeepingBytes = 16384
let writeTextOffset = 0
let writeTextCap = 8192
let writeListOffset = 8192          // writeTextOffset + writeTextCap
let writeListMaxEntries = 48
let writeListStride = 48
let writeNameOffset = 10496         // writeListOffset + 48 * stride
let writeNameCap = 40
let writeMessageOffset = 10536      // writeNameOffset + writeNameCap
let writeMessageCap = 96

/// The Write window's place and shape, reckoned in runGui
/// beside the Reader's: as large as a page wants to be,
/// standing off-centre over the Terminal.
var guiWriteX = 0
var guiWriteY = 0
var guiWriteW = 0
var guiWriteH = 0

/// Whether the Write window stands, and whether it holds
/// the room.
var writeOpen = false
var guiFocusWrite = false

/// The Write window's maximize bookkeeping, as its
/// siblings': whether it stands maximized, and the place
/// restore returns it to.
var writeMaximized = false
var writeSavedX = 0
var writeSavedY = 0
var writeSavedW = 0
var writeSavedH = 0

/// The window's word, standing in its title bar and on its
/// bar launcher, as the other windows' words stand.
let guiWriteTitle: StaticString = "Write"

/// The `write` command's word to the face, as the `files`
/// command's stands: set when the command is answered at
/// the text console, taken and cleared by runGui at its
/// door.
var writeWantedAtFace = false

/// The document's books, all of them over the keeping:
/// how many bytes of text stand in it, where the caret
/// stands among them (a byte offset), and the first
/// display line the window shows.
var writeLength = 0
var writeCursor = 0
var writeViewTop = 0

/// The document's name: its length, its bytes standing in
/// the keeping's name field — bytes, not a String, as every
/// name in this house is bytes — and whether the document
/// has a name at all. writeSlot is the directory slot the
/// document's file stands in, found at its opening or its
/// last saving (-1 when no standing file is this
/// document's), and writeStart that file's first sector.
var writeNameLength = 0
var writeHasName = false
var writeSlot = -1
var writeStart: UInt32 = 0

/// Whether the document's words differ from what stands on
/// the disk under its name — or, unnamed, whether they
/// differ from nothing at all.
var writeDirty = false

/// The window's face: 0 the typing, 1 the Open list, 2 the
/// naming.
var writeMode = 0

/// New's confirmation arming: a first press over unsaved
/// words speaks and arms; the second press, while the
/// arming stands, sets the words aside. Any keypress, and
/// any other button, puts the arming down.
var writeNewArmed = false

/// The Open list's books: how many entries the keeping
/// holds, which of them the hand last chose, the first of
/// them the window shows, and whether the disk held more
/// than the list can carry — the keeping's candour, spoken
/// in the strip when it stands.
var writeListCount = 0
var writeListSelected = -1
var writeListScroll = 0
var writeListTruncated = false

/// The strip message's length, in the keeping. The message
/// stands in place of the document's standing in the strip
/// until the next keypress or button press clears it.
var writeMessageLength = 0

/// The title bar's double-click pairing, kept as its
/// siblings' are.
var writeTitlePressTick: UInt64 = 0
var writeTitlePressArmed = false

/// The window's vocabulary: its buttons, its strip's
/// standing words, and every message its work can speak —
/// each in plain words, as the desktop speaks everywhere.
let writeNewLabel: StaticString = "New"
let writeOpenLabel: StaticString = "Open"
let writeSaveLabel: StaticString = "Save"
let writeBackLabel: StaticString = "Back"
let writeUntitledWord: StaticString = "New writing"
let writeSavedSuffix: StaticString = " - saved"
let writeNotSavedSuffix: StaticString = " - not saved"
let writeChooseLine: StaticString = "Choose a file to open"
let writeFirst48Line: StaticString = "The first 48 files"
let writeNamePrompt: StaticString = "Name your writing:"
let writeEmptyDiskLine: StaticString = "No files on the disk yet."
let writeNoDiskLine: StaticString = "No Cardnull disk yet."
let writeNoDiskWordsLine: StaticString =
    "No Cardnull disk yet. Your words are still here."
let writeNoRoomLine: StaticString =
    "The disk has no room. Your words are still here."
let writeTakenLine: StaticString =
    "A file with that name already stands. Choose another name."
let writeBadNameLine: StaticString =
    "Names use letters, numbers, dots, dashes and underscores."
let writeFullLine: StaticString =
    "This page is full. Save it and start a new one."
let writeOutgrownLine: StaticString =
    "This writing has outgrown its place. Save it under a new name."
let writeSavedLine: StaticString = "Saved."
let writeSaveFirstLine: StaticString =
    "Save this writing first, or press New to set it aside."
let writeNewAgainLine: StaticString =
    "Your words are not saved. Press New again to set them aside."
let writeNewWritingLine: StaticString = "New writing."
let writeLongerLine: StaticString =
    "This file is longer than one page here. Its first part is open."
let writeSetAsideLine: StaticString = "Saving set aside."
let writeRefusedLine: StaticString =
    "The disk refused a writing. Your words are still here."
let writeUnreadLine: StaticString =
    "The disk did not answer. Your words are still here."
let writeGoneLine: StaticString = "That file is not on the disk now."

/// The keeping, as the one pointer every Write hand shares.
@inline(__always)
func writeBase() -> UnsafeMutablePointer<UInt8> {
    cardnullWriteKeeping()
}

/// The name field, as a pointer — a name being typed, and a
/// document's standing name, both live here.
@inline(__always)
func writeNameBase() -> UnsafeMutablePointer<UInt8> {
    cardnullWriteKeeping() + writeNameOffset
}

// ---------------------------------------------------------------------------
// The strip's message: bytes in the keeping, set from a
// standing sentence's words, cleared by the next keypress
// or button press — the Files status line's own discipline,
// kept for a shorter sentence.
// ---------------------------------------------------------------------------

func writeClearMessage() {
    writeMessageLength = 0
}

func writeSetMessage(_ text: StaticString) {
    let base = writeBase()
    var pen = 0
    while text.utf8Start[pen] != 0 && pen < writeMessageCap {
        base[writeMessageOffset + pen] = text.utf8Start[pen]
        pen += 1
    }
    writeMessageLength = pen
}

/// Sets the message to the saving's account: "Saved as "
/// and the name as typed, and a full stop — the disk stores
/// the name as typed, and the message speaks it as typed.
func writeSetMessageSavedAs() {
    let base = writeBase()
    let head: StaticString = "Saved as "
    var pen = 0
    while head.utf8Start[pen] != 0 {
        base[writeMessageOffset + pen] = head.utf8Start[pen]
        pen += 1
    }
    var index = 0
    while index < writeNameLength
        && pen < writeMessageCap - 1 {
        base[writeMessageOffset + pen]
            = base[writeNameOffset + index]
        pen += 1
        index += 1
    }
    base[writeMessageOffset + pen] = 0x2E   // '.'
    pen += 1
    writeMessageLength = pen
}

// ---------------------------------------------------------------------------
// The Open list's reading hands: one entry's facts, by its
// number — the Files entries' own shape, kept a second
// time in this keeping.
// ---------------------------------------------------------------------------

func writeListNameLength(_ entry: Int) -> Int {
    Int(writeBase()[writeListOffset + entry * writeListStride + 32])
}

func writeListSize(_ entry: Int) -> UInt32 {
    let base = writeBase()
    let at = writeListOffset + entry * writeListStride + 36
    return UInt32(base[at]) | UInt32(base[at + 1]) << 8
        | UInt32(base[at + 2]) << 16 | UInt32(base[at + 3]) << 24
}

// ---------------------------------------------------------------------------
// The window's geometry, every part reckoned from its own
// rect like its siblings': the title strip across the head
// (36, the house measure); the strip of 40 beneath it; and
// the text's field from there to the window's foot less 8,
// its letters at twofold size from an inset of 12.
// ---------------------------------------------------------------------------

func writeStripY() -> Int { guiWriteY + 36 }
func writeTextX() -> Int { guiWriteX + 12 }
func writeTextTop() -> Int { guiWriteY + 36 + 40 }
func writeTextBottom() -> Int { guiWriteY + guiWriteH - 8 }

/// The page's width in letters, at twofold size.
func writeCols() -> Int {
    max(8, (guiWriteW - 24) / 16)
}

/// The page's height in display lines, as the window
/// stands.
func writeVisibleRows() -> Int {
    max(1, (writeTextBottom() - writeTextTop()) / 16)
}

/// The Open list's height in rows, at the Files list's own
/// row measure.
func writeVisibleListRows() -> Int {
    max(1, (writeTextBottom() - writeTextTop()) / filesRowHeight)
}

/// The strip buttons' places: New at the strip's left, Open
/// and Save following, each its label's own width — the
/// bar's buttons' reckoning — 28 tall at the strip's y + 6,
/// 12 apart from the window's inset.
func writeNewBtnX() -> Int { guiWriteX + 12 }
func writeNewBtnW() -> Int { guiBarButtonWidth(writeNewLabel) }
func writeOpenBtnX() -> Int {
    writeNewBtnX() + writeNewBtnW() + 12
}
func writeOpenBtnW() -> Int { guiBarButtonWidth(writeOpenLabel) }
func writeSaveBtnX() -> Int {
    writeOpenBtnX() + writeOpenBtnW() + 12
}
func writeSaveBtnW() -> Int { guiBarButtonWidth(writeSaveLabel) }
func writeBackBtnW() -> Int { guiBarButtonWidth(writeBackLabel) }
func writeStripBtnY() -> Int { writeStripY() + 6 }

func writeStripBtnContains(_ bx: Int, _ bw: Int,
                           _ x: Int, _ y: Int) -> Bool {
    x >= bx && x < bx + bw
        && y >= writeStripBtnY() && y < writeStripBtnY() + 28
}

func guiWriteContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWriteX && x < guiWriteX + guiWriteW
        && y >= guiWriteY && y < guiWriteY + guiWriteH
}

func guiWriteCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiWriteX, guiWriteW)
        && x < guiCloseBoxX(guiWriteX, guiWriteW) + guiBoxW
        && y >= guiWriteY + guiBoxTop
        && y < guiWriteY + guiBoxTop + guiBoxH
}

func guiWriteMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiWriteX, guiWriteW)
        && x < guiMaxBoxX(guiWriteX, guiWriteW) + guiBoxW
        && y >= guiWriteY + guiBoxTop
        && y < guiWriteY + guiBoxTop + guiBoxH
}

func guiWriteTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWriteX && x < guiWriteX + guiWriteW
        && y >= guiWriteY && y < guiWriteY + 36
}

/// The text field's own ground, clear of the strip and the
/// window's foot.
func writeTextContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWriteX + 12 && x < guiWriteX + guiWriteW - 12
        && y >= writeTextTop() && y < writeTextBottom()
}

/// The Open list's own ground: the visible rows' field.
func writeListContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWriteX + 12 && x < guiWriteX + guiWriteW - 12
        && y >= writeTextTop()
        && y < writeTextTop()
            + writeVisibleListRows() * filesRowHeight
}

/// The entry a list press at this height lands on, or -1
/// when the press stands below the list's last entry.
func writeListRowAt(_ y: Int) -> Int {
    let slot = (y - writeTextTop()) / filesRowHeight
    let entry = writeListScroll + slot
    return entry < writeListCount ? entry : -1
}

// ---------------------------------------------------------------------------
// The text's reckoning: display lines over the text
// keeping, walked fresh at every asking — the Reader's own
// wrapping (readerLineSpan's rule), kept a second time for
// a second keeping: line feeds end lines; carriage returns
// and the other undrawable bytes are passed over without a
// column; a tab steps in as a space; within a line, the
// break is at the last space that fits, or a plain cut
// where there is none.
// ---------------------------------------------------------------------------

/// Whether a byte of the text takes a column on the page.
func writeByteDrawable(_ byte: UInt8) -> Bool {
    byte == 0x09 || (byte >= 0x20 && byte != 0x7F)
}

/// One display line's span, from the byte where it begins:
/// the byte one past its last drawn letter, and the byte
/// where the next line begins (-1 when the text is spent).
func writeLineSpan(_ pos: Int, _ cols: Int) -> (end: Int,
                                                next: Int) {
    if pos >= writeLength { return (writeLength, -1) }
    let base = writeBase()
    var index = pos
    var col = 0
    var breakEnd = -1
    var breakNext = -1
    while index < writeLength {
        let byte = base[writeTextOffset + index]
        if byte == 0x0A {
            return (index, index + 1)
        }
        if !writeByteDrawable(byte) {
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

/// The page's whole count of display lines. An empty page
/// is one line — the line the caret stands on — and a page
/// ending in a line feed has its last, empty line counted:
/// the caret stands there, and the count must have room
/// for it.
func writeDisplayLineCount() -> Int {
    if writeLength == 0 { return 1 }
    let cols = writeCols()
    var count = 0
    var pos = 0
    while pos < writeLength {
        let span = writeLineSpan(pos, cols)
        count += 1
        if span.next < 0 { break }
        pos = span.next
    }
    if writeBase()[writeTextOffset + writeLength - 1] == 0x0A {
        count += 1
    }
    return count
}

/// The byte where a display line begins, walked from the
/// text's head — the text is a few thousand bytes, and a
/// fresh honest walk beats a kept index, as the Reader's
/// painter found before this one.
func writeLineStartPos(_ line: Int) -> Int {
    let cols = writeCols()
    var pos = 0
    var walked = 0
    while walked < line && pos < writeLength {
        let span = writeLineSpan(pos, cols)
        if span.next < 0 { return writeLength }
        pos = span.next
        walked += 1
    }
    return pos
}

/// The caret's place on the page: its display line, and
/// its column within that line — the column the up and
/// down walks keep, and the cell the block caret is laid
/// on. A caret at a line's first byte after a line feed
/// belongs to the line the feed began, not the one it
/// ended: the walk asks whether the caret stands before
/// the next line's start, and a caret standing exactly at
/// it has already crossed.
func writeCursorDisplay() -> (line: Int, col: Int) {
    let cols = writeCols()
    var pos = 0
    var line = 0
    while true {
        let span = writeLineSpan(pos, cols)
        if span.next < 0 || writeCursor < span.next {
            var col = 0
            var index = pos
            while index < writeCursor && index < span.end {
                if writeByteDrawable(
                    writeBase()[writeTextOffset + index]) {
                    col += 1
                }
                index += 1
            }
            return (line, col)
        }
        pos = span.next
        line += 1
    }
}

/// The byte a display place names: the line's start,
/// advanced by whole drawn columns, stopping at the line's
/// end — a press beyond a short line's end lands on its
/// end, which is where the hand meant to be.
func writeByteAtDisplay(_ line: Int, _ colWanted: Int) -> Int {
    let total = writeDisplayLineCount()
    let target = min(max(line, 0), total - 1)
    let pos = writeLineStartPos(target)
    let span = writeLineSpan(pos, writeCols())
    let base = writeBase()
    var col = 0
    var index = pos
    while index < span.end && col < colWanted {
        let byte = base[writeTextOffset + index]
        index += 1
        if writeByteDrawable(byte) { col += 1 }
    }
    return index
}

/// Brings the view to the caret: after any key, the
/// caret's display line stands within the window's rows,
/// and the view itself stands within the page's reckoning.
func writeEnsureCursorVisible() {
    let place = writeCursorDisplay()
    let rows = writeVisibleRows()
    if place.line < writeViewTop { writeViewTop = place.line }
    if place.line >= writeViewTop + rows {
        writeViewTop = place.line - rows + 1
    }
    let maxTop = max(0, writeDisplayLineCount() - rows)
    if writeViewTop > maxTop { writeViewTop = maxTop }
    if writeViewTop < 0 { writeViewTop = 0 }
}

/// Repaints the window where it stands, in the pointer's
/// hidden moment — the face's own courtesy, as its
/// siblings' scroll hands observe it.
func writeRepaint() {
    pointerHide()
    guiPaintWriteWindow()
    pointerShow()
}

/// Scrolls the page by whole lines, clamped at both ends
/// of the text's reckoning, and repainted where it stands.
/// A scroll that cannot move paints nothing.
func writeScrollBy(_ lines: Int) {
    let maxTop = max(0, writeDisplayLineCount()
                     - writeVisibleRows())
    let target = min(max(writeViewTop + lines, 0), maxTop)
    if target == writeViewTop { return }
    writeViewTop = target
    writeRepaint()
}

/// Scrolls the Open list by whole lines, down the same
/// road.
func writeListScrollBy(_ lines: Int) {
    let maxScroll = max(0, writeListCount
                        - writeVisibleListRows())
    let target = min(max(writeListScroll + lines, 0), maxScroll)
    if target == writeListScroll { return }
    writeListScroll = target
    writeRepaint()
}

/// Moves the Open list's choosing by whole entries,
/// clamped, the chosen entry kept within the window's
/// rows — the keyboard's parity with the press.
func writeListMove(_ delta: Int) {
    if writeListCount == 0 { return }
    var target = writeListSelected + delta
    if target < 0 { target = 0 }
    if target > writeListCount - 1 {
        target = writeListCount - 1
    }
    writeListSelected = target
    if target < writeListScroll { writeListScroll = target }
    let rows = writeVisibleListRows()
    if target >= writeListScroll + rows {
        writeListScroll = target - rows + 1
    }
}

// ---------------------------------------------------------------------------
// The painters.
// ---------------------------------------------------------------------------

/// Paints the Write window's maximize box, as its
/// siblings' are painted: one square at rest, two while
/// maximized.
func guiPaintWriteMaxBox() {
    let boxX = guiMaxBoxX(guiWriteX, guiWriteW)
    let boxY = guiWriteY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if writeMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Write window's title strip alone, in the
/// colour of its standing, with its name and both its
/// boxes — the whole-window painter lays its strip through
/// this same hand, as its siblings' painters do.
func guiPaintWriteTitleBar(_ held: Bool) {
    guiFillRect(guiWriteX, guiWriteY, guiWriteW, 36,
                held ? guiHeldBarColor
                    : (guiFocusWrite ? guiCardinalColor
                                     : guiDimBarColor))
    guiDrawText(guiWriteX + 16, guiWriteY + 10, 2, guiWriteTitle,
                guiWhiteColor)
    guiPaintWriteMaxBox()
    guiPaintXBox(guiCloseBoxX(guiWriteX, guiWriteW),
                 guiWriteY + guiBoxTop)
}

/// Paints one of the strip's buttons: the bar button's own
/// face — its ground and border, its label centred — at
/// the strip's place rather than the bar's.
func guiPaintWriteButton(_ bx: Int, _ by: Int, _ w: Int,
                         _ label: StaticString) {
    guiFillRect(bx, by, w, 28, guiButtonColor)
    guiFillRect(bx, by, w, 2, guiBorderColor)
    guiFillRect(bx, by + 26, w, 2, guiBorderColor)
    guiFillRect(bx, by, 2, 28, guiBorderColor)
    guiFillRect(bx + w - 2, by, 2, 28, guiBorderColor)
    let labelW = guiTextGlyphs(label) * 16
    guiDrawText(bx + (w - labelW) / 2, by + 6, 2, label,
                guiInkColor)
}

/// Paints the strip's message at a place, wrapped by words
/// over at most the lines it is given — guiPaintStatusLines'
/// own walk, kept for this keeping's message: a word that
/// cannot stand whole on a fresh line is drawn to the
/// line's end and the message rests there.
func writePaintMessageLines(_ x: Int, _ y: Int, _ cols: Int,
                            _ maxLines: Int) {
    let base = writeBase()
    var line = 0
    var col = 0
    var index = 0
    while index < writeMessageLength && line < maxLines {
        let byte = base[writeMessageOffset + index]
        if byte == 0x20 {
            index += 1
            if col > 0 { col += 1 }
            continue
        }
        var wordLength = 0
        while index + wordLength < writeMessageLength
            && base[writeMessageOffset + index + wordLength]
                != 0x20 {
            wordLength += 1
        }
        if col + wordLength > cols && col > 0 {
            line += 1
            col = 0
            if line >= maxLines { return }
            continue
        }
        var step = 0
        while step < wordLength && col < cols {
            guiDrawGlyph(x + col * 16, y + line * 18, 2,
                         base[writeMessageOffset + index + step],
                         guiInkColor)
            col += 1
            step += 1
        }
        index += wordLength
    }
}

/// Paints the strip: its ground laid fresh over the
/// window's parchment with its divider at its foot, then
/// its face by the window's mode — the typing face's three
/// buttons and the document's standing (or the message
/// standing in its place); the Open face's Back button and
/// its choosing words; the naming face's asking, the name
/// growing beneath it — its tail shown when it outgrows
/// its line, so the caret's neighbourhood is always the
/// part in view — with the caret block after it, and the
/// message, when one stands, on the line beneath.
func guiPaintWriteStrip() {
    let stripY = writeStripY()
    guiFillRect(guiWriteX + 2, stripY, guiWriteW - 4, 40,
                guiParchmentColor)
    guiFillRect(guiWriteX + 2, stripY + 38, guiWriteW - 4, 2,
                guiBorderColor)
    if writeMode == 0 {
        guiPaintWriteButton(writeNewBtnX(), writeStripBtnY(),
                            writeNewBtnW(), writeNewLabel)
        guiPaintWriteButton(writeOpenBtnX(), writeStripBtnY(),
                            writeOpenBtnW(), writeOpenLabel)
        guiPaintWriteButton(writeSaveBtnX(), writeStripBtnY(),
                            writeSaveBtnW(), writeSaveLabel)
        let standingX = writeSaveBtnX() + writeSaveBtnW() + 16
        if writeMessageLength > 0 {
            let cols = (guiWriteX + guiWriteW - 12 - standingX)
                / 16
            writePaintMessageLines(standingX, stripY + 4,
                                   max(cols, 1), 2)
        } else {
            let suffix = writeDirty ? writeNotSavedSuffix
                                    : writeSavedSuffix
            let suffixGlyphs = guiTextGlyphs(suffix)
            if writeHasName {
                let room = (guiWriteX + guiWriteW - 12
                            - standingX) / 16 - suffixGlyphs
                let shown = min(writeNameLength, max(room, 0))
                let after = guiDrawBytes(
                    standingX, stripY + 12, 2, writeBase(),
                    writeNameOffset, shown, guiInkColor)
                guiDrawText(after, stripY + 12, 2, suffix,
                            guiInkColor)
            } else {
                let after = guiDrawText(standingX, stripY + 12,
                                        2, writeUntitledWord,
                                        guiInkColor)
                guiDrawText(after, stripY + 12, 2, suffix,
                            guiInkColor)
            }
        }
    } else if writeMode == 1 {
        guiPaintWriteButton(writeNewBtnX(), writeStripBtnY(),
                            writeBackBtnW(), writeBackLabel)
        let wordsX = writeNewBtnX() + writeBackBtnW() + 16
        if writeMessageLength > 0 {
            let cols = (guiWriteX + guiWriteW - 12 - wordsX) / 16
            writePaintMessageLines(wordsX, stripY + 4,
                                   max(cols, 1), 2)
        } else {
            guiDrawText(wordsX, stripY + 12, 2,
                        writeListTruncated ? writeFirst48Line
                                           : writeChooseLine,
                        guiInkColor)
        }
    } else {
        guiDrawText(guiWriteX + 12, stripY + 4, 2,
                    writeNamePrompt, guiInkColor)
        if writeMessageLength > 0 {
            let cols = (guiWriteW - 24) / 16
            writePaintMessageLines(guiWriteX + 12, stripY + 22,
                                   max(cols, 1), 1)
        } else {
            // The name, on the prompt's own line beneath the
            // asking: its tail, when it is longer than the
            // line holds, and the caret block after it.
            let room = (guiWriteW - 24) / 16 - 1
            let shown = min(writeNameLength, max(room, 0))
            let start = writeNameLength - shown
            let after = guiDrawBytes(
                guiWriteX + 12, stripY + 22, 2, writeBase(),
                writeNameOffset + start, shown, guiInkColor)
            guiFillRect(after, stripY + 22, 16, 16,
                        guiCardinalColor)
        }
    }
}

/// Paints the page: the display lines as they stand
/// scrolled, walked from the text's head each time, and
/// the caret — a cardinal block at its cell, laid first,
/// its glyph drawn over it in the paper colour when the
/// cell holds one.
func guiPaintWriteText() {
    let base = writeBase()
    let cols = writeCols()
    let rows = writeVisibleRows()
    let top = writeTextTop()
    let textX = writeTextX()
    let total = writeDisplayLineCount()
    let caret = writeCursorDisplay()
    var pos = 0
    var line = 0
    while line < writeViewTop && pos < writeLength {
        let span = writeLineSpan(pos, cols)
        if span.next < 0 {
            pos = writeLength
            break
        }
        pos = span.next
        line += 1
    }
    var row = 0
    while row < rows {
        if line >= total { break }
        let y = top + row * 16
        let span = writeLineSpan(pos, cols)
        if line == caret.line {
            guiFillRect(textX + caret.col * 16, y, 16, 16,
                        guiCardinalColor)
        }
        var col = 0
        var index = pos
        while index < span.end {
            let byte = base[writeTextOffset + index]
            if !writeByteDrawable(byte) {
                index += 1
                continue
            }
            let glyph: UInt8 = byte == 0x09 ? 0x20 : byte
            let colour = (line == caret.line && col == caret.col)
                ? guiParchmentColor : guiInkColor
            guiDrawGlyph(textX + col * 16, y, 2, glyph, colour)
            col += 1
            index += 1
        }
        if span.next < 0 { break }
        pos = span.next
        line += 1
        row += 1
    }
}

/// Paints the Open list: the gathered entries as they
/// stand scrolled — the chosen one wearing the
/// pressed-button tan the Files list's chosen wears — a
/// name at the left and its size in plain words at the
/// right, down guiDrawSizeRight's road. An empty gathering
/// speaks its emptiness in the body, where the eye looks
/// for the list.
func guiPaintWriteList() {
    let base = writeBase()
    if writeListCount == 0 {
        guiDrawText(writeTextX(), writeTextTop() + 4, 2,
                    writeEmptyDiskLine, guiInkColor)
        return
    }
    var slot = 0
    while slot < writeVisibleListRows() {
        let entry = writeListScroll + slot
        if entry >= writeListCount { break }
        let rowY = writeTextTop() + slot * filesRowHeight
        if entry == writeListSelected {
            guiFillRect(guiWriteX + 8, rowY, guiWriteW - 16,
                        filesRowHeight, guiPressedColor)
        }
        guiDrawBytes(writeTextX(), rowY + 8, 2, base,
                     writeListOffset + entry * writeListStride,
                     writeListNameLength(entry), guiInkColor)
        guiDrawSizeRight(guiWriteX + guiWriteW - 16, rowY + 8,
                         writeListSize(entry))
        slot += 1
    }
}

/// Paints the Write window whole: shadow, parchment body
/// and border, the title strip, the furniture strip, and
/// the face the mode is wearing — the page, or the Open
/// list. The view and the list's scroll are first clamped
/// home inside the window's present shape, as its
/// siblings' painters clamp theirs.
func guiPaintWriteWindow() {
    let maxTop = max(0, writeDisplayLineCount()
                     - writeVisibleRows())
    if writeViewTop > maxTop { writeViewTop = maxTop }
    if writeViewTop < 0 { writeViewTop = 0 }
    let maxList = max(0, writeListCount - writeVisibleListRows())
    if writeListScroll > maxList { writeListScroll = maxList }
    if writeListScroll < 0 { writeListScroll = 0 }
    guiFillRect(guiWriteX + 10, guiWriteY + 12, guiWriteW,
                guiWriteH, guiShadowColor)
    guiFillRect(guiWriteX, guiWriteY, guiWriteW, guiWriteH,
                guiParchmentColor)
    guiFillRect(guiWriteX, guiWriteY, guiWriteW, 2, guiBorderColor)
    guiFillRect(guiWriteX, guiWriteY + guiWriteH - 2, guiWriteW,
                2, guiBorderColor)
    guiFillRect(guiWriteX, guiWriteY, 2, guiWriteH, guiBorderColor)
    guiFillRect(guiWriteX + guiWriteW - 2, guiWriteY, 2,
                guiWriteH, guiBorderColor)
    guiPaintWriteTitleBar(false)
    guiPaintWriteStrip()
    if writeMode == 1 {
        guiPaintWriteList()
    } else {
        guiPaintWriteText()
    }
}

/// Gives the room to the Write window: the whole desktop
/// is repainted in the new standing, as guiSetFocusFiles
/// repaints it for its window.
func guiSetFocusWrite() {
    if guiFocusWrite && !guiFocusTerminal && !guiFocusFiles
        && !guiFocusReader && !guiFocusBible {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = true
    guiFocusBible = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// The Write window's maximize and restore, one control,
/// down its siblings' own road: the whole work area, or
/// its own place back — the page re-wraps at its new width
/// because its layout is a walk, and the view is brought
/// to the caret at the change.
func guiToggleWriteMaximize() {
    if writeMaximized {
        guiWriteX = writeSavedX
        guiWriteY = writeSavedY
        guiWriteW = writeSavedW
        guiWriteH = writeSavedH
        writeMaximized = false
    } else {
        writeSavedX = guiWriteX
        writeSavedY = guiWriteY
        writeSavedW = guiWriteW
        writeSavedH = guiWriteH
        guiWriteX = 0
        guiWriteY = guiWorkTop
        guiWriteW = framebufferWidth
        guiWriteH = guiBarTop() - guiWorkTop
        writeMaximized = true
    }
    writeEnsureCursorVisible()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Write window: it stands and takes the room.
/// The document in the keeping is the document — a first
/// opening finds it empty and untitled, and reopening a
/// closed window finds the writing in progress exactly as
/// it was left, because closing the window never touches
/// the words.
func guiOpenWrite() {
    if writeOpen {
        guiSetFocusWrite()
        return
    }
    writeOpen = true
    guiSetFocusWrite()
    pointerHide()
    guiPaintWriteWindow()
    pointerShow()
}

// ---------------------------------------------------------------------------
// The disk road, shared by the editor and the door:
// hdCreateFile — a new file on the Cardnull disk, standing
// beside runDsave (whose printed behaviour is the family's
// standing word and is not touched), walking the same road
// runDsave walks: the name judged, the disk raised and
// read fresh, the name sought in the directory, the data
// written, the entry written, the superblock written last,
// the flush. The duplication is deliberate and stated in
// the section's head: it is safer than bending the
// Terminal's witness to fit two callers.
// ---------------------------------------------------------------------------

/// Writes a new file to the Cardnull disk: the name stands
/// in the caller's field at (nameStart, nameLength), the
/// bytes in the caller's field for dataLength of them —
/// either caller's field may be any field its road can
/// read (the editor's keeping, a guest's estate), and the
/// bytes are carried sector by sector through the disk's
/// own field, so neither source is ever the field the
/// directory is read into. Answers: 0 written; 1 no ready
/// disk — the disk absent, not Cardnull's, silent, or a
/// writing refused along the way; 2 the name already
/// stands; 3 no room — no free directory slot, or no data
/// room for the file's run; 4 the name is not one this
/// house can keep.
func hdCreateFile(_ nameFrom: UnsafeMutablePointer<UInt8>,
                  _ nameStart: Int, _ nameLength: Int,
                  _ dataFrom: UnsafeMutablePointer<UInt8>,
                  _ dataLength: Int) -> Int {
    if !hdNameCanStand(nameFrom, nameStart, nameLength) {
        return 4
    }
    hdRaise()
    if !hdFound { return 1 }
    if hdReadState() != hdStateReady { return 1 }
    // Stage the sought name in the path scratch, as
    // runDsave stages it: the scratch's standing users are
    // the shell's commands, and no command runs in either
    // calling context (the face's loop with the Write
    // window holding the room; the door with the shell
    // blocked in a launch).
    let path = discPath()
    var index = 0
    while index < nameLength {
        path[index] = nameFrom[nameStart + index]
        index += 1
    }
    if !hdScanDirectory(0, nameLength) { return 1 }
    if hdFoundSlot >= 0 { return 2 }
    if hdFreeSlot < 0 { return 3 }
    let sectors = (dataLength + hdSectorBytes - 1) / hdSectorBytes
    if hdSbNextFree + UInt64(sectors) > hdSbTotal { return 3 }
    let start = hdSbNextFree
    let slot = hdFreeSlot
    let count = hdEntryCount
    var sectorIndex = 0
    while sectorIndex < sectors {
        let buffer = hdData()
        var step = 0
        while step < hdSectorBytes {
            buffer[step] = 0
            step += 1
        }
        let chunkStart = sectorIndex * hdSectorBytes
        var take = dataLength - chunkStart
        if take > hdSectorBytes { take = hdSectorBytes }
        step = 0
        while step < take {
            buffer[step] = dataFrom[chunkStart + step]
            step += 1
        }
        if !hdWriteSector(start + UInt64(sectorIndex)) {
            return 1
        }
        sectorIndex += 1
    }
    if !hdWriteEntry(slot, UnsafePointer(nameFrom), nameStart,
                     nameLength, UInt32(start),
                     UInt32(dataLength)) {
        return 1
    }
    if !hdWriteSuperblock(UInt32(count + 1),
                          start + UInt64(sectors)) {
        return 1
    }
    _ = hdFlush()
    return 0
}

/// Stages the document's standing name — the keeping's
/// name field — into the path scratch, for a directory
/// scan by it.
func writeStageNameForScan() {
    let path = discPath()
    let base = writeBase()
    var index = 0
    while index < writeNameLength {
        path[index] = base[writeNameOffset + index]
        index += 1
    }
}

// ---------------------------------------------------------------------------
// The editor's disk work: Save's three roads, the naming's
// confirming, the Open list's gathering, and a chosen
// file's loading.
// ---------------------------------------------------------------------------

/// Writes the document back into its standing run: its
/// sectors in the run's own place, its entry remade with
/// the new length at its slot, the superblock rewritten
/// with the standing count and the standing next free
/// sector — the file keeps its ground, nothing else on
/// the disk moves. The caller has judged the fit already.
func writeSaveInPlace() -> Bool {
    let base = writeBase()
    let sectors = (writeLength + hdSectorBytes - 1) / hdSectorBytes
    var sectorIndex = 0
    while sectorIndex < sectors {
        let buffer = hdData()
        var step = 0
        while step < hdSectorBytes {
            buffer[step] = 0
            step += 1
        }
        let chunkStart = sectorIndex * hdSectorBytes
        var take = writeLength - chunkStart
        if take > hdSectorBytes { take = hdSectorBytes }
        step = 0
        while step < take {
            buffer[step] = base[writeTextOffset + chunkStart + step]
            step += 1
        }
        if !hdWriteSector(UInt64(writeStart)
                          + UInt64(sectorIndex)) {
            return false
        }
        sectorIndex += 1
    }
    if !hdWriteEntry(writeSlot, UnsafePointer(base),
                     writeNameOffset, writeNameLength,
                     writeStart, UInt32(writeLength)) {
        return false
    }
    if !hdWriteSuperblock(UInt32(hdEntryCount), hdSbNextFree) {
        return false
    }
    _ = hdFlush()
    return true
}

/// The Save button's work, by the section head's three
/// roads: back into the standing run when the writing
/// still fits it; the outgrown message and a forgotten
/// slot when it does not, so the next Save asks for a
/// name; and the naming for a document with no standing
/// place. With no ready disk, the words are kept and the
/// naming is not even entered.
func writeSaveDocument() {
    hdRaise()
    if !hdFound {
        writeSetMessage(writeNoDiskWordsLine)
        return
    }
    if hdReadState() != hdStateReady {
        writeSetMessage(writeNoDiskWordsLine)
        return
    }
    if writeHasName && writeSlot >= 0 {
        writeStageNameForScan()
        if hdScanDirectory(0, writeNameLength)
            && hdFoundSlot == writeSlot {
            let sectorsNeeded = (writeLength + hdSectorBytes - 1)
                / hdSectorBytes
            let standingSectors = (Int(hdFoundLength)
                                   + hdSectorBytes - 1)
                / hdSectorBytes
            if sectorsNeeded <= standingSectors {
                if writeSaveInPlace() {
                    writeDirty = false
                    writeSetMessage(writeSavedLine)
                } else {
                    writeSetMessage(writeRefusedLine)
                }
                return
            }
            // Outgrown: the words are kept whole, the slot
            // is forgotten, and the next Save press will
            // ask for a name.
            writeSetMessage(writeOutgrownLine)
            writeSlot = -1
            writeStart = 0
            return
        }
        // The name no longer stands in this document's
        // slot — the file was renamed or taken away by
        // another road. The writing is treated as unnamed
        // from here, and asks for its name below.
        writeSlot = -1
        writeStart = 0
    }
    // Unnamed, or standing in no slot: the naming. A
    // document that carries a name still (it outgrew its
    // place on an earlier press) keeps the name in the
    // field, to be edited or confirmed as it stands.
    if !writeHasName { writeNameLength = 0 }
    writeClearMessage()
    writeMode = 2
}

/// The naming's confirming: Enter pressed with a name
/// typed. The name is judged by the family's rules and
/// given to hdCreateFile with the document's bytes — the
/// text stands at the keeping's head, offset 0, so the
/// one pointer serves both fields, the name read from its
/// own offset within it. Each of the road's answers is
/// spoken in the strip, and the window stays where the
/// answer leaves the work: in the naming, when another
/// name is the whole of what is wanted.
func writeConfirmName() {
    let base = writeBase()
    if !hdNameCanStand(base, writeNameOffset, writeNameLength) {
        writeSetMessage(writeBadNameLine)
        return
    }
    let result = hdCreateFile(base, writeNameOffset,
                              writeNameLength, base, writeLength)
    if result == 0 {
        writeHasName = true
        writeDirty = false
        writeMode = 0
        // The new file's slot and start, found by asking
        // the directory for the name just written.
        writeStageNameForScan()
        if hdScanDirectory(0, writeNameLength)
            && hdFoundSlot >= 0 {
            writeSlot = hdFoundSlot
            writeStart = hdFoundStart
        } else {
            writeSlot = -1
            writeStart = 0
        }
        writeSetMessageSavedAs()
    } else if result == 2 {
        writeSetMessage(writeTakenLine)
    } else if result == 3 {
        writeMode = 0
        writeSetMessage(writeNoRoomLine)
    } else if result == 4 {
        writeSetMessage(writeBadNameLine)
    } else {
        writeMode = 0
        writeSetMessage(writeNoDiskWordsLine)
    }
}

/// Gathers the hard disk's standing entries into the
/// keeping's list: the directory walked sector by sector
/// as runDls walks it, free slots passed over, each used
/// entry's name and length and size kept — the first
/// forty-eight, with the gathering's bound confessed in
/// writeListTruncated when the disk holds more. False
/// when there is no ready disk to gather from.
func writeGatherList() -> Bool {
    hdRaise()
    if !hdFound { return false }
    if hdReadState() != hdStateReady { return false }
    let base = writeBase()
    writeListCount = 0
    writeListTruncated = false
    var dirSector: UInt64 = 0
    while dirSector < hdDirSectors {
        if !hdReadSector(hdDirStart + dirSector) { return false }
        let buffer = hdData()
        var inSector = 0
        while inSector < Int(hdSectorBytes) / hdEntryBytes {
            let entryBase = inSector * hdEntryBytes
            if buffer[entryBase] != 0 {
                if writeListCount < writeListMaxEntries {
                    var length = 0
                    while length < 32
                        && buffer[entryBase + 1 + length] != 0 {
                        length += 1
                    }
                    let copy = min(length, filesEntryNameCap)
                    let at = writeListOffset
                        + writeListCount * writeListStride
                    var index = 0
                    while index < copy {
                        base[at + index]
                            = buffer[entryBase + 1 + index]
                        index += 1
                    }
                    base[at + 32] = UInt8(copy)
                    let size = discU32(buffer, entryBase + 36)
                    base[at + 36] = UInt8(size & 0xFF)
                    base[at + 37] = UInt8((size >> 8) & 0xFF)
                    base[at + 38] = UInt8((size >> 16) & 0xFF)
                    base[at + 39] = UInt8((size >> 24) & 0xFF)
                    writeListCount += 1
                } else {
                    writeListTruncated = true
                }
            }
            inSector += 1
        }
        dirSector += 1
    }
    return true
}

/// The Open button's work: the disk judged, its list
/// gathered, and the window turned to its choosing face —
/// or, with no ready disk, the plain word and no turning.
func writeOpenList() {
    if !writeGatherList() {
        writeSetMessage(writeNoDiskLine)
        return
    }
    writeMode = 1
    writeListSelected = writeListCount > 0 ? 0 : -1
    writeListScroll = 0
    writeClearMessage()
}

/// Opens one gathered entry into the editor: the file
/// found again by its name — the dopen road, the
/// directory's own scan — and read sector by sector into
/// the text keeping, to the keeping's bound, the going-on
/// confessed in the strip when the file is longer. A
/// document with unsaved words is never replaced: the
/// asking is answered in the strip, and nothing is read.
func writeOpenEntry(_ entry: Int) {
    if entry < 0 || entry >= writeListCount { return }
    if writeDirty {
        writeSetMessage(writeSaveFirstLine)
        return
    }
    let base = writeBase()
    let nameLength = writeListNameLength(entry)
    hdRaise()
    if !hdFound {
        writeSetMessage(writeNoDiskLine)
        return
    }
    if hdReadState() != hdStateReady {
        writeSetMessage(writeNoDiskLine)
        return
    }
    let path = discPath()
    var index = 0
    while index < nameLength {
        path[index] = base[writeListOffset
                           + entry * writeListStride + index]
        index += 1
    }
    if !hdScanDirectory(0, nameLength) {
        writeSetMessage(writeNoDiskLine)
        return
    }
    if hdFoundSlot < 0 {
        writeSetMessage(writeGoneLine)
        return
    }
    let slot = hdFoundSlot
    let start = hdFoundStart
    let fileLength = Int(hdFoundLength)
    let wanted = min(fileLength, writeTextCap)
    var read = 0
    var sectorIndex = 0
    while read < wanted {
        if !hdReadSector(UInt64(start) + UInt64(sectorIndex)) {
            writeSetMessage(writeUnreadLine)
            return
        }
        let buffer = hdData()
        var take = wanted - read
        if take > hdSectorBytes { take = hdSectorBytes }
        var step = 0
        while step < take {
            base[writeTextOffset + read + step] = buffer[step]
            step += 1
        }
        read += take
        sectorIndex += 1
    }
    // The document takes the file's place: its words, its
    // name copied into the name field, its slot and start
    // kept for a later saving into the same run.
    index = 0
    while index < nameLength {
        base[writeNameOffset + index]
            = base[writeListOffset + entry * writeListStride
                   + index]
        index += 1
    }
    writeNameLength = nameLength
    writeLength = wanted
    writeCursor = 0
    writeViewTop = 0
    writeHasName = true
    writeSlot = slot
    writeStart = start
    writeDirty = false
    writeNewArmed = false
    writeMode = 0
    if fileLength > writeTextCap {
        writeSetMessage(writeLongerLine)
    } else {
        writeClearMessage()
    }
}

/// Sets the document aside, whole: an empty, unnamed,
/// unsaved-nothing page, and the strip's word for it.
func writeClearDocument() {
    writeLength = 0
    writeCursor = 0
    writeViewTop = 0
    writeHasName = false
    writeNameLength = 0
    writeSlot = -1
    writeStart = 0
    writeDirty = false
    writeMode = 0
    writeNewArmed = false
    writeSetMessage(writeNewWritingLine)
}

/// The New button's work: at once over a saved document;
/// over unsaved words, the first press speaks and arms,
/// and the second press — while the arming stands — sets
/// the words aside. No press of New ever loses a word
/// without having spoken first.
func writeNewDocument() {
    if writeDirty {
        if writeNewArmed {
            writeClearDocument()
        } else {
            writeNewArmed = true
            writeSetMessage(writeNewAgainLine)
        }
    } else {
        writeClearDocument()
    }
}

// ---------------------------------------------------------------------------
// The keyboard, while the Write window holds the room.
// runGui's loop keeps the 0xE0 prefix in its own e0Pending,
// exactly as it keeps it for the Terminal: the code after
// the prefix comes to writeExtendedKey, and plain codes
// come here.
// ---------------------------------------------------------------------------

/// Lays one byte into the text at the caret, the tail
/// shifted up behind it. At the page's bound the byte is
/// refused with the page's own message, and nothing
/// changes — not the text, not the caret, not the dirt.
func writeInsertByte(_ byte: UInt8) {
    if writeLength >= writeTextCap {
        writeSetMessage(writeFullLine)
        return
    }
    let base = writeBase()
    var index = writeLength
    while index > writeCursor {
        base[writeTextOffset + index]
            = base[writeTextOffset + index - 1]
        index -= 1
    }
    base[writeTextOffset + writeCursor] = byte
    writeLength += 1
    writeCursor += 1
    writeDirty = true
    writeEnsureCursorVisible()
}

/// Rubs out the byte before the caret, the tail shifted
/// down over it.
func writeDeleteBefore() {
    if writeCursor <= 0 { return }
    let base = writeBase()
    var index = writeCursor - 1
    while index < writeLength - 1 {
        base[writeTextOffset + index]
            = base[writeTextOffset + index + 1]
        index += 1
    }
    writeLength -= 1
    writeCursor -= 1
    writeDirty = true
    writeEnsureCursorVisible()
}

/// Rubs out the byte at the caret, the tail shifted down
/// over it.
func writeDeleteAt() {
    if writeCursor >= writeLength { return }
    let base = writeBase()
    var index = writeCursor
    while index < writeLength - 1 {
        base[writeTextOffset + index]
            = base[writeTextOffset + index + 1]
        index += 1
    }
    writeLength -= 1
    writeDirty = true
    writeEnsureCursorVisible()
}

/// Moves the caret by whole display lines, keeping its
/// column as the target line's span allows — the walk the
/// arrow keys and the page keys both come down.
func writeMoveCaretLines(_ delta: Int) {
    let place = writeCursorDisplay()
    let total = writeDisplayLineCount()
    var target = place.line + delta
    if target < 0 { target = 0 }
    if target > total - 1 { target = total - 1 }
    writeCursor = writeByteAtDisplay(target, place.col)
    writeEnsureCursorVisible()
}

/// One plain key, while the Write window holds the room.
/// Shift and Caps Lock are bookkeeping first, exactly as
/// handleScancode keeps them — the same globals, the same
/// faces, ascii(forScancode:) reading them — and every
/// other release is let go. The message's life ends at
/// every true keypress, and New's arming with it. What the
/// key then does is the face's own: typing edits or grows
/// the name; the list lets every plain key but Enter go;
/// the naming hears Enter as its confirming and Esc as
/// its setting aside.
func writeTakeKey(_ code: UInt8) {
    switch code {
    case 0x2A, 0x36:            // Shift pressed
        shiftHeld = true
        return
    case 0xAA, 0xB6:            // Shift released
        shiftHeld = false
        return
    case 0x3A:                  // Caps Lock
        capsLock = !capsLock
        return
    default:
        break
    }
    if code >= 0x80 { return }  // any other release
    writeClearMessage()
    writeNewArmed = false
    if code == 0x01 {           // Esc, by the face wearing it
        if writeMode == 2 {
            writeMode = 0
            writeSetMessage(writeSetAsideLine)
        } else if writeMode == 1 {
            writeMode = 0
        } else {
            guiWantsHome = true
        }
        if !guiWantsHome { writeRepaint() }
        return
    }
    if writeMode == 2 {
        if code == 0x1C {       // Enter: the name stands
            writeConfirmName()
        } else if code == 0x0E {    // Backspace edits it
            if writeNameLength > 0 { writeNameLength -= 1 }
        } else {
            let character = ascii(forScancode: code)
            if character != 0 && writeNameLength < writeNameCap {
                writeBase()[writeNameOffset + writeNameLength]
                    = character
                writeNameLength += 1
            }
        }
    } else if writeMode == 1 {
        if code == 0x1C {       // Enter opens the choosing
            if writeListSelected >= 0 {
                writeOpenEntry(writeListSelected)
            }
        }
    } else {
        if code == 0x1C {       // Enter: a line feed
            writeInsertByte(0x0A)
        } else if code == 0x0E {    // Backspace
            writeDeleteBefore()
        } else {
            let character = ascii(forScancode: code)
            if character != 0 {
                writeInsertByte(character)
            }
        }
    }
    writeRepaint()
}

/// One extended key — the code after the 0xE0 prefix —
/// while the Write window holds the room: the caret's
/// walking keys and Delete on the page; the choosing's
/// walking keys on the list, Enter's parity standing in
/// writeTakeKey; nothing at all in the naming, where the
/// name is typed with plain keys alone.
func writeExtendedKey(_ code: UInt8) {
    writeClearMessage()
    writeNewArmed = false
    if writeMode == 1 {
        if code == 0x48 {              // Up
            writeListMove(-1)
        } else if code == 0x50 {       // Down
            writeListMove(1)
        } else if code == 0x49 {       // Page Up
            writeListMove(-writeVisibleListRows())
        } else if code == 0x51 {       // Page Down
            writeListMove(writeVisibleListRows())
        }
    } else if writeMode == 0 {
        if code == 0x4B {              // Left: one byte
            if writeCursor > 0 { writeCursor -= 1 }
            writeEnsureCursorVisible()
        } else if code == 0x4D {       // Right: one byte
            if writeCursor < writeLength { writeCursor += 1 }
            writeEnsureCursorVisible()
        } else if code == 0x48 {       // Up: a display line
            writeMoveCaretLines(-1)
        } else if code == 0x50 {       // Down
            writeMoveCaretLines(1)
        } else if code == 0x47 {       // Home: the line's start
            let place = writeCursorDisplay()
            writeCursor = writeLineStartPos(place.line)
            writeEnsureCursorVisible()
        } else if code == 0x4F {       // End: the line's end
            let place = writeCursorDisplay()
            let start = writeLineStartPos(place.line)
            let span = writeLineSpan(start, writeCols())
            writeCursor = span.end
            writeEnsureCursorVisible()
        } else if code == 0x49 {       // Page Up: a windowful
            writeMoveCaretLines(-writeVisibleRows())
        } else if code == 0x51 {       // Page Down
            writeMoveCaretLines(writeVisibleRows())
        } else if code == 0x53 {       // Delete: the byte at it
            writeDeleteAt()
        }
    }
    writeRepaint()
}

// ---------------------------------------------------------------------------
// The press, in the window's own seniority, as its
// siblings': its close box closes it alone — the document
// kept whole in the keeping for its reopening, and the
// room falling to the Terminal when the Terminal stands —
// its maximize box trades its size; its title bar takes
// hold for the drag, unless the press is the second of a
// pair, which trades the size instead; its strip buttons
// act on the press, as the house's furniture acts; a
// press on the page in the typing face sets the caret at
// the nearest display place; a press on the Open list
// chooses and opens on the same press; any other press
// gives the window the room. Returns false when the point
// is not the window's at all.
// ---------------------------------------------------------------------------

func guiPressWrite(_ x: Int, _ y: Int) -> Bool {
    if !writeOpen { return false }
    if !guiWriteContains(x, y) { return false }
    if guiWriteCloseContains(x, y) {
        writeOpen = false
        writeTitlePressArmed = false
        if guiFocusWrite {
            guiFocusWrite = false
            guiFocusTerminal = termOpen
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiWriteMaxContains(x, y) {
        guiSetFocusWrite()
        guiToggleWriteMaximize()
        return true
    }
    if guiWriteTitleContains(x, y) {
        guiSetFocusWrite()
        if writeTitlePressArmed
            && ticks &- writeTitlePressTick
                <= guiDoubleClickTicks {
            writeTitlePressArmed = false
            guiToggleWriteMaximize()
            return true
        }
        writeTitlePressArmed = true
        writeTitlePressTick = ticks
        guiBeginDrag(6, x, y)
        return true
    }
    if writeMode == 0 {
        if writeStripBtnContains(writeNewBtnX(), writeNewBtnW(),
                                 x, y) {
            guiSetFocusWrite()
            writeClearMessage()
            writeNewDocument()
            writeRepaint()
            return true
        }
        if writeStripBtnContains(writeOpenBtnX(), writeOpenBtnW(),
                                 x, y) {
            guiSetFocusWrite()
            writeClearMessage()
            writeNewArmed = false
            writeOpenList()
            writeRepaint()
            return true
        }
        if writeStripBtnContains(writeSaveBtnX(), writeSaveBtnW(),
                                 x, y) {
            guiSetFocusWrite()
            writeClearMessage()
            writeNewArmed = false
            writeSaveDocument()
            writeRepaint()
            return true
        }
        if writeTextContains(x, y) {
            guiSetFocusWrite()
            let line = writeViewTop
                + (y - writeTextTop()) / 16
            let col = (x - writeTextX()) / 16
            writeCursor = writeByteAtDisplay(line, col)
            writeEnsureCursorVisible()
            writeRepaint()
            return true
        }
    } else if writeMode == 1 {
        if writeStripBtnContains(writeNewBtnX(), writeBackBtnW(),
                                 x, y) {
            guiSetFocusWrite()
            writeMode = 0
            writeClearMessage()
            writeRepaint()
            return true
        }
        if writeListContains(x, y) {
            guiSetFocusWrite()
            let row = writeListRowAt(y)
            if row >= 0 {
                writeListSelected = row
                writeOpenEntry(row)
            }
            writeRepaint()
            return true
        }
    }
    guiSetFocusWrite()
    return true
}

/// The `write` command's work, down the `files` command's
/// own road: in the Terminal, the window opens where the
/// conversation stands; at the text console, the face
/// opens with the window standing on it.
func runWriteCommand() {
    if consoleInTerminal {
        guiOpenWrite()
    } else {
        writeWantedAtFace = true
        runGui()
    }
}

// ---------------------------------------------------------------------------
// The door's file services (services 10 and 11), answered
// by syscallHandler beside services 1 and 2. Every guest
// span is proven against the estate BEFORE a byte of it
// is read — service 1's estate discipline, spoken once
// here for the two services' four spans.
// ---------------------------------------------------------------------------

/// Whether a guest's reach stands wholly within its
/// estate: the address at or past the estate's base, the
/// length no more than the estate's whole span, and the
/// end not past the estate's top — the arithmetic done in
/// offsets, so no sum is ever trusted to have not wrapped.
func guestSpanStands(_ address: UInt64,
                     _ length: UInt64) -> Bool {
    if address < programBase { return false }
    let offset = address - programBase
    let span = programEstateTop - programBase
    if length > span { return false }
    if offset > span - length { return false }
    return true
}

/// Service 10, read a file: (name address, name length,
/// destination address, destination room) in the first
/// four words. The name is proven, judged by the family's
/// rules, and staged in the path scratch; the disk is
/// judged fresh; the directory is scanned by the name;
/// and only then — the file's length now known — is the
/// destination proven for exactly that length, the file's
/// sector read into the disk's field, and its bytes
/// copied out. The answer is the byte count, or the
/// all-ones family: all-ones for a bad reach or a bad
/// name, one less for no ready disk, two less when the
/// name does not stand, three less when the file is
/// longer than one sector — 512 bytes, the keeping's
/// honest size — or longer than the room offered, the
/// refusal whole and nothing copied either way.
func doorReadFile(_ nameAddress: UInt64, _ nameLength: UInt64,
                  _ destAddress: UInt64, _ destRoom: UInt64)
    -> UInt64 {
    if nameLength < 1 || nameLength > UInt64(hdNameCap) {
        return UInt64.max
    }
    if !guestSpanStands(nameAddress, nameLength) {
        return UInt64.max
    }
    let name = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(nameAddress))!
    if !hdNameCanStand(name, 0, Int(nameLength)) {
        return UInt64.max
    }
    let path = discPath()
    var index = 0
    while index < Int(nameLength) {
        path[index] = name[index]
        index += 1
    }
    hdRaise()
    if !hdFound { return UInt64.max - 1 }
    if hdReadState() != hdStateReady { return UInt64.max - 1 }
    if !hdScanDirectory(0, Int(nameLength)) {
        return UInt64.max - 1
    }
    if hdFoundSlot < 0 { return UInt64.max - 2 }
    let length = UInt64(hdFoundLength)
    if length > 512 || length > destRoom {
        return UInt64.max - 3
    }
    if !guestSpanStands(destAddress, length) {
        return UInt64.max
    }
    if !hdReadSector(UInt64(hdFoundStart)) {
        return UInt64.max - 1
    }
    let destination = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(destAddress))!
    let buffer = hdData()
    index = 0
    while index < Int(length) {
        destination[index] = buffer[index]
        index += 1
    }
    return length
}

/// Service 11, write a file: (name address, name length,
/// source address, byte count) in the first four words,
/// the count no more than 512 — one disk sector, the
/// keeping's honest size. Both reaches are proven before
/// a byte is read, the name judged by the family's rules,
/// and the writing is hdCreateFile's own: a new file
/// under a name that does not stand — no overwrite, no
/// signature, as the section's head states. The answer is
/// 0, or the all-ones family: all-ones for a bad reach, a
/// bad name, or a count past the bound; one less for no
/// ready disk; two less when the name already stands;
/// four less when the disk has no room.
func doorWriteFile(_ nameAddress: UInt64, _ nameLength: UInt64,
                   _ sourceAddress: UInt64, _ count: UInt64)
    -> UInt64 {
    if nameLength < 1 || nameLength > UInt64(hdNameCap) {
        return UInt64.max
    }
    if count > 512 { return UInt64.max }
    if !guestSpanStands(nameAddress, nameLength) {
        return UInt64.max
    }
    if !guestSpanStands(sourceAddress, count) {
        return UInt64.max
    }
    let name = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(nameAddress))!
    let source = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(sourceAddress))!
    if !hdNameCanStand(name, 0, Int(nameLength)) {
        return UInt64.max
    }
    let result = hdCreateFile(name, 0, Int(nameLength),
                              source, Int(count))
    if result == 0 { return 0 }
    if result == 1 { return UInt64.max - 1 }
    if result == 2 { return UInt64.max - 2 }
    if result == 3 { return UInt64.max - 4 }
    return UInt64.max
}

