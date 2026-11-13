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
// The bundle (milestone 23): the kernel carries its files in
// memory.
//
// The disc above is a CD, and a stick is not a CD. This section
// teaches the kernel a second source for the system's own files:
// one bundle file — the welcome, every guest program, every
// feather, the very set the disc's root carries for the system —
// handed over by the bootloader as a Multiboot2 module (tag
// type 3) and served out of the memory it rode in on. The format
// is written down in docs/BUNDLE.md; the packer is
// tools/pack-bundle.py, and it assembles the bundle from the
// ISO staging itself, guarding the agreement both ways, so the
// bundle and the disc can never silently disagree about
// contents.
//
// The serving rule, stated once and kept everywhere: a valid
// bundle rides, the bundle serves — `ls`, `cat`, `run`, `both`,
// `feather`, the Files window's list and its Reader, and the
// installer's copies all read from memory. No bundle, or a
// bundle that fails its proving, and the disc path serves,
// unchanged in every behavior. The hard disk's world is its
// own: `disk`, `dls`, `dcat`, `dsave`, `format` never read the
// bundle.
//
// The cargo's safety is arranged before it is read: the module
// span the bootloader reports is reserved out of the frame
// allocator's pool in initMemory — the bundle's frames stand in
// `mem`'s used count, never handed to the heap or a guest — and
// the bundle is proven before a byte of it is served: its magic,
// its table's sanity (every name a plain name, every length
// within the caps, the lengths summing exactly to the payload
// the header declares, and the payload ending exactly at the
// span's end), and its FNV-1a 64 checksum, the house reckoning,
// over the whole payload. A bundle that fails any of it is
// reported in the boot transcript in plain words and never
// served from; the disc serves in its place.
// ---------------------------------------------------------------------------

/// The bundle's caps, stated plainly (docs/BUNDLE.md carries
/// them too): at most 64 files, a name at most 31 letters, one
/// file at most a mebibyte, the whole payload at most sixteen.
let bundleMaxFiles = 64
let bundleMaxName = 31
let bundleMaxFileBytes = 1048576
let bundleMaxPayloadBytes = 16777216

/// The Multiboot2 module's span, read off the module tag
/// (type 3) before the allocator is raised: the start and end
/// the bootloader confessed. Both zero when no module rode.
var bootModuleStart: UInt64 = 0
var bootModuleEnd: UInt64 = 0

/// Did a bundle ride, and did it prove sound? Until the proving
/// runs, both are false and the disc serves, as it always has.
var bundlePresent = false
var bundleValid = false

/// The proven bundle's measure: how many files its table
/// holds, and where its payload begins, counted in bytes from
/// the span's first byte.
var bundleFileCount = 0
var bundlePayloadStart = 0

/// The resolution's source, set beside resolvedExtent and its
/// kin by whichever resolver answered: true when the bundle
/// answered, with resolvedOffset holding the file's place in
//  the bundle (a byte offset from the span's start); false
/// when the disc answered, with resolvedExtent holding its
/// sector, as it has since milestone 8.
var resolvedFromBundle = false
var resolvedOffset: UInt32 = 0

/// One bundle entry's facts, as the walkers below find them,
/// kept in globals in the disc section's manner: the name's
/// place and length within the span, the file's offset from
/// the span's start, and its length in bytes.
var bundleEntryFound = false
var bundleEntryNameOffset = 0
var bundleEntryNameLength = 0
var bundleEntryOffset: UInt32 = 0
var bundleEntryLength: UInt32 = 0

/// Reads the Multiboot2 module tag (type 3), if the bootloader
/// left one: the span the bundle rides in. Called from kmain
/// before initMemory, so the allocator can reserve the cargo
/// out of its pool; the proving itself waits until the house
/// stands (validateBundle, below).
func noteBootModule(_ infoAddress: UInt64) {
    if infoAddress == 0 { return }
    let tagOffset = findTagOffset(3, infoAddress: infoAddress)
    if tagOffset < 0 { return }
    let base = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(infoAddress))!
    let start = bootInfoU32(base, tagOffset + 8)
    let end = bootInfoU32(base, tagOffset + 16 - 4)
    if end > start {
        bootModuleStart = UInt64(start)
        bootModuleEnd = UInt64(end)
        bundlePresent = true
    }
}

