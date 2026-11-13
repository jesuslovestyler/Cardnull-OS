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
// Milestone 34: the Bible window — the seventh window, and
// the desktop's own book.
//
// The text is the Douay-Rheims Bible (Challoner revision,
// 1899; public domain), the whole of it — all seventy-three
// books in the Catholic order — carried as plain text files
// in the bundle, like every system file: six group files of
// whole books (disc/bible/, authored by
// tools/build-bible-text.py from the Catholic Bible app's
// own data) and one index, BIBLE-IDX.TXT, naming every
// book's place: its group file, and its offset and length
// there. The window reads the text straight out of the
// bundle's span in memory — nothing is copied into a
// keeping — and walks it with the Reader's own line
// reckoning, so a page wraps at the window's width exactly
// as the Reader's pages do.
//
// The window has two standings. At its opening it shows
// the books themselves, one name to a line, in their
// order, with the index's credit line at its foot — "The
// Douay-Rheims Bible (Challoner, 1899)". A press on a name
// opens that book at its head; the title bar then carries
// the book's own name. From a book, the "< All books"
// strip at the page's head — or Escape, which climbs one
// step here before it goes home — returns to the list.
// The window keeps every manner its siblings keep: the
// room by focus, the drag by its title bar, the maximize
// box and the double-click, the wheel and the scroll keys
// at three lines and a page, the rail's two buttons.
//
// The doors in are two, both plain words: the Welcome
// card's "Read the Bible" button, and the Terminal's
// `bible` command. (The bar has no room for a fifth
// launcher beside the clock at the screens this house
// runs — the layout's arithmetic is plain about it — and
// the desktop's law prefers a word that stands whole on
// the greeting card to a button squeezed into the bar.)
//
// If no bundle rode, or the index is not among its files,
// the window still opens and says so in one plain line:
// a Bible window that cannot read its book does not
// pretend to.
// ---------------------------------------------------------------------------

var bibleOpen = false
var guiFocusBible = false
var guiBibleX = 0
var guiBibleY = 0
var guiBibleW = 0
var guiBibleH = 0
var bibleSavedX = 0
var bibleSavedY = 0
var bibleSavedW = 0
var bibleSavedH = 0
var bibleMaximized = false
var bibleTitlePressArmed = false
var bibleTitlePressTick: UInt64 = 0

/// The `bible` command's word for the face, left when the
/// command is typed at the text console.
var bibleWantedAtFace = false

/// The index's standing: parsed or not, and what it yielded.
/// bibleIndexStart is the index payload's place in the
/// bundle's span; the book entries are walked from it fresh
/// at every asking — the index is a few thousand bytes, and
/// a fresh honest walk beats a kept table.
var bibleParsed = false
var bibleBookCount = 0
var bibleIndexStart = 0
var bibleIndexLength = 0
var bibleCreditStart = 0
var bibleCreditLength = 0

/// The reading's standing: which book, and where its text
/// stands in the span.
var bibleReading = false
var bibleBook = -1
var bibleTextStart = 0
var bibleTextLength = 0
var bibleGroupStart = 0

/// The two scrolls, in display lines: the list's and the
/// reading's.
var bibleScroll = 0
var bibleListScroll = 0

/// The line count's cache: the book and the column count it
/// was reckoned at — a book is a long walk, and the count is
/// asked at every painting.
var bibleCountBook = -1
var bibleCountCols = -1
var bibleCountLines = 0

func bibleTextX() -> Int { guiBibleX + 16 }
func bibleListTop() -> Int { guiBibleY + 52 }
func bibleTextTop() -> Int { guiBibleY + 92 }
func bibleRailX() -> Int { guiBibleX + guiBibleW - 40 }
func bibleBottom() -> Int { guiBibleY + guiBibleH - 16 }

/// The page's width in letters, as the Reader reckons its
/// own: the window's width less margins and the rail.
func bibleCols() -> Int {
    max(8, (guiBibleW - 64) / 16)
}

func bibleListVisibleRows() -> Int {
    max(1, (bibleBottom() - 20 - bibleListTop()) / 16)
}

func bibleTextVisibleRows() -> Int {
    max(1, (bibleBottom() - bibleTextTop()) / 16)
}

