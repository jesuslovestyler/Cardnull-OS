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
                       _ fromBundle: Bool, _ extent: UInt32,
                       _ offset: UInt32, _ size: UInt32) -> Bool {
    let buffer = discBuffer()
    var written: UInt32 = 0
    var sectorIndex: UInt32 = 0
    while written < size {
        if !serveReadChunk(fromBundle, extent, offset, size,
                           sectorIndex) { return false }
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
    if !filesReady() { return }
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
    let outcome = serveResolvePath(length)
    if outcome == pathMissingCode {
        writeNotHerePrefix()
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
    if !readWholeFileInto(base, resolvedFromBundle, resolvedExtent,
                          resolvedOffset, resolvedSize) {
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
    // The reading is NOT handed back yet (milestone 25): a
    // feather that claims the graphical suite at the desktop
    // opens a window titled with its card's own title, and
    // the title's letters live in this reading. The block is
    // freed on the far side of the session instead — `heap`
    // after a feather reads exactly as it did, the freeing
    // merely having waited for the guest to leave.
    writeStatic(runRunningPrefix)
    writePathArgument(length)
    writeLine(runRunningSuffix)
    writeLine(sessionStopLine)
    resetGuestDoorState()
    // The windowed road is armed (milestone 25): a feather
    // launched while the desktop stands — typed in its
    // Terminal, or launched from the Files window, which
    // types through the same Terminal — will open its face
    // in a window when it claims the suite. From the text
    // shell the same feather takes the whole screen, as it
    // always has: the face fits the room it was opened in.
    if consoleInTerminal {
        guestWindowArmed = true
        featherWinTitleBase = base
        featherWinTitleStart = featherTitleStart
        featherWinTitleLength = featherTitleLength
    }
    programRunning = true
    let verdict = cardnullLaunchProgram(root, programBase,
                                        programStackTop)
    programRunning = false
    teardownProgramSpace(root)
    restoreGuestScreen()
    featherWinTitleBase = nil
    heapFree(address)
    if verdict == programKilledVerdict {
        writeLine(programKilledLine)
    } else {
        writeStatic(programExitedPrefix)
        writeNumber(verdict)
        writeNewline()
    }
}

// ---------------------------------------------------------------------------
// Feathers with faces (milestone 18): the door's second suite.
//
// Until now a guest could speak but could not be seen: the text
// door (services 1 and 2) lends it the shell's voice, letter by
// letter, onto a screen the kernel keeps. This milestone gives
// a guest a face of its own — five new services through the same
// int 0x80 door, behind the same walls:
//
//   4  screen size — the framebuffer's width and height, so a
//      guest can reckon its painting from the screen it was
//      actually given, not from a guess baked into its bytes.
//   5  fill a rectangle — the kernel draws, clipped to the
//      screen. A guest never touches the framebuffer itself;
//      it names a place, a shape and a colour (0x00RRGGBB),
//      and the kernel's own hand — guiFillRect, the desktop's
//      painter — lays the pixels. Degenerate asks (a width or
//      height that is not positive) and asks lying wholly off
//      the screen are refused with the answer 1 and nothing
//      drawn; a partly-off-screen ask is drawn clipped and
//      answers 0. No ask can fault: the corners are clamped
//      into the screen's neighbourhood before any arithmetic
//      that could run away is trusted.
//   6  draw text — the kernel renders the guest's words with
//      its own GUI font at twofold size (the size the desktop's
//      windows speak in: 16 pixels a letter). The pointer and
//      length are proven against the guest's estate with
//      exactly service 1's discipline — the whole reach inside
//      the estate before a byte is read — and a reach that
//      leaves the estate stops the guest under the door's own
//      protection report, the fault road's twin, below. The
//      drawn count is capped at 256 letters; text is clipped
//      at the screen's edge, a letter at a time.
//   7  read a key — while a session stands, the keyboard is
//      the guest's: this service takes scancodes out of the
//      same ring the shell drains and translates them with the
//      shell's own table, under shift and caps state the guest
//      keeps for itself, so neither typist disturbs the other.
//      Enter answers 0x0A, Backspace 0x08, and keys that are
//      not characters — shifts, arrows, releases — answer 0,
//      as does an empty ring: the service never waits. A guest
//      that wants to wait knocks, hears 0, and yields
//      (service 3) until a key answers — the blocking shape is
//      built out of the two honest pieces, and said so.
//      One key is never the guest's: Esc. Milestone 15's law
//      stands armed through a graphical session exactly as
//      through a text one — the keyboard handler keeps the Esc
//      make code out of the ring while any session stands and
//      asks for the stop instead — and should an Esc make ever
//      be found waiting in the ring, this service asks for the
//      same stop and answers 0. A feather never receives Esc.
//   8  poll the mouse — the session's own reckoning of the
//      pointer: each knock drains the mouse ring and makes
//      packets of the bytes with the face's own discipline
//      (a first byte carries bit 3; anything else is a byte
//      astray and is let go), the travels are added and
//      clamped to the screen, and the answer carries the
//      place and the buttons. The reckoning opens at the
//      screen's centre at the session's first knock. The
//      kernel draws no pointer for a guest — the reckoning is
//      data, and a guest that wants a visible pointer paints
//      its own from it, as the terminal feather could one day.
//      Milestone 26: a wheel mouse's packets carry a fourth
//      byte; its turnings gather between polls and ride home
//      in the answer's wheel word (bits 40–47, signed, spent
//      by the asking) — windowed, the face's assembly is the
//      gatherer, and only turnings over the guest's canvas
//      are the guest's.
//
// The face rules, stated as law and kept by the hands below:
//
//   - The suite is claimed whole. A single guest's first knock
//     on any of services 4–9 takes the door's graphical side:
//     its own typing state, its own mouse reckoning, and —
//     where the boot brought a framebuffer — the guest's face
//     for the session. (Milestone 25: a feather launched while
//     the desktop stands opens that face in a desktop window
//     instead — window 5, in the keeping below — and the
//     suite's answers fit the window: the size is the canvas's,
//     the painting is offset by the canvas's origin and
//     clipped to it, the mouse is answered relative to it,
//     the keys are the guest's only while its window holds
//     the room, and service 9 tells the guest when its canvas
//     has been painted over and a repaint is owed. From the
//     text shell, and for bare guests always, the face is the
//     screen edge to edge, exactly as milestone 18 left it.)
//     A text guest that never knocks is untouched by all of
//     this — nothing is claimed, nothing is restored, and
//     milestones 9–17 behave exactly as they did, which the
//     milestone's regressions lean on.
//   - The way back is exact. When the session ends — by the
//     guest's leaving, by the user's Esc, by a fault, by the
//     door's own stop — the world it covered is repainted from
//     what was never touched: launched from the desktop's
//     Terminal, the desktop paints itself whole and the
//     Terminal's conversation stands in its grid as it stood,
//     word for word; launched from the text shell, the shell's
//     grid paints back through the screen. The estate is then
//     taken back as ever, so `mem` after a graphical session
//     reads as it read before it: faces cost no frames and no
//     heap — the framebuffer was reserved out of the pool at
//     boot, and the suite's keepings are a handful of words.
//   - A pair takes the text door only. Graphical services are
//     for a session of one guest: two guests share one screen
//     by taking turns speaking on it, and a face cannot be
//     shared by turns. While a pair session stands, a knock
//     on the suite is refused — the refusal spoken plainly on
//     the screen, once per session, and answered with the
//     service's nothing (0 for size, text and keys, 1 for a
//     rectangle, all-ones for the mouse and the window
//     standing). `both` itself is
//     not refused — the kernel cannot know a guest's mind
//     before it knocks — but the knock is, with the reason.
//
// The witnesses: FACE.FEATHER, a greeting painted by a guest;
// TERM.FEATHER, a terminal that is a feather, standing on this
// suite alone — the stone milestone 13 promised when it
// labelled the kernel's Terminal window honestly; BADGFX.BIN,
// which knocks on draw text with a pointer aimed at the
// kernel's first byte and is stopped at the same wall BAD.BIN
// found, through the door instead of through a fault; and
// WILDRECT.BIN, which asks for a rectangle far larger than the
// screen and stands, clipped and unharmed, to tell about it.
// ---------------------------------------------------------------------------

/// The door protection report's words — the fault report's
/// twin for a stopping the door itself hands down, written
/// into the same top rows of the same grid by the same hands,
/// so a stopped guest's screen reads one way by either road:
/// the title, the address the guest reached for, and the
/// service that was refused, in plain words.
let doorReportTitle: StaticString =
    "A guest reached past its own ground - the guest was stopped."
let doorReportServiceLine: StaticString =
    "  Service: draw text - the reach left the guest's estate."

/// The pair refusal, spoken once per pair session at the first
/// graphical knock: the reason, plainly, on the shared screen.
let guestPairRefusalLine: StaticString =
    "Graphical services belong to a session of one guest; a pair keeps the text door only."

/// The drawn count's cap for service 6: a guest may ask the
/// door to read at most this many of its letters in one knock.
/// The whole asked reach is still proven against the estate
/// first — the cap bounds the drawing, never the proving.
let guestTextCap: UInt64 = 256

/// The suite's text measure: the kernel's GUI font at twofold
/// size, the measure of the desktop's own windows.
let guestTextScale = 2

/// Has the running single guest claimed the screen? Set at the
/// suite's first knock (when the boot brought a framebuffer),
/// read by the launch's caller when the session ends: while it
/// stands, the covered world must be repainted on the way home.
var guestGraphical = false

/// Has the running guest taken the graphical suite at all this
/// session? The claim's one-time keeping: the typing state and
/// the mouse reckoning are opened fresh at the first knock and
/// never again within the session.
var guestDoorTaken = false

/// Has the pair refusal been spoken this session? Once is
/// plain; at every knock would be a nag.
var guestPairRefusalSpoken = false

/// The guest's own typing state, kept apart from the shell's
/// (shiftHeld, capsLock, extendedPrefix are the shell's own):
/// a guest's Shift is its own affair, and the shell's next
/// line must never inherit a capital from a feather's reading.
var guestKeyShift = false
var guestKeyCaps = false
var guestKeyExtended = false

/// The session's mouse reckoning: the pointer's place as the
/// session's polls have added it up, the buttons of the last
/// whole packet, and the packet assembly's stage and stashed
/// bytes — the face's discipline (guiTakeMouseByte) kept a
/// second time, for a second reader, rather than shared: the
/// face's stage must stand untouched while a guest holds the
/// room, and the session's must open clean at its first knock.
var guestMouseX = 0
var guestMouseY = 0
var guestMouseButtons: UInt64 = 0
var guestMouseStage = 0
var guestMouseFirst: UInt8 = 0
var guestMouseSecond: UInt8 = 0
var guestMouseThird: UInt8 = 0

/// The wheel's turning as it gathers for the guest
/// (milestone 26): the signed sum of every wheel byte's
/// turning since the guest last polled the mouse — positive
/// turned up, toward older lines; negative down. Both roads
/// fill the one keeping: a full-screen guest's own assembly
/// (below) adds its packets' fourth bytes directly; a
/// windowed guest's turnings are gathered by the face's
/// assembly while the pointer stands over its canvas
/// (guiWheelTurn). A poll of the mouse (service 8) answers
/// the sum in its wheel word and spends it — the next poll
/// hears only what has turned since. The sum is clamped to
/// a signed byte's reach, the field it rides home in.
var guestWheelAccum = 0

// MARK: - Milestone 25: the guest's face in a window
//
// A feather launched while the desktop stands opens its
// face in a window on that desktop (window 5) instead of
// taking the screen. The window's size is FIXED at the
// claim: the guest reckons its face from service 4's
// answer once, at its start, and a size that moved under
// it would make its own reckoning a lie — a different size
// means closing and reopening the feather. There is no
// resize furniture and no maximize box; the chrome is the
// title bar and the close box the other windows keep.
//
// Repaint, honestly: the kernel paints its side of the
// window — the frame, the title, and the canvas's ground —
// whenever the window opens, moves, is raised, or is
// covered and uncovered, and every such painting fills the
// canvas with its ground. That filling IS the kernel's
// invalidation: the guest learns of it by service 9 (the
// window standing), whose bit 0 answers "a repaint is
// owed" until the guest asks, and a well-mannered feather
// paints its whole face again the moment the owing stands.
// (The feather's window stands over the elders for its
// whole session, so the owing is never a covering's debt:
// it is the debt of the kernel's own ground-laying at the
// opening, at a change of the room, and at a drag's end.)
//
// A windowed session still runs with the shell blocked in
// the launch, as every session does: the desktop is tended
// on the guest's own input knocks. Services 7, 8 and 9
// first feed the drained mouse bytes through the desktop's
// own hands, so clicks raise and cover windows, the title
// bar drags, and the close box asks for the session's
// stop — Esc's request by another road — all while the
// guest stands. Keys are the guest's only while its window
// holds the room (service 7 lets them go otherwise, the
// way the desktop's own faces do).

/// Armed by `runFeather` when the launch stands on the
/// desktop: the guest's claim will open a window instead
/// of taking the screen. Cleared with the rest of the
/// door's state at every launch.
var guestWindowArmed = false

/// Whether the running graphical session is windowed. Set
/// at the claim, cleared when the screen is restored.
var guestWindowed = false

/// A repaint is owed: the kernel has painted over the
/// guest's canvas (at the claim, and whenever the window
/// is painted again), and the guest has not yet asked
/// service 9. Stands at every claim, windowed or
/// full-screen, so one contract serves both roads:
/// full-screen, bits 1 and 2 of the standing always stand
/// and bit 0 stands once at the claim.
var guestRepaintOwed = false

/// The card reading's own letters for the window's title:
/// the block's base and the title's place inside it. The
/// reading stays alive for the session (see `runFeather`)
/// and is handed back when the guest leaves.
var featherWinTitleBase: UnsafeMutablePointer<UInt8>? = nil
var featherWinTitleStart = 0
var featherWinTitleLength = 0

/// The feather window's rect on the framebuffer (window
/// 5), reckoned at the claim and fixed until the session
/// ends — only its place moves, when the title is dragged.
var guiFeatherX = 0
var guiFeatherY = 0
var guiFeatherW = 0
var guiFeatherH = 0

/// Whether the feather window stands on the desktop, and
/// whether it holds the room (the focus, in plain words).
var featherWinOpen = false
var guiFocusFeather = false

/// Sets the suite's keepings back to their rest, at every
/// launch — run, both and feather alike — so no session ever
/// inherits the last session's face, keys or refusals.
func resetGuestDoorState() {
    guestGraphical = false
    guestDoorTaken = false
    guestPairRefusalSpoken = false
    guestWindowArmed = false
    guestWindowed = false
    guestRepaintOwed = false
    featherWinOpen = false
    guiFocusFeather = false
}

/// The claim, taken at a single guest's first knock on the
/// graphical suite: the typing state wiped, the mouse
/// reckoning opened at the screen's centre, and — where the
/// boot brought a framebuffer — the screen itself claimed, so
/// the launch's caller knows to repaint the covered world when
/// the session ends. Called once per session (guestDoorTaken
/// keeps it so); later knocks walk straight past.
func guestTakeDoor() {
    if guestDoorTaken { return }
    guestDoorTaken = true
    guestKeyShift = false
    guestKeyCaps = false
    guestKeyExtended = false
    guestMouseStage = 0
    guestMouseButtons = 0
    guestWheelAccum = 0
    // The repaint owing stands at every claim (milestone
    // 25): the guest's first service-9 ask hears that its
    // ground has been laid and its face is owed — the same
    // word whether the face is a window or the whole
    // screen.
    guestRepaintOwed = true
    if useFramebuffer {
        guestGraphical = true
        guestMouseX = framebufferWidth / 2
        guestMouseY = framebufferHeight / 2
        if guestWindowArmed {
            // The windowed claim: the window opens on the
            // desktop, centred in the work area, as large
            // as its measure allows with air around it, and
            // holds the room — it was just opened, and its
            // owner is waiting to be typed to. Its size is
            // fixed here and never moves again this session.
            guestWindowed = true
            guiFeatherW = min(800, framebufferWidth - 48)
            guiFeatherH = min(560, guiBarTop() - guiWorkTop - 32)
            guiFeatherX = (framebufferWidth - guiFeatherW) / 2
            guiFeatherY = guiWorkTop + 40
            featherWinOpen = true
            guiFocusFeather = true
            guiFocusTerminal = false
            guiFocusFiles = false
            guiFocusReader = false
            pointerHide()
            guiPaintDesktop()
            pointerShow()
        }
    }
}

/// The pair refusal's speaking: the reason, once per session.
/// A pair's guests go on with the text door exactly as before;
/// only the knock is refused, and its answer — chosen by the
/// caller per service — is the service's nothing.
func guestPairRefusal() {
    if guestPairRefusalSpoken { return }
    guestPairRefusalSpoken = true
    writeLine(guestPairRefusalLine)
}

/// The door's protection report: the title at the grid's top
/// row, the address reached for beneath it, and the service
/// refused in the third — written through putCell like the
/// fault report, so it lands in whichever grid is live and
/// stands through the screen's restoration.
func printDoorReport(_ address: UInt64) {
    _ = writeStaticAt(0, 0, doorReportTitle)
    let col = writeStaticAt(1, 0, pageFaultAddressLabel)
    _ = writeHexAt(1, col, address, 16)
    _ = writeStaticAt(2, 0, doorReportServiceLine)
}

/// Stops the running guest at the door: the protection report
/// is written, its facts are kept beside the fault handler's,
/// and the floor's abandon hand carries the machine home with
/// the stopped verdict — the same road the page fault takes,
/// walked from the door instead. Never returns.
func doorStopGuest(_ address: UInt64) -> Never {
    programFaultAddress = address
    printDoorReport(address)
    if pairRunning {
        cardnullAbandonGuestInPair(programKilledVerdict)
    }
    cardnullAbandonProgram(programKilledVerdict)
}

/// The way home for a covered world, called by run and feather
/// once the estate is taken back: if the guest claimed the
/// screen, the world it covered is repainted from what it
/// never touched. From the desktop's Terminal: the mouse ring
/// is drained to a clean packet boundary — the courtesy
/// runGui performs at its own opening — the face's packet
/// stage is reset, the pointer's cushion is let go (its ground
/// was the guest's painting, and laying it back would stamp a
/// dead face onto the living one), the desktop paints itself
/// whole — windows, bar, and the Terminal's conversation from
/// its grid — and the pointer is drawn fresh over the restored
/// ground. From the text shell: the shell's grid paints back
/// through the screen, and the cursor is drawn at its place.
/// A session that never claimed the screen returns at once.
/// The text shell's branch blackens the whole pixel field
/// before the grid is painted back — the same courtesy the
/// face's own way home performs — because a graphical guest
/// paints past the grid's rows, and a repaint of the grid
/// alone would leave the lower field wearing the guest's
/// face. (On the VGA text screen there is no field past the
/// grid, and the repaint is the whole story there.)
func restoreGuestScreen() {
    if !guestGraphical { return }
    guestGraphical = false
    if guestWindowed {
        // The windowed way home (milestone 25): the window
        // closes, and the room returns to the Terminal —
        // the conversation that launched the feather and
        // the verdict line that follows it both live there.
        // The desktop repaint below then paints the whole
        // world true again, window and all trace of it gone.
        guestWindowed = false
        featherWinOpen = false
        guiFocusFeather = false
        guiFocusTerminal = true
    }
    if consoleInTerminal {
        while nextMouseByte() != nil {}
        mouseStage = 0
        pointerIsDrawn = false
        guiPaintDesktop()
        pointerShow()
    } else {
        if useFramebuffer {
            for row in 0 ..< framebufferHeight {
                for col in 0 ..< framebufferWidth {
                    putPixel(x: col, y: row, white: false)
                }
            }
        }
        repaintScreen()
        moveHardwareCursor()
    }
}

/// The graphical suite's answering voice: services 4–8, with
/// the five words the stub now carries up. The laws are checked
/// in the order they bind: a pair session refuses everything
/// first (with the reason spoken once); the key service needs
/// no screen and is answered next; the drawing services need
/// the framebuffer the boot brought, and without one answer
/// their nothings. Only then is the claim taken and the work
/// done.
func graphicalService(_ service: UInt64, _ first: UInt64,
                      _ second: UInt64, _ third: UInt64,
                      _ fourth: UInt64, _ fifth: UInt64) -> UInt64 {
    if pairRunning {
        guestPairRefusal()
        if service == 5 { return 1 }
        if service == 8 { return UInt64.max }
        if service == 9 { return UInt64.max }
        return 0
    }
    if service == 7 {
        guestTakeDoor()
        return guestReadKey()
    }
    if !useFramebuffer {
        if service == 5 { return 1 }
        if service == 8 { return UInt64.max }
        if service == 9 { return UInt64.max }
        return 0
    }
    guestTakeDoor()
    if service == 4 {
        // The face's measure, as one word: the width in
        // the low half, the height in the high half.
        // Windowed (milestone 25), the measure is the
        // window's canvas — the guest reckons its face
        // from this answer and no other, so the answer is
        // the room it truly has.
        if guestWindowed {
            return guestCanvasAnswer()
        }
        return UInt64(framebufferWidth)
            | UInt64(framebufferHeight) << 32
    }
    if service == 5 {
        return guestFillRectangle(first, second, third, fourth,
                                  fifth)
    }
    if service == 6 {
        return guestDrawText(first, second, third, fourth, fifth)
    }
    if service == 9 {
        return guestWindowStanding()
    }
    return guestMousePoll()
}

/// The windowed session's canvas measure: service 4's
/// answer in a window — the canvas's width in the low half
/// of the word, its height in the high half, the same
/// packing as the whole screen's.
func guestCanvasAnswer() -> UInt64 {
    return UInt64(guiFeatherW - 4)
        | UInt64(guiFeatherH - 2 - 36) << 32
}

/// The canvas's place on the framebuffer: its origin, the
/// window's frame inset by the border and the title bar —
/// the milestone-14 chrome's own measure (2 to the side,
/// 36 of title above, 2 of border below).
func guestCanvasOriginX() -> Int { return guiFeatherX + 2 }
func guestCanvasOriginY() -> Int { return guiFeatherY + 36 }

/// Tending the desktop while a windowed session stands
/// (milestone 25): the mouse bytes the interrupts have
/// gathered are fed through the desktop's own hands —
/// `guiTakeMouseByte`, the very hand the face feeds — so
/// packets assemble, the pointer travels, a press raises
/// or covers windows and may drag the feather's title or
/// ask for the session's stop at its close box, and a
/// release sets a carried window down, all by the
/// desktop's ordinary manners. Called at the head of the
/// input services (7, 8, 9) while the session is
/// windowed; the byte after the feeding is the state the
/// service then answers from.
func guestWindowTend() {
    while let byte = nextMouseByte() {
        guiTakeMouseByte(byte)
    }
    _ = guiPollMousePort()
}

/// Service 9, the window standing: the guest's news of
/// its window, as bits in one word — bit 0, a repaint is
/// owed (the kernel has painted over the guest's canvas:
/// at the opening, and whenever the window is painted
/// again; asking clears the owing, and a well-mannered
/// feather paints its whole face again at once); bit 1,
/// the guest's face holds the room (its keys are live);
/// bit 2, the pointer stands over the guest's ground.
/// A full-screen session answers bits 1 and 2 standing —
/// the whole screen is its ground and it always holds
/// the room — and bit 0 owed once, at the claim: one
/// contract for both roads.
func guestWindowStanding() -> UInt64 {
    if guestWindowed {
        guestWindowTend()
        var answer: UInt64 = 0
        if guestRepaintOwed { answer |= 1 }
        if guiFocusFeather { answer |= 2 }
        if pointerOverGuestCanvas() { answer |= 4 }
        guestRepaintOwed = false
        return answer
    }
    let owed = guestRepaintOwed
    guestRepaintOwed = false
    return owed ? 7 : 6
}

/// Whether the desktop's pointer stands over the
/// windowed guest's canvas — the standing's bit 2, and
/// the mouse poll's rule for whether the buttons are the
/// guest's to hear.
func pointerOverGuestCanvas() -> Bool {
    return pointerX >= guestCanvasOriginX()
        && pointerX < guestCanvasOriginX() + (guiFeatherW - 4)
        && pointerY >= guestCanvasOriginY()
        && pointerY < guestCanvasOriginY()
            + (guiFeatherH - 2 - 36)
}

/// Service 5, the rectangle: (x, y, width, height, colour) read
/// as signed words, for a guest may honestly ask for a shape
/// that begins off the screen's top or left. The ask is judged
/// before it is drawn: a width or height that is not positive
/// is degenerate and refused; the far corner is reckoned
/// against overflow before it is trusted (an origin past zero
/// and a reach that would wrap the reckoning are answered with
/// the reckoning's own ceiling, which is off any screen); both
/// corners are then clamped to the screen, and an ask nothing
/// of which stands on the screen is refused. What remains is
/// drawn by the desktop's own painter and answers 0; every
/// refusal answers 1 with nothing drawn, and no road faults.
func guestFillRectangle(_ xWord: UInt64, _ yWord: UInt64,
                        _ wWord: UInt64, _ hWord: UInt64,
                        _ colorWord: UInt64) -> UInt64 {
    let sx = Int64(bitPattern: xWord)
    let sy = Int64(bitPattern: yWord)
    let sw = Int64(bitPattern: wWord)
    let sh = Int64(bitPattern: hWord)
    if sw <= 0 || sh <= 0 { return 1 }
    var right: Int64
    if sx > 0 && sw > Int64.max - sx {
        right = Int64.max
    } else {
        right = sx + sw
    }
    var bottom: Int64
    if sy > 0 && sh > Int64.max - sy {
        bottom = Int64.max
    } else {
        bottom = sy + sh
    }
    if guestWindowed {
        // Windowed (milestone 25): the same asks, reckoned
        // in the canvas's own coordinates — clipped to the
        // canvas, offset by its origin, and never into the
        // window that covers it or the bar below.
        return guestFillWindowed(sx, sy, right, bottom,
                                 colorWord)
    }
    let width = Int64(framebufferWidth)
    let height = Int64(framebufferHeight)
    let x0 = sx < 0 ? Int64(0) : sx
    let y0 = sy < 0 ? Int64(0) : sy
    let x1 = right < 0 ? Int64(0) : (right > width ? width : right)
    let y1 = bottom < 0 ? Int64(0) : (bottom > height ? height : bottom)
    if x1 <= x0 || y1 <= y0 { return 1 }
    guiFillRect(Int(x0), Int(y0), Int(x1 - x0), Int(y1 - y0),
                UInt32(truncatingIfNeeded: colorWord))
    return 0
}

/// Service 5 in a window (milestone 25): the ask arrives
/// in the canvas's own coordinates. The intersection with
/// the canvas is taken in those coordinates with the same
/// care as the screen's (an ask lying wholly outside is
/// the refusal answer 1, never a stop), then painted
/// through `guestPaintFill`, which offsets, screens and
/// uncovers it. The pointer is hidden across the painting
/// so its saved-under cushion never lays stale pixels over
/// the guest's fresh ground, and shown again after.
func guestFillWindowed(_ sx: Int64, _ sy: Int64,
                       _ right: Int64, _ bottom: Int64,
                       _ colorWord: UInt64) -> UInt64 {
    let canvasW = Int64(guiFeatherW - 4)
    let canvasH = Int64(guiFeatherH - 2 - 36)
    let x0 = sx < 0 ? Int64(0) : sx
    let y0 = sy < 0 ? Int64(0) : sy
    let x1 = right < 0 ? Int64(0) : (right > canvasW ? canvasW : right)
    let y1 = bottom < 0 ? Int64(0)
        : (bottom > canvasH ? canvasH : bottom)
    if x1 <= x0 || y1 <= y0 { return 1 }
    pointerHide()
    guestPaintFill(Int(x0), Int(y0), Int(x1 - x0), Int(y1 - y0),
                   UInt32(truncatingIfNeeded: colorWord))
    pointerShow()
    return 0
}

/// Painting one rectangle of the guest's, in canvas
/// coordinates, onto the screen truly: the rect is moved
/// by the canvas's origin and cut off at the bottom bar
/// (the bar is a band across the whole screen; a window
/// may be dragged down over its head, and the bar must
/// stay the bar). Nothing else can cover the canvas: the
/// feather's window stands over the desktop's own windows
/// for its whole session (guiPaintDesktop keeps that
/// law), so no elder's rect is ever subtracted here — a
/// painting clipped only by the canvas and the bar is a
/// painting that lands exactly where the eye will find
/// the window. What survives is painted by `guiFillRect`.
func guestPaintFill(_ cx: Int, _ cy: Int, _ cw: Int, _ ch: Int,
                    _ color: UInt32) {
    let x = guestCanvasOriginX() + cx
    let y = guestCanvasOriginY() + cy
    var h = ch
    if y + h > guiBarTop() { h = guiBarTop() - y }
    if cw <= 0 || h <= 0 { return }
    guiFillRect(x, y, cw, h, color)
}

/// Service 6, the guest's drawn words: (x, y, address, length,
/// colour). The reach is proven first, with exactly service
/// 1's discipline — the pointer at or past the estate's base,
/// the length within the estate's span, the reach's end within
/// the span after it — and a reach that fails the proof stops
/// the guest under the door's protection report: the kernel
/// never reads a byte outside a guest's estate at a guest's
/// word, and a guest that asks it to does not walk on. The
/// drawing itself: at most the cap's letters, each painted by
/// the GUI's own glyph hand at twofold size — which clips
/// letter by letter at the screen's edge — the pen stepping
/// one letter's width per byte whether the byte paints or not.
/// The pen's place is first drawn into the screen's
/// neighbourhood (a letter's width of letters around it), so
/// no coordinate a guest can name makes the reckoning run off
/// the world's edge: a wholly distant ask simply paints
/// nothing and still answers its count.
func guestDrawText(_ xWord: UInt64, _ yWord: UInt64,
                   _ pointer: UInt64, _ length: UInt64,
                   _ colorWord: UInt64) -> UInt64 {
    if pointer < programBase {
        doorStopGuest(pointer)
    }
    let offset = pointer - programBase
    let span = programEstateTop - programBase
    if length > span {
        doorStopGuest(pointer)
    }
    if offset > span - length {
        doorStopGuest(pointer)
    }
    let count = length < guestTextCap ? length : guestTextCap
    let color = UInt32(truncatingIfNeeded: colorWord)
    var penX = Int(Int64(bitPattern: xWord))
    var penY = Int(Int64(bitPattern: yWord))
    if penX > framebufferWidth + 4096 { penX = framebufferWidth + 4096 }
    if penX < -4096 { penX = -4096 }
    if penY > framebufferHeight + 4096 { penY = framebufferHeight + 4096 }
    if penY < -4096 { penY = -4096 }
    var index: UInt64 = 0
    if guestWindowed { pointerHide() }
    while index < count {
        let byte = UnsafePointer<UInt8>(
            bitPattern: UInt(pointer + index))!.pointee
        if byte >= 0x20 && byte != 0x7F {
            if guestWindowed {
                guestDrawGlyphWindowed(penX, penY, byte, color)
            } else {
                guiDrawGlyph(penX, penY, guestTextScale, byte, color)
            }
        }
        penX += 8 * guestTextScale
        index += 1
    }
    if guestWindowed { pointerShow() }
    return count
}

/// One of the guest's letters in a window (milestone 25):
/// the same kernel font at the same twofold measure as
/// the whole screen's road, drawn square by square
/// through `guestPaintFill`, so a letter straddling the
/// canvas's edge — or a covering window — is clipped by
/// the same discipline as a filled rectangle, never by
/// trust. The pen stands in canvas coordinates.
func guestDrawGlyphWindowed(_ penX: Int, _ penY: Int,
                            _ byte: UInt8, _ color: UInt32) {
    let glyph = Int(byte & 0x7F)
    let font = cardnullFont8x8()
    let cell = 8 * guestTextScale
    if penX >= guiFeatherW - 4 || penY >= guiFeatherH - 2 - 36
        || penX + cell <= 0 || penY + cell <= 0 {
        return
    }
    var row = 0
    while row < 8 {
        let bits = font[glyph * 8 + row]
        if bits != 0 {
            var runStart = -1
            var col = 0
            while col <= 8 {
                let on = col < 8 && bits & (UInt8(1) << UInt8(col)) != 0
                if on && runStart < 0 { runStart = col }
                if !on && runStart >= 0 {
                    guestPaintFill(penX + runStart * guestTextScale,
                                   penY + row * guestTextScale,
                                   (col - runStart) * guestTextScale,
                                   guestTextScale, color)
                    runStart = -1
                }
                col += 1
            }
        }
        row += 1
    }
}

/// Service 7, the guest's keys: scancodes are taken from the
/// shell's own ring and read with the guest's own typing
/// state, until one of them is a key — or the ring stands
/// empty, which answers 0. Shift and Caps Lock are bookkeeping
/// (their makes and breaks are consumed, the state kept, and
/// 0 answered by going on to the next code rather than by
/// reporting a key that typed nothing); the extended prefix
/// swallows its second code whole, as the shell's reader does;
/// releases are not the guest's affair; Enter and Backspace
/// answer with their control letters, 0x0A and 0x08. The
/// translation itself is the shell's own table, consulted with
/// the guest's state standing in the shell's globals for the
/// one call and the shell's own state restored after it — no
/// interrupt handler reads those globals, so the exchange is
/// invisible to everyone. Esc's make code, should it ever be
/// found waiting here (the keyboard handler keeps it out of
/// the ring while a session stands, and asks for the stop
/// itself), asks for the stop and answers 0: the law holds by
/// both roads, and a feather never receives Esc.
func guestReadKey() -> UInt64 {
    if guestWindowed {
        // Windowed (milestone 25): tend the desktop first,
        // then the focus law — keys are the guest's only
        // while its window holds the room. While another
        // window holds it, the gathered keys are let go
        // (drained and dropped, the way the desktop's own
        // faces let go of keys that are not theirs — they
        // are not saved up to ambush the guest when the
        // room comes back), and the answer is no key. Esc
        // is the interrupt's own affair and has usually
        // already asked for the stop before this knock;
        // the drain keeps its word here too.
        guestWindowTend()
        if !guiFocusFeather {
            while let code = nextScancode() {
                if code == 0x01 {
                    cardnullSetStopRequest(1)
                } else if code == 0xE0 {
                    guestKeyExtended = true
                } else {
                    guestKeyExtended = false
                }
            }
            return 0
        }
    }
    while let code = nextScancode() {
        if code == 0x01 {
            cardnullSetStopRequest(1)
            return 0
        }
        if guestKeyExtended {
            guestKeyExtended = false
            continue
        }
        if code == 0xE0 {
            guestKeyExtended = true
            continue
        }
        switch code {
        case 0x2A, 0x36:            // Shift pressed: the guest's own
            guestKeyShift = true
        case 0xAA, 0xB6:            // Shift released
            guestKeyShift = false
        case 0x3A:                  // Caps Lock: the guest's latch
            guestKeyCaps = !guestKeyCaps
        case 0x1C:                  // Enter
            return 0x0A
        case 0x0E:                  // Backspace
            return 0x08
        case 0x80 ... 0xFF:         // any other release: not a key
            continue
        default:
            let shellShift = shiftHeld
            let shellCaps = capsLock
            shiftHeld = guestKeyShift
            capsLock = guestKeyCaps
            let character = ascii(forScancode: code)
            shiftHeld = shellShift
            capsLock = shellCaps
            if character != 0 {
                return UInt64(character)
            }
        }
    }
    return 0
}

/// Service 8, the mouse's word: the ring is drained and its
/// bytes made packets of, with the face's own discipline —
/// three bytes to a packet (four from a wheel mouse,
/// milestone 26), the first carrying bit 3, a byte without
/// it let go — the travels signed by the first byte's flags,
/// the screen's down reckoned against the mouse's up,
/// the place clamped to the screen, and the last whole
/// packet's buttons kept. The answer packs the reckoning:
/// the x place in the low word, the y above it, the buttons
/// above that (bit 0 the left, bit 1 the right, bit 2 the
/// middle), and — since milestone 26 — the wheel's turning
/// in the byte above them (bits 40–47): the signed sum of
/// every turning since the guest last asked, positive
/// turned up toward older lines, negative down; the asking
/// spends it, so the next answer hears only what has turned
/// since. Between polls the bytes wait in the ring; a guest
/// that never polls simply never hears them, and the ring's
/// own fullness lets old news go, as it does for the face.
func guestMousePoll() -> UInt64 {
    if guestWindowed {
        // Windowed (milestone 25): the reckoning answered
        // is the desktop's own pointer — tended first, so
        // the answer is the pointer as it stands now — in
        // the canvas's own coordinates: the pointer minus
        // the canvas's origin, each way packed as a signed
        // sixteen-bit word, so a pointer left or above the
        // window answers honestly negative rather than
        // clamped into a lie. The buttons ride the third
        // word only while the pointer stands over the
        // canvas; outside it they answer 0 — a click out
        // there belongs to the desktop, never to the
        // guest. The session's own second reckoning (the
        // keeping below) is the full-screen road's and is
        // not touched here. The wheel word (milestone 26)
        // is the turning the face's assembly gathered
        // while the pointer stood over the canvas; the
        // tending above may have added to it, and the
        // asking spends it, as on the full-screen road.
        guestWindowTend()
        let relX = pointerX - guestCanvasOriginX()
        let relY = pointerY - guestCanvasOriginY()
        var buttons: UInt64 = 0
        if pointerOverGuestCanvas() {
            buttons = UInt64(mouseFirstByte & 0x07)
        }
        let wheel = UInt64(UInt8(bitPattern:
            Int8(clamping: guestWheelAccum)))
        guestWheelAccum = 0
        return UInt64(UInt16(bitPattern: Int16(relX)))
            | UInt64(UInt16(bitPattern: Int16(relY))) << 16
            | buttons << 32
            | wheel << 40
    }
    while let byte = nextMouseByte() {
        if guestMouseStage == 0 {
            if byte & 0x08 == 0 { continue }
            guestMouseFirst = byte
            guestMouseStage = 1
        } else if guestMouseStage == 1 {
            guestMouseSecond = byte
            guestMouseStage = 2
        } else if guestMouseStage == 2 {
            guestMouseThird = byte
            if mousePacketLength == 4 {
                guestMouseStage = 3
                continue
            }
            guestMouseStage = 0
            guestFinishMousePacket(0)
        } else {
            guestMouseStage = 0
            // The turning reckoned the reader's way, as
            // on the face's road: the byte counts a turn
            // away from the hand as a negative step, and
            // the guest is told of turnings, not bytes.
            guestFinishMousePacket(
                -Int(Int8(bitPattern: byte)))
        }
    }
    let wheel = UInt64(UInt8(bitPattern:
        Int8(clamping: guestWheelAccum)))
    guestWheelAccum = 0
    return UInt64(guestMouseX) | UInt64(guestMouseY) << 16
        | guestMouseButtons << 32
        | wheel << 40
}

/// A whole packet is answered on the full-screen road: the
/// travels reckoned and clamped, the buttons kept, and a
/// wheel byte's turning added to the gathering the next
/// poll will answer (milestone 26).
func guestFinishMousePacket(_ wheelDelta: Int) {
    var travelX = Int(guestMouseSecond)
    if guestMouseFirst & 0x10 != 0 { travelX -= 256 }
    var travelY = Int(guestMouseThird)
    if guestMouseFirst & 0x20 != 0 { travelY -= 256 }
    guestMouseX = min(max(guestMouseX + travelX, 0),
                      framebufferWidth - 1)
    guestMouseY = min(max(guestMouseY - travelY, 0),
                      framebufferHeight - 1)
    guestMouseButtons = UInt64(guestMouseFirst & 0x07)
    if wheelDelta != 0 {
        guestWheelAccum = min(max(guestWheelAccum + wheelDelta,
                                  -128), 127)
    }
}