/// The bundle's first byte, as a pointer: the span stands in
/// the identity map, read the way the Multiboot2 information
/// itself is read. Only called when a module rode.
@inline(__always)
func bundleBase() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(bootModuleStart))!
}

/// The span's whole length in bytes.
@inline(__always)
func bundleSpanLength() -> Int {
    Int(bootModuleEnd - bootModuleStart)
}

/// The end of the line standing at `from`: the offset of its
/// newline, or -1 when the span ends first. Bundle lines never
/// run past a sane measure either — a line longer than 96
/// bytes is no line of this format's, and answers -1 as well.
func bundleLineEnd(_ from: Int) -> Int {
    let base = bundleBase()
    let limit = bundleSpanLength()
    var index = from
    while index < limit && index - from <= 96 {
        if base[index] == 0x0A { return index }
        index += 1
    }
    return -1
}

/// Does the line at `from` say exactly the given word?
func bundleLineIs(_ from: Int, _ end: Int,
                  _ word: StaticString) -> Bool {
    let base = bundleBase()
    var index = 0
    while word.utf8Start[index] != 0 {
        if from + index >= end { return false }
        if base[from + index] != word.utf8Start[index] {
            return false
        }
        index += 1
    }
    return from + index == end
}

/// Does the line at `from` open with the given key — the
/// header's reckoned lines wear theirs as "files: ", the word
/// and its space both?
func bundleLineOpens(_ from: Int, _ end: Int,
                     _ key: StaticString) -> Bool {
    let base = bundleBase()
    var index = 0
    while key.utf8Start[index] != 0 {
        if from + index >= end { return false }
        if base[from + index] != key.utf8Start[index] {
            return false
        }
        index += 1
    }
    return true
}

/// Reads a decimal number out of the bundle between two
/// offsets: the digits' value, or -1 when any byte there is
/// not a digit, or the reach is empty, or the number grows
/// past a whole payload's measure — no honest field of this
/// format is larger.
func bundleParseDecimal(_ from: Int, _ end: Int) -> Int {
    if end <= from { return -1 }
    let base = bundleBase()
    var value = 0
    var index = from
    while index < end {
        let byte = base[index]
        if byte < 0x30 || byte > 0x39 { return -1 }
        value = value * 10 + Int(byte - 0x30)
        if value > bundleMaxPayloadBytes { return -1 }
        index += 1
    }
    return value
}

/// Reads a sixteen-digit hexadecimal reckoning — the
/// checksum's shape on its line. The digits are the lowercase
/// the packer writes; capital letters are forgiven, as the
/// shell forgives them. False when the reach is not exactly
/// sixteen hex digits.
var bundleHexValue: UInt64 = 0

func bundleParseHex(_ from: Int, _ end: Int) -> Bool {
    if end - from != 16 { return false }
    let base = bundleBase()
    var value: UInt64 = 0
    var index = from
    while index < end {
        let byte = base[index]
        var digit: UInt64 = 0
        if byte >= 0x30 && byte <= 0x39 {
            digit = UInt64(byte - 0x30)
        } else if byte >= 0x61 && byte <= 0x66 {
            digit = UInt64(byte - 0x61) + 10
        } else if byte >= 0x41 && byte <= 0x46 {
            digit = UInt64(byte - 0x41) + 10
        } else {
            return false
        }
        value = value << 4 | digit
        index += 1
    }
    bundleHexValue = value
    return true
}

/// The FNV-1a 64 reckoning over one reach of the bundle —
/// the feather's own checksum, the same offset and prime,
/// folded here over bytes standing in memory.
func bundleChecksum(_ from: Int, _ length: Int) -> UInt64 {
    let base = bundleBase()
    var hash: UInt64 = 0xCBF29CE484222325
    var index = 0
    while index < length {
        hash ^= UInt64(base[from + index])
        hash = hash &* 0x100000001B3
        index += 1
    }
    return hash
}