func bibleVisibleRows() -> Int {
    bibleReading ? bibleTextVisibleRows() : bibleListVisibleRows()
}

func guiBibleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiBibleX && x < guiBibleX + guiBibleW
        && y >= guiBibleY && y < guiBibleY + guiBibleH
}

func guiBibleCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiBibleX, guiBibleW)
        && x < guiCloseBoxX(guiBibleX, guiBibleW) + guiBoxW
        && y >= guiBibleY + guiBoxTop
        && y < guiBibleY + guiBoxTop + guiBoxH
}

func guiBibleMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiBibleX, guiBibleW)
        && x < guiMaxBoxX(guiBibleX, guiBibleW) + guiBoxW
        && y >= guiBibleY + guiBoxTop
        && y < guiBibleY + guiBoxTop + guiBoxH
}

func guiBibleTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiBibleX && x < guiBibleX + guiBibleW
        && y >= guiBibleY && y < guiBibleY + 36
}

func guiBibleUpContains(_ x: Int, _ y: Int) -> Bool {
    let top = bibleReading ? bibleTextTop() : bibleListTop()
    return x >= bibleRailX() && x < bibleRailX() + 28
        && y >= top && y < top + 28
}

func guiBibleDownContains(_ x: Int, _ y: Int) -> Bool {
    x >= bibleRailX() && x < bibleRailX() + 28
        && y >= bibleBottom() - 28 && y < bibleBottom()
}

/// The "< All books" strip at a reading's head: the way
/// back to the list, standing where the eye already is.
func guiBibleStripContains(_ x: Int, _ y: Int) -> Bool {
    bibleReading
        && x >= bibleTextX() && x < bibleTextX() + 176
        && y >= guiBibleY + 52 && y < guiBibleY + 80
}

/// True when the bundle entry the walk last named (its
/// facts in the bundle entry globals) is the word given,
/// letter for letter — the bundle's names stand in the
/// capital letters they were staged in.
func bibleEntryNameIs(_ word: StaticString) -> Bool {
    let base = bundleBase()
    var index = 0
    while true {
        let wanted = word.utf8Start[index]
        if wanted == 0 { return index == bundleEntryNameLength }
        if index >= bundleEntryNameLength { return false }
        if base[bundleEntryNameOffset + index] != wanted {
            return false
        }
        index += 1
    }
}

/// True when the span's bytes at [start, end) are the word
/// given, letter for letter.
func bibleSpanIs(_ start: Int, _ end: Int,
                 _ word: StaticString) -> Bool {
    let base = bundleBase()
    var index = 0
    while true {
        let wanted = word.utf8Start[index]
        if wanted == 0 { return start + index == end }
        if start + index >= end { return false }
        if base[start + index] != wanted { return false }
        index += 1
    }
}

/// One line of the index, by its number (0 the magic, 1 the
/// count, 2 the credit, then one line per book): its range
/// within the index payload, or (-1, -1) when the index
/// holds no such line.
func bibleIndexLine(_ line: Int) -> (start: Int, end: Int) {
    let base = bundleBase()
    var start = 0
    var current = 0
    while true {
        var end = start
        while end < bibleIndexLength
            && base[bibleIndexStart + end] != 0x0A {
            end += 1
        }
        if current == line { return (start, end) }
        if end >= bibleIndexLength { return (-1, -1) }
        start = end + 1
        current += 1
    }
}