/// Is this byte a lawful bundle name letter? Names are the
/// disc's own kind: capitals, digits, and the punctuation a
/// filename honestly wears — anything printable but a space
/// (the table's own separator) and a slash (the path's).
func bundleNameByte(_ byte: UInt8) -> Bool {
    byte > 0x20 && byte < 0x7F && byte != 0x2F
}

/// Walks the bundle's entry table to the entry at the given
/// place and leaves its facts in the bundle entry globals.
/// The walk re-reads the header every time — the table is
/// short, the walk is cheap, and no second keeping of it can
/// drift from the bytes. False when the header does not parse
/// or the table has no such entry; validateBundle proves the
/// whole shape at boot, so a false here after a true proving
/// is not expected — but the walkers answer plainly rather
/// than trust.
func bundleEntryAt(_ wanted: Int) -> Bool {
    bundleEntryFound = false
    if !bundlePresent { return false }
    let base = bundleBase()
    let limit = bundleSpanLength()
    var lineStart = 0
    var lineEnd = bundleLineEnd(lineStart)
    if lineEnd < 0 || !bundleLineIs(lineStart, lineEnd,
                                    bundleMagicLine) {
        return false
    }
    // The three reckoned lines, passed over here — the
    // proving already read them with care.
    var step = 0
    while step < 3 {
        lineStart = lineEnd + 1
        lineEnd = bundleLineEnd(lineStart)
        if lineEnd < 0 { return false }
        step += 1
    }
    var payloadOffset = 0
    var index = 0
    while true {
        lineStart = lineEnd + 1
        lineEnd = bundleLineEnd(lineStart)
        if lineEnd < 0 { return false }
        if bundleLineIs(lineStart, lineEnd, bundleSeparatorLine) {
            return false   // the table ended before the entry
        }
        // The entry line: a name, one space, a length.
        var space = lineStart
        while space < lineEnd && base[space] != 0x20 {
            space += 1
        }
        if space >= lineEnd { return false }
        let length = bundleParseDecimal(space + 1, lineEnd)
        if length < 0 { return false }
        if index == wanted {
            bundleEntryNameOffset = lineStart
            bundleEntryNameLength = space - lineStart
            bundleEntryOffset = UInt32(bundlePayloadStart
                                       + payloadOffset)
            bundleEntryLength = UInt32(length)
            bundleEntryFound = true
            return true
        }
        payloadOffset += length
        index += 1
        if payloadOffset > limit { return false }
    }
}

/// The proving's scratch, beside bundleHexValue: the
/// payload's declared byte count, kept as it was proven.
var bundleDeclaredBytes = 0