/// Reads the index once: finds BIBLE-IDX.TXT among the
/// bundle's files, proves its magic line, takes its book
/// count and its credit line. What is not found is not
/// invented: the count stands at nothing and the window
/// says so.
func bibleParseIndex() {
    if bibleParsed { return }
    bibleParsed = true
    if !bundleValid { return }
    var index = 0
    var found = false
    while index < bundleFileCount {
        if !bundleEntryAt(index) { return }
        if bibleEntryNameIs(guiBibleIndexName) {
            found = true
            break
        }
        index += 1
    }
    if !found { return }
    // The entry's offset already stands reckoned from the
    // span's own beginning, payload start folded in — the
    // Reader's road (readerOpenFilePath).
    bibleIndexStart = Int(bundleEntryOffset)
    bibleIndexLength = Int(bundleEntryLength)
    let magic = bibleIndexLine(0)
    if magic.start < 0
        || !bibleSpanIs(bibleIndexStart + magic.start,
                        bibleIndexStart + magic.end,
                        guiBibleMagic) {
        bibleIndexLength = 0
        return
    }
    // The count line: "books: N".
    let base = bundleBase()
    let countLine = bibleIndexLine(1)
    if countLine.start < 0 { return }
    var at = countLine.start
    while at < countLine.end
        && base[bibleIndexStart + at] != 0x3A {
        at += 1
    }
    at += 1
    var count = 0
    var digits = 0
    while at < countLine.end {
        let byte = base[bibleIndexStart + at]
        if byte >= 0x30 && byte <= 0x39 {
            count = count * 10 + Int(byte - 0x30)
            digits += 1
        }
        at += 1
    }
    if digits == 0 || count > 200 { return }
    let credit = bibleIndexLine(2)
    if credit.start < 0 { return }
    bibleCreditStart = bibleIndexStart + credit.start
    bibleCreditLength = credit.end - credit.start
    bibleBookCount = count
}

/// One book's facts from its index line: its group file's
/// name range, its text's offset and length inside that
/// file, and its own name's range — the ranges within the
/// index payload, the numbers plain.
func bibleBookEntry(_ book: Int)
    -> (fileStart: Int, fileLength: Int, offset: Int,
        length: Int, nameStart: Int, nameEnd: Int) {
    let empty = (0, 0, 0, 0, 0, 0)
    let range = bibleIndexLine(book + 3)
    if range.start < 0 { return empty }
    let base = bundleBase()
    var at = range.start
    while at < range.end && base[bibleIndexStart + at] != 0x20 {
        at += 1
    }
    let fileStart = range.start
    let fileEnd = at
    at += 1
    var offset = 0
    while at < range.end && base[bibleIndexStart + at] != 0x20 {
        let byte = base[bibleIndexStart + at]
        if byte < 0x30 || byte > 0x39 { return empty }
        offset = offset * 10 + Int(byte - 0x30)
        at += 1
    }
    at += 1
    var length = 0
    while at < range.end && base[bibleIndexStart + at] != 0x20 {
        let byte = base[bibleIndexStart + at]
        if byte < 0x30 || byte > 0x39 { return empty }
        length = length * 10 + Int(byte - 0x30)
        at += 1
    }
    at += 1
    if at > range.end { return empty }
    return (fileStart, fileEnd - fileStart, offset, length,
            at, range.end)
}

/// Finds one of the index's group files among the bundle's
/// entries, by the name the index itself speaks: on success
/// bibleGroupStart is the file's payload place in the span.
func bibleFindFile(_ nameStart: Int, _ nameLength: Int) -> Bool {
    let base = bundleBase()
    var index = 0
    while index < bundleFileCount {
        if !bundleEntryAt(index) { return false }
        if bundleEntryNameLength == nameLength {
            var matched = true
            var at = 0
            while at < nameLength {
                if base[bundleEntryNameOffset + at]
                    != base[bibleIndexStart + nameStart + at] {
                    matched = false
                    break
                }
                at += 1
            }
            if matched {
                bibleGroupStart = Int(bundleEntryOffset)
                return true
            }
        }
        index += 1
    }
    return false
}

/// Opens one book at its head: its place found through the
/// index and its group file, the window turned to reading.
func bibleOpenBook(_ book: Int) {
    let entry = bibleBookEntry(book)
    if entry.length <= 0 { return }
    if !bibleFindFile(entry.fileStart, entry.fileLength) {
        return
    }
    bibleBook = book
    bibleTextStart = bibleGroupStart + entry.offset
    bibleTextLength = entry.length
    bibleReading = true
    bibleScroll = 0
    bibleCountBook = -1
    pointerHide()
    guiPaintBibleWindow()
    pointerShow()
}

/// Returns from a book to the list of books, the list's own
/// scroll as it was left.
func bibleBackToList() {
    bibleReading = false
    pointerHide()
    guiPaintBibleWindow()
    pointerShow()
}