/// Proves the bundle, at boot, before a byte of it is served:
/// the magic line; the three reckoned lines (the file count
/// within its cap, the payload's byte count within its cap,
/// the checksum in its shape); the entry table (every name
/// a plain name within its cap, every length within its
/// cap, the lengths summing exactly to the declared payload);
/// the payload ending exactly at the span's end; and the
/// checksum itself, folded over the whole payload and
/// matched against the header's word. Any failure leaves
/// bundleValid false, and the disc serves.
func validateBundle() {
    if !bundlePresent { return }
    let base = bundleBase()
    let limit = bundleSpanLength()
    if limit < 32 { return }
    var lineStart = 0
    var lineEnd = bundleLineEnd(lineStart)
    if lineEnd < 0 || !bundleLineIs(lineStart, lineEnd,
                                    bundleMagicLine) {
        return
    }
    // files: N
    lineStart = lineEnd + 1
    lineEnd = bundleLineEnd(lineStart)
    if lineEnd < 0 || !bundleLineOpens(lineStart, lineEnd,
                                       bundleFilesKey) {
        return
    }
    let count = bundleParseDecimal(lineStart + 7, lineEnd)
    if count < 1 || count > bundleMaxFiles { return }
    // bytes: B
    lineStart = lineEnd + 1
    lineEnd = bundleLineEnd(lineStart)
    if lineEnd < 0 || !bundleLineOpens(lineStart, lineEnd,
                                       bundleBytesKey) {
        return
    }
    let payloadBytes = bundleParseDecimal(lineStart + 7, lineEnd)
    if payloadBytes < 0 || payloadBytes > bundleMaxPayloadBytes {
        return
    }
    // checksum: HHHHHHHHHHHHHHHH
    lineStart = lineEnd + 1
    lineEnd = bundleLineEnd(lineStart)
    if lineEnd < 0 || !bundleLineOpens(lineStart, lineEnd,
                                       bundleChecksumKey) {
        return
    }
    if !bundleParseHex(lineStart + 10, lineEnd) { return }
    let declaredChecksum = bundleHexValue
    // The entry table: count lines of name and length.
    var sum = 0
    var index = 0
    while index < count {
        lineStart = lineEnd + 1
        lineEnd = bundleLineEnd(lineStart)
        if lineEnd < 0 { return }
        if bundleLineIs(lineStart, lineEnd,
                        bundleSeparatorLine) {
            return   // the table ended short of its count
        }
        var space = lineStart
        while space < lineEnd && base[space] != 0x20 {
            space += 1
        }
        if space >= lineEnd { return }
        let nameLength = space - lineStart
        if nameLength < 1 || nameLength > bundleMaxName {
            return
        }
        var nameIndex = lineStart
        while nameIndex < space {
            if !bundleNameByte(base[nameIndex]) { return }
            nameIndex += 1
        }
        let length = bundleParseDecimal(space + 1, lineEnd)
        if length < 0 || length > bundleMaxFileBytes {
            return
        }
        sum += length
        index += 1
    }
    if sum != payloadBytes { return }
    // The separator, then the payload, ending at the span's
    // own end — not a byte short, not a byte over.
    lineStart = lineEnd + 1
    lineEnd = bundleLineEnd(lineStart)
    if lineEnd < 0 || !bundleLineIs(lineStart, lineEnd,
                                    bundleSeparatorLine) {
        return
    }
    let payloadStart = lineEnd + 1
    if payloadStart + payloadBytes != limit { return }
    if bundleChecksum(payloadStart, payloadBytes)
        != declaredChecksum {
        return
    }
    bundleDeclaredBytes = payloadBytes
    bundlePayloadStart = payloadStart
    bundleFileCount = count
    bundleValid = true
}

/// Finds one name in the bundle's table: the component held
/// in the path scratch, matched letter for letter with case
/// folded, the way the disc's finder matches — the bundle's
/// names carry no version suffix to forgive. The facts land
/// in the bundle entry globals.
func bundleFindEntry(_ componentStart: Int,
                     _ componentLength: Int) -> Bool {
    bundleEntryFound = false
    if !bundleValid { return false }
    let path = discPath()
    let base = bundleBase()
    var index = 0
    while index < bundleFileCount {
        if !bundleEntryAt(index) { return false }
        if bundleEntryNameLength == componentLength {
            var matched = true
            var at = 0
            while at < componentLength {
                var bundleByte = base[bundleEntryNameOffset + at]
                var pathByte = path[componentStart + at]
                if bundleByte >= 0x61 && bundleByte <= 0x7A {
                    bundleByte -= 0x20
                }
                if pathByte >= 0x61 && pathByte <= 0x7A {
                    pathByte -= 0x20
                }
                if bundleByte != pathByte {
                    matched = false
                    break
                }
                at += 1
            }
            if matched {
                bundleEntryFound = true
                return true
            }
        }
        index += 1
    }
    return false
}