/// One display line's span of the book being read, from the
/// byte where it begins — the Reader's own reckoning
/// (readerLineSpan) walked over the bundle's span: line
/// feeds end lines, undrawable bytes are passed over
/// without a column, and the wrap breaks at the last space
/// that fits.
func bibleLineSpan(_ pos: Int, _ cols: Int) -> (end: Int,
                                                next: Int) {
    let base = bundleBase()
    var index = pos
    var col = 0
    var breakEnd = -1
    var breakNext = -1
    while index < bibleTextLength {
        let byte = base[bibleTextStart + index]
        if byte == 0x0A {
            return (index, index + 1)
        }
        if byte == 0x0D || (byte < 0x20 && byte != 0x09)
            || byte == 0x7F {
            index += 1
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

/// The book's whole count of display lines at the page's
/// present width, walked end to end and kept against the
/// book and the width that reckoned it.
func bibleTotalLines() -> Int {
    if bibleCountBook == bibleBook
        && bibleCountCols == bibleCols() {
        return bibleCountLines
    }
    let cols = bibleCols()
    var count = 0
    var pos = 0
    while pos < bibleTextLength {
        let span = bibleLineSpan(pos, cols)
        count += 1
        if span.next < 0 { break }
        pos = span.next
    }
    bibleCountBook = bibleBook
    bibleCountCols = cols
    bibleCountLines = count
    return count
}

/// The standing view's furthest scroll.
func bibleMaxScroll() -> Int {
    if bibleReading {
        return max(0, bibleTotalLines() - bibleTextVisibleRows())
    }
    return max(0, bibleBookCount - bibleListVisibleRows())
}

/// Scrolls the standing view — the list's or the reading's —
/// by whole lines, clamped and repainted, down the elders'
/// road.
func bibleScrollBy(_ lines: Int) {
    let maxScroll = bibleMaxScroll()
    if bibleReading {
        let target = min(max(bibleScroll + lines, 0), maxScroll)
        if target == bibleScroll { return }
        bibleScroll = target
    } else {
        let target = min(max(bibleListScroll + lines, 0),
                         maxScroll)
        if target == bibleListScroll { return }
        bibleListScroll = target
    }
    pointerHide()
    guiPaintBibleWindow()
    pointerShow()
}

/// Gives the room to the Bible window, by the Reader's road.
func guiSetFocusBible() {
    if guiFocusBible && !guiFocusTerminal && !guiFocusFiles
        && !guiFocusReader && !guiFocusWrite && !guiFocusShield
        && !guiFocusHelp {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = true
    guiFocusShield = false
    guiFocusHelp = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Bible window on its list of books. The index
/// is read at the first opening; a Bible that did not ride
/// opens onto its one plain line instead.
func guiOpenBible() {
    bibleParseIndex()
    bibleOpen = true
    bibleReading = false
    guiSetFocusBible()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// The Bible window's maximize and restore, one control,
/// down the Reader's road — the page re-wraps at its new
/// width because the layout is a walk, not a keeping.
func guiToggleBibleMaximize() {
    if bibleMaximized {
        guiBibleX = bibleSavedX
        guiBibleY = bibleSavedY
        guiBibleW = bibleSavedW
        guiBibleH = bibleSavedH
        bibleMaximized = false
    } else {
        bibleSavedX = guiBibleX
        bibleSavedY = guiBibleY
        bibleSavedW = guiBibleW
        bibleSavedH = guiBibleH
        guiBibleX = 0
        guiBibleY = guiWorkTop
        guiBibleW = framebufferWidth
        guiBibleH = guiBarTop() - guiWorkTop
        bibleMaximized = true
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Paints the Bible window's maximize box, as its siblings'.
func guiPaintBibleMaxBox() {
    let boxX = guiMaxBoxX(guiBibleX, guiBibleW)
    let boxY = guiBibleY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if bibleMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Bible window's title strip alone: "Bible"
/// over the list; over a book, the book's own name read out
/// of the index, cut at the room the strip leaves it, as
/// the feather's title is cut.
func guiPaintBibleTitleBar(_ held: Bool) {
    guiFillRect(guiBibleX, guiBibleY, guiBibleW, 36,
                held ? guiHeldBarColor
                    : (guiFocusBible ? guiCardinalColor
                                     : guiDimBarColor))
    if bibleReading && bibleBook >= 0 && bibleBookCount > 0 {
        let entry = bibleBookEntry(bibleBook)
        let room = (guiBibleW - 16 - guiBoxGap - 2 * guiBoxW
            - guiBoxRightPad) / 16
        let count = min(entry.nameEnd - entry.nameStart,
                        max(room, 0))
        if count > 0 {
            guiDrawBytes(guiBibleX + 16, guiBibleY + 10, 2,
                         bundleBase(),
                         bibleIndexStart + entry.nameStart,
                         count, guiWhiteColor)
        }
    } else {
        guiDrawText(guiBibleX + 16, guiBibleY + 10, 2,
                    guiBibleTitle, guiWhiteColor)
    }
    guiPaintBibleMaxBox()
    guiPaintXBox(guiCloseBoxX(guiBibleX, guiBibleW),
                 guiBibleY + guiBoxTop)
}

/// Paints the list of books: one name to a line in the
/// books' own order, and the credit line at the foot. A
/// Bible that did not ride paints its one plain line.
func guiPaintBibleList() {
    if bibleBookCount == 0 {
        guiDrawText(bibleTextX(), bibleListTop(), 2,
                    guiBibleNoRideLine, guiInkColor)
        return
    }
    let rows = bibleListVisibleRows()
    var row = 0
    while row < rows {
        let book = bibleListScroll + row
        if book >= bibleBookCount { break }
        let entry = bibleBookEntry(book)
        guiDrawBytes(bibleTextX(), bibleListTop() + row * 16,
                     2, bundleBase(),
                     bibleIndexStart + entry.nameStart,
                     entry.nameEnd - entry.nameStart,
                     guiInkColor)
        row += 1
    }
    if bibleCreditLength > 0 {
        // The credit stands a half-margin further left than
        // the names: at the names' own margin its last
        // letter would slide beneath the rail's down
        // button, and the line is owed whole.
        guiDrawBytes(guiBibleX + 8, bibleBottom() - 16, 2,
                     bundleBase(), bibleCreditStart,
                     bibleCreditLength, 0x6B5636)
    }
}

/// Paints a reading's page: the wrapped lines as they stand
/// scrolled, walked from the book's head each time, as the
/// Reader's page is walked.
func guiPaintBibleReadBody() {
    let base = bundleBase()
    let cols = bibleCols()
    let rows = bibleTextVisibleRows()
    var pos = 0
    var line = 0
    while line < bibleScroll && pos < bibleTextLength {
        let span = bibleLineSpan(pos, cols)
        if span.next < 0 {
            pos = bibleTextLength
            break
        }
        pos = span.next
        line += 1
    }
    var row = 0
    while row < rows {
        let y = bibleTextTop() + row * 16
        if line >= bibleTotalLines() { break }
        let span = bibleLineSpan(pos, cols)
        var col = 0
        var index = pos
        while index < span.end {
            let byte = base[bibleTextStart + index]
            if byte == 0x0D || (byte < 0x20 && byte != 0x09)
                || byte == 0x7F {
                index += 1
                continue
            }
            let glyph: UInt8 = byte == 0x09 ? 0x20 : byte
            guiDrawGlyph(bibleTextX() + col * 16, y, 2,
                         glyph, guiInkColor)
            col += 1
            index += 1
        }
        if span.next < 0 { break }
        pos = span.next
        line += 1
        row += 1
    }
}

/// Paints the "< All books" strip at a reading's head.
func guiPaintBibleStrip() {
    let sx = bibleTextX()
    let sy = guiBibleY + 52
    guiFillRect(sx, sy, 176, 28, guiButtonColor)
    guiFillRect(sx, sy, 176, 2, guiBorderColor)
    guiFillRect(sx, sy + 26, 176, 2, guiBorderColor)
    guiFillRect(sx, sy, 2, 28, guiBorderColor)
    guiFillRect(sx + 174, sy, 2, 28, guiBorderColor)
    guiDrawText(sx + 16, sy + 6, 2, guiAllBooksLabel,
                guiInkColor)
}

/// Paints the Bible window whole: shadow, parchment body
/// and border — a page's colours, as its siblings wear —
/// its title strip, its standing view, and its scroll rail.
func guiPaintBibleWindow() {
    let maxScroll = bibleMaxScroll()
    if bibleReading {
        if bibleScroll > maxScroll { bibleScroll = maxScroll }
        if bibleScroll < 0 { bibleScroll = 0 }
    } else {
        if bibleListScroll > maxScroll {
            bibleListScroll = maxScroll
        }
        if bibleListScroll < 0 { bibleListScroll = 0 }
    }
    guiFillRect(guiBibleX + 10, guiBibleY + 12, guiBibleW,
                guiBibleH, guiShadowColor)
    guiFillRect(guiBibleX, guiBibleY, guiBibleW, guiBibleH,
                guiParchmentColor)
    guiFillRect(guiBibleX, guiBibleY, guiBibleW, 2,
                guiBorderColor)
    guiFillRect(guiBibleX, guiBibleY + guiBibleH - 2,
                guiBibleW, 2, guiBorderColor)
    guiFillRect(guiBibleX, guiBibleY, 2, guiBibleH,
                guiBorderColor)
    guiFillRect(guiBibleX + guiBibleW - 2, guiBibleY, 2,
                guiBibleH, guiBorderColor)
    guiPaintBibleTitleBar(false)
    let top = bibleReading ? bibleTextTop() : bibleListTop()
    let scroll = bibleReading ? bibleScroll : bibleListScroll
    if bibleReading {
        guiPaintBibleStrip()
        guiPaintBibleReadBody()
    } else {
        guiPaintBibleList()
    }
    guiPaintScrollButton(bibleRailX(), top, true, scroll > 0)
    guiPaintScrollButton(bibleRailX(), bibleBottom() - 28,
                         false, scroll < maxScroll)
}

/// A press inside the Bible window, asked as its siblings
/// are: its close box closes it alone — the room falling
/// to the Terminal when the Terminal stands, as the
/// Reader's closing lets it fall; its maximize box trades
/// its size; its title bar takes hold for the drag, unless
/// the press is the second of a pair; its rail steps the
/// standing view a line; the "< All books" strip returns
/// to the list; a press on a book's name opens the book;
/// any other press gives the window the room.
func guiPressBible(_ x: Int, _ y: Int) -> Bool {
    if !bibleOpen { return false }
    if !guiBibleContains(x, y) { return false }
    if guiBibleCloseContains(x, y) {
        bibleOpen = false
        if guiFocusBible {
            guiFocusBible = false
            guiFocusTerminal = termOpen
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiBibleMaxContains(x, y) {
        guiSetFocusBible()
        guiToggleBibleMaximize()
        return true
    }
    if guiBibleTitleContains(x, y) {
        guiSetFocusBible()
        if bibleTitlePressArmed
            && ticks &- bibleTitlePressTick
                <= guiDoubleClickTicks {
            bibleTitlePressArmed = false
            guiToggleBibleMaximize()
            return true
        }
        bibleTitlePressArmed = true
        bibleTitlePressTick = ticks
        guiBeginDrag(7, x, y)
        return true
    }
    if guiBibleUpContains(x, y) {
        guiSetFocusBible()
        bibleScrollBy(-1)
        return true
    }
    if guiBibleDownContains(x, y) {
        guiSetFocusBible()
        bibleScrollBy(1)
        return true
    }
    if guiBibleStripContains(x, y) {
        bibleBackToList()
        return true
    }
    if !bibleReading && bibleBookCount > 0
        && x >= bibleTextX() && x < bibleRailX() - 8
        && y >= bibleListTop()
        && y < bibleListTop() + bibleListVisibleRows() * 16 {
        let book = bibleListScroll
            + (y - bibleListTop()) / 16
        if book < bibleBookCount {
            guiSetFocusBible()
            bibleOpenBook(book)
            return true
        }
    }
    guiSetFocusBible()
    return true
}

/// The `bible` command's work, down the `write` command's
/// own road: in the Terminal, the window opens where the
/// conversation stands; at the text console, the face
/// opens with the window standing on it.
func runBibleCommand() {
    if consoleInTerminal {
        guiOpenBible()
    } else {
        bibleWantedAtFace = true
        runGui()
    }
}