/// The bundle's resolver, a flat twin of milestone 8's walk:
/// the bundle holds one root and no directories, so a path
/// resolves by its first component alone — found, and it is
/// a file; found with more path beyond it, and the answer is
/// "not a directory"; missing, and the answer is missing; an
/// empty path is the root itself. The outcome codes are the
/// disc walk's own, and the resolved globals take the file's
/// bundle offset and size, with resolvedFromBundle set.
func bundleResolvePathIn(_ start: Int, _ end: Int) -> Int {
    let path = discPath()
    resolvedExtent = 0
    resolvedOffset = 0
    resolvedSize = 0
    resolvedIsDirectory = true
    resolvedFromBundle = true
    lastComponentStart = 0
    lastComponentLength = 0
    var index = start
    while index < end && path[index] == 0x2F { index += 1 }
    if index >= end { return pathFoundCode }
    let componentStart = index
    while index < end && path[index] != 0x2F { index += 1 }
    let componentLength = index - componentStart
    lastComponentStart = componentStart
    lastComponentLength = componentLength
    if !bundleFindEntry(componentStart, componentLength) {
        return pathMissingCode
    }
    var next = index
    while next < end && path[next] == 0x2F { next += 1 }
    if next < end { return pathNotDirectoryCode }
    resolvedOffset = bundleEntryOffset
    resolvedSize = bundleEntryLength
    resolvedIsDirectory = false
    return pathFoundCode
}

/// The one resolver every file command now knocks at: the
/// bundle when a proven bundle rides, the disc's walk in its
/// own words otherwise — milestone 8's resolver untouched
/// beneath, so the disc's behavior is the disc's, exactly.
func serveResolvePath(_ length: Int) -> Int {
    if bundleValid { return bundleResolvePathIn(0, length) }
    resolvedFromBundle = false
    return isoResolvePath(length)
}

/// The reach form, for `both`'s two paths in the one scratch.
func serveResolvePathIn(_ start: Int, _ end: Int) -> Int {
    if bundleValid { return bundleResolvePathIn(start, end) }
    resolvedFromBundle = false
    return isoResolvePathIn(start, end)
}

/// Does the file world answer at all, and through which
/// door? The bundle's presence answers for itself; otherwise
/// the disc's two standings answer in their standing words,
/// exactly as each command answered before this stone.
func filesReady() -> Bool {
    if bundleValid { return true }
    if !discDriveFound {
        writeLine(discAbsentLine)
        return false
    }
    if !discIsoFound {
        writeLine(discUnknownFsLine)
        return false
    }
    return true
}

/// Reads one sector's measure of the file the identity
/// names — the chunk at the given index — into the disc
/// buffer every reader shares, so `cat`, the program loader,
/// the feather reader, and the Files window's Reader all
/// drink from the one cup whichever source serves. From the
/// disc it is the sector reader's own call, the extent plus
/// the index, unchanged. From the bundle it is a copying out
/// of memory: the chunk's true bytes, and zeros past the
/// file's end to the sector's measure, so no stale byte of
/// an earlier reading can be mistaken for the file's own.
func serveReadChunk(_ fromBundle: Bool, _ discExtent: UInt32,
                    _ bundleOffset: UInt32, _ fileSize: UInt32,
                    _ chunkIndex: UInt32) -> Bool {
    if !fromBundle {
        return discReadSector(discExtent + chunkIndex)
    }
    if !bundleValid { return false }
    let buffer = discBuffer()
    let start = UInt64(chunkIndex) * UInt64(discSectorBytes)
    if start >= UInt64(fileSize) {
        var index = 0
        while index < discSectorBytes {
            buffer[index] = 0
            index += 1
        }
        return true
    }
    let base = bundleBase()
    let source = Int(bundleOffset) + Int(start)
    var count = Int(fileSize) - Int(start)
    if count > discSectorBytes { count = discSectorBytes }
    var index = 0
    while index < count {
        buffer[index] = base[source + index]
        index += 1
    }
    while index < discSectorBytes {
        buffer[index] = 0
        index += 1
    }
    return true
}

/// The bundle's header words and the serving layer's
/// sentences.
let bundleMagicLine: StaticString = "CARDNULL FILES 1"
let bundleFilesKey: StaticString = "files: "
let bundleBytesKey: StaticString = "bytes: "
let bundleChecksumKey: StaticString = "checksum: "
let bundleSeparatorLine: StaticString = "---"
let bundleListPrefix: StaticString = "Bundle "
let notInBundlePrefix: StaticString = "Not in the bundle: "
let filesCarriedPrefix: StaticString =
    "Files: carried in memory - "
let bundleOneFileSuffix: StaticString = " file in the bundle."
let bundleFilesSuffix: StaticString = " files in the bundle."
let filesDiscLine: StaticString = "Files: read from the disc."
let bundleUnsoundLine: StaticString =
    "A bundle of files rode with the boot, but it is not sound. The disc will serve the files."

/// The missing-file prefix of whichever world is serving:
/// the disc's standing words when the disc serves, the
/// bundle's when the bundle does — a file is answered as
/// missing from the place that was actually searched.
func writeNotHerePrefix() {
    if bundleValid {
        writeStatic(notInBundlePrefix)
    } else {
        writeStatic(notOnDiscPrefix)
    }
}

/// The source sentence, spoken by `about` and at the boot:
/// the bundle's account when a proven bundle serves, the
/// disc's when it does.
func printFilesSourceLine() {
    if bundleValid {
        writeStatic(filesCarriedPrefix)
        writeNumber(UInt64(bundleFileCount))
        writeLine(bundleFileCount == 1 ? bundleOneFileSuffix
                                       : bundleFilesSuffix)
    } else {
        writeLine(filesDiscLine)
    }
}

/// The boot transcript's bundle news, spoken from kmain
/// after the disc's report: the source sentence when the
/// bundle proved sound; the plain confession, and the
/// fall-back, when one rode but did not prove; and silence
/// when none rode — a boot without a bundle is milestone
/// 22's boot, word for word.
func printBundleReport() {
    if bundleValid {
        printFilesSourceLine()
    } else if bundlePresent {
        writeLine(bundleUnsoundLine)
    }
}

/// Prints one bundle entry for `ls`: two spaces, the name as
/// the bundle keeps it, padding to the listing's modest
/// column, and its size — printDirectoryEntry's twin, for a
/// table that stands in memory instead of on a disc. Every
/// bundle entry is a file; the bundle holds no directories.
func printBundleEntry() {
    let base = bundleBase()
    writeChar(0x20)
    writeChar(0x20)
    var index = 0
    while index < bundleEntryNameLength {
        writeChar(base[bundleEntryNameOffset + index])
        index += 1
    }
    var padding = 14 - bundleEntryNameLength
    if padding < 1 { padding = 1 }
    while padding > 0 {
        writeChar(0x20)
        padding -= 1
    }
    writeNumber(UInt64(bundleEntryLength))
    writeNewline()
}

/// `ls`'s work on the bundle: the header naming the source
/// and the root, then every entry the table holds.
func listBundleDirectory() {
    writeStatic(bundleListPrefix)
    writeChar(0x2F)
    writeLine(lsHeaderSuffix)
    if bundleFileCount == 0 {
        writeLine(lsEmptyLine)
        return
    }
    var index = 0
    while index < bundleFileCount {
        if bundleEntryAt(index) {
            printBundleEntry()
        }
        index += 1
    }
}
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
// The keeping was cooperative, honestly — in this milestone. A
// guest that never yielded kept the machine: the timer ticked,
// but no hand answered it with a switch. Milestone 15 is the
// stone that superseded the keeping, and it stands in the
// floor, not here: the timer now cuts ten-tick slices out of a
// running guest and hands the machine to its partner whether
// the guest knocks or not, SPIN.BIN is the witness that a guest
// can no longer keep the machine, and Esc ends a session whose
// guests will not. What this section's code gained from it is
// only the session's speech: the guidance line every launch
// prints and the switch counts the pair's report closes with.
// Two guests exactly, likewise, still: the books are two, and
// no process table is pretended. And the wall stands under
// company as it stood alone — the page fault's pair road stops
// the guest that fell and carries the machine to its partner,
// which finishes its work in its own ground, undisturbed;
// `both /BAD.BIN /A.BIN` is the proof, BAD stopped at the wall
// and A counting out its five tokens in the same session.
