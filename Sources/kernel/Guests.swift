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

/// The estate's fixed address: the guests' whole world begins here.
/// Its place in the tables is chosen to sit under the first branch
/// of every level — root 0, pointer table 1, directory 0 — ground
/// the kernel's own map leaves empty.
let programBase: UInt64 = 0x4000_0000

/// The scratch page's place in the estate's page table, and the
/// stack pages': the image fills the indices below the scratch,
/// so a guest's estate has the same shape whatever its size.
let programScratchIndex = 16
let programStackFirstIndex = 17
let programStackPages = 4

/// The stack's top: one past the stack's last page — the address
/// the guest is entered with in its stack pointer.
let programStackTop: UInt64 =
    programBase + UInt64(programStackFirstIndex + programStackPages) * pageSize

/// The estate's end: everything a guest may touch lies beneath it,
/// and the service door checks every address against this bound.
let programEstateTop: UInt64 = programStackTop

/// The largest image a guest may be: sixteen pages, 64 KiB. The
/// sample guests are two hundred bytes on their proudest day; the
/// cap exists so `run` can refuse plainly, not so it will be met.
let programMaxImageBytes: UInt64 = 16 * pageSize

/// Is a guest running? The page-fault handler reads this to choose
/// its road: while it stands, a user-mode fault is a guest's fall,
/// to be reported and stopped; without it, every fault keeps the
/// old road to the halt.
var programRunning = false

/// Is the running guest one of a pair (milestone 10)? The page-
/// fault handler reads this beside programRunning: while it
/// stands, a fallen guest is stopped by the floor's pair road,
/// which carries the machine to its partner instead of home.
var pairRunning = false

/// The standings the floor writes in a finished guest's book, and
/// copies into its result bookmarks for the shell to read: a
/// guest that left by the door, and a guest that was stopped.
/// (0, still alive, is the standing of a guest mid-session and is
/// never read here: the pair launch returns only when neither
/// guest wears it.)
let pairStatusExited: UInt64 = 1
let pairStatusStopped: UInt64 = 2

/// The two paths of a `both` line, as reaches of the one path
/// scratch: the first path is the bytes before bothFirstEnd, the
/// second the bytes from bothSecondStart to bothSecondEnd. The
/// splitter below leaves them; the resolver, the report and the
/// running line read them.
var bothFirstEnd = 0
var bothSecondStart = 0
var bothSecondEnd = 0

/// both's vocabulary: the usage, the running line's joints, and
/// the two reports — a leaving spoken with its code, a stopping
/// spoken plainly — each beside the path as it was typed.
let bothUsageLine: StaticString =
    "both wants two programs: both /A.BIN /B.BIN"
let bothAndWord: StaticString = " and "
let bothTogetherSuffix: StaticString = " together:"
let bothExitedWord: StaticString = " exited: "
let bothStoppedSuffix: StaticString = " was stopped."

/// Milestone 15's vocabulary: the guidance every session opens
/// with — run, both, and feather alike, since any of them can
/// hold a guest that never ends — and the pair report's closing
/// line, which speaks the session's two switch counts beside
/// each other: the turns taken at the door (yields and
/// hand-overs) and the turns taken by the timer (slices spent).
/// Both numbers are the floor's own keepings, read once the
/// launch has returned.
let sessionStopLine: StaticString = "Press Esc to stop the session."
let bothSwitchesPrefix: StaticString = "Switches: "
let bothSwitchesDoorWord: StaticString = " by the door, "
let bothSwitchesTimerWord: StaticString = " by the timer."

/// The stopped guest's testimony, kept by the fault handler before
/// the abandon: the address it reached for and the error code's
/// word. The shell does not speak them — the report already stands
/// at the screen's top — but they are kept, because a stopping
/// should leave its facts where they can be read.
var programFaultAddress: UInt64 = 0
var programFaultError: UInt64 = 0

/// The verdict of a stopped guest: all ones — a value no honest
/// exit code is mistaken for, since the guests' door carries the
/// code in a register the shell reads whole. `run` answers this
/// verdict with the stopping's words, any other with the code.
let programKilledVerdict: UInt64 = 0xFFFF_FFFF_FFFF_FFFF

/// The live guest's page table address, remembered between the
/// building of its estate and the reading of its image off the
/// disc: the loader copies the file's bytes into the very frames
/// the table names.
var programTableAddress: UInt64 = 0

/// run's vocabulary: the usage, the refusals, and the two reports.
let runUsageLine: StaticString = "run wants a program: run /HELLO.BIN"
let runNoPagingLine: StaticString =
    "Paging is not standing; a guest needs the kernel's own tables."
let runEmptySuffix: StaticString = " is empty; there is nothing to run."
let runTooBigLine: StaticString =
    "That file is larger than the ground a guest may have (64 KiB)."
let runNoMemoryLine: StaticString =
    "Memory could not pay for the guest's ground."
let runRunningPrefix: StaticString = "Running "
let runRunningSuffix: StaticString = ":"
let programExitedPrefix: StaticString = "Program exited: "
let programKilledLine: StaticString =
    "The guest was stopped. The shell stands."

/// Wipes one frame clean, byte by byte — the guest's image frames
/// and desk and stack begin zeroed, so no byte of a previous
/// tenant, or of the pool's past, is part of a guest's world.
func wipeFrame(_ frame: UInt64) {
    let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(frame))!
    for index in 0 ..< Int(pageSize) {
        bytes[index] = 0
    }
}

/// Builds a guest's estate: its own page tables, cloned from the
/// kernel's and branched privately toward the estate, with the
/// image's pages, the scratch page and the stack pages laid in as
/// fresh frames under the laws the section header states. Returns
/// the estate's root on success; on any failure of the pool to
/// pay, takes back whatever was built and returns 0.
func buildProgramSpace(_ size: UInt32) -> UInt64 {
    let imagePages = Int((UInt64(size) + pageSize - 1) / pageSize)
    let root = pagingNewTable()
    if root == 0 { return 0 }
    let kernelRoot = pagingRootAddress
    for index in 0 ..< 512 {
        setPagingEntry(root, index, pagingEntry(kernelRoot, index))
    }
    let kernelPointerTable =
        pagingEntry(kernelRoot, 0) & pagingAddressMask
    let pointerTable = pagingNewTable()
    if pointerTable == 0 {
        freeFrame(root)
        return 0
    }
    for index in 0 ..< 512 {
        setPagingEntry(pointerTable, index,
                       pagingEntry(kernelPointerTable, index))
    }
    // The one branch opened to ring 3 above the estate: the root's
    // first entry now names the guest's own pointer table, under
    // the kernel entry's own flags with the user bit added. Every
    // other entry in both cloned tables still speaks with the
    // kernel's voice, so the ground behind them stays shut.
    setPagingEntry(root, 0,
                   pointerTable
                       | (pagingEntry(kernelRoot, 0) & 0xFFF)
                       | pteUser)
    let directory = pagingNewTable()
    if directory == 0 {
        teardownProgramSpace(root)
        return 0
    }
    setPagingEntry(pointerTable, 1,
                   directory | ptePresent | pteWritable | pteUser)
    let table = pagingNewTable()
    if table == 0 {
        teardownProgramSpace(root)
        return 0
    }
    setPagingEntry(directory, 0,
                   table | ptePresent | pteWritable | pteUser)
    programTableAddress = table
    var index = 0
    while index < imagePages {
        let frame = allocFrame()
        if frame == 0 {
            teardownProgramSpace(root)
            return 0
        }
        wipeFrame(frame)
        // The image: readable and executable, never writable —
        // and readable because a flat guest keeps its words in
        // its image, as the samples keep their greetings.
        setPagingEntry(table, index, frame | ptePresent | pteUser)
        index += 1
    }
    let scratch = allocFrame()
    if scratch == 0 {
        teardownProgramSpace(root)
        return 0
    }
    wipeFrame(scratch)
    setPagingEntry(table, programScratchIndex,
                   scratch | ptePresent | pteWritable | pteUser
                       | pteNoExecute)
    var stackIndex = 0
    while stackIndex < programStackPages {
        let frame = allocFrame()
        if frame == 0 {
            teardownProgramSpace(root)
            return 0
        }
        wipeFrame(frame)
        setPagingEntry(table, programStackFirstIndex + stackIndex,
                       frame | ptePresent | pteWritable | pteUser
                           | pteNoExecute)
        stackIndex += 1
    }
    return root
}

/// Takes a guest's estate back: every present leaf's frame, then
/// the page table, the directory, the pointer table and the root,
/// each returned to the pool. The shared tables the clones point
/// *into* — the kernel's own branches beneath the copied entries —
/// are never freed: they are recognised by their address, the one
/// pointer table that is not the guest's own. A half-built estate
/// takes the same road home, which is why the builder calls this
/// on its failures.
func teardownProgramSpace(_ root: UInt64) {
    if root == 0 { return }
    let kernelPointerTable =
        pagingEntry(pagingRootAddress, 0) & pagingAddressMask
    let pointerTable = pagingEntry(root, 0) & pagingAddressMask
    if pointerTable != 0 && pointerTable != kernelPointerTable {
        let directory = pagingEntry(pointerTable, 1) & pagingAddressMask
        if directory != 0 {
            let table = pagingEntry(directory, 0) & pagingAddressMask
            if table != 0 {
                for index in 0 ..< 512 {
                    let leaf = pagingEntry(table, index)
                    if leaf & ptePresent != 0 {
                        freeFrame(leaf & pagingAddressMask)
                    }
                }
                freeFrame(table)
            }
            freeFrame(directory)
        }
        freeFrame(pointerTable)
    }
    freeFrame(root)
    programTableAddress = 0
}

/// Reads a guest's image off the disc into the frames its page
/// table names: sector by sector through the milestone-8 driver,
/// byte by byte into the frames — which the kernel's identity map
/// lets it touch by their physical addresses while the guest's
/// own tables are still only a building, not yet the machine's
/// law. False when a sector refuses to be read.
func loadProgramImage(_ fromBundle: Bool, _ extent: UInt32,
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
            let at = written + UInt32(index)
            let frame = pagingEntry(programTableAddress,
                                    Int(at / UInt32(pageSize)))
                & pagingAddressMask
            let destination = UnsafeMutablePointer<UInt8>(
                bitPattern: UInt(frame + UInt64(at % UInt32(pageSize))))!
            destination.pointee = buffer[index]
            index += 1
        }
        written += count
        sectorIndex += 1
    }
    return true
}

/// The service door's answering voice, called by the floor's stub
/// with the guest's registers translated into arguments: the
/// service number, then the guest's rsi, rdx, rcx, r8 and r9 —
/// the last three carried up since milestone 18, whose services
/// take more words than the first suite's two. The answer rides
/// home in the guest's rax. The door's services, as the guests'
/// sources publish them:
///
///   1  write a string — the first argument is the string's
///      address in the guest's ground, the second its length.
///      The whole reach is checked against the estate before a
///      byte is read; refused reaches answer all-ones, the door's
///      no. Bytes are drawn by the screen's own rules, the ones
///      `cat` speaks by: line feeds end lines, tabs step to a
///      space, the undrawable are passed over.
///   2  write one character — the first argument's low byte,
///      under the same drawing rules.
///   4  screen size — the graphical suite (milestone 18), kept
///      in its own section below: the framebuffer's width in
///      the answer's low half and its height in the high half,
///      or 0 when no graphical screen is the guest's to use.
///   5  fill a rectangle — (x, y, width, height, colour) in
///      the five words, drawn clipped to the screen; the
///      answer is 0 when anything of it was drawn and 1 when
///      the ask was refused whole, nothing drawn.
///   6  draw text — (x, y, address, length, colour); the
///      reach proven against the estate with exactly service
///      1's discipline before a byte is read, but where
///      service 1 answers a bad reach with all-ones and lets
///      the guest walk on, this service stops the guest: a
///      feather is never handed a kernel's-eye view of memory
///      it does not own, not even by refusal's implication.
///      The answer is the count drawn, capped at 256.
///   7  read a key — the next key waiting for the guest, as a
///      character (Enter answers 0x0A, Backspace 0x08), or 0
///      when none waits. Esc is never the answer: it is the
///      user's key, and milestone 15's stop stands armed.
///   8  poll the mouse — the session's own reckoning of the
///      pointer: x, then y, then the buttons, packed into
///      the answer's words; all-ones when it is not the
///      guest's to ask. In a windowed session (milestone
///      25) the reckoning is the desktop's own pointer, the
///      words signed and relative to the window's canvas,
///      and the buttons the guest's only while the pointer
///      stands over that canvas. Since milestone 26 the
///      answer's fourth word (bits 40–47) carries the
///      wheel's turning since the guest last asked, signed,
///      spent by the asking.
///   9  window standing (milestone 25) — the guest's news
///      of its window: bit 0, a repaint is owed (the kernel
///      has painted over the guest's canvas — the window
///      opened, moved, was covered or uncovered — and the
///      guest must paint its whole face again; asking
///      clears the owing); bit 1, the guest's face holds
///      the room (its keys are live); bit 2, the pointer
///      stands over the guest's ground. A full-screen
///      session answers bits 1 and 2 standing and bit 0
///      owed once, at the claim — one contract for both
///      roads. All-ones in a pair, like the mouse's no.
///   10 read a file (milestone 31) — (name address, name
///      length, destination address, destination room):
///      the named file off the Cardnull disk, copied to the
///      destination, its byte count the answer. Both reaches
///      are proven against the estate before a byte of them
///      is read — the name's at the knock, the destination's
///      for exactly the file's length once the directory has
///      been read. The all-ones family answers the refusals:
///      all-ones a bad reach or a bad name, one less no
///      ready disk, two less the name not standing, three
///      less the file longer than one sector (512 bytes, the
///      keeping's honest size) or than the room offered —
///      refused whole, nothing copied.
///   11 write a file (milestone 31) — (name address, name
///      length, source address, byte count, the count no
///      more than 512): a new file on the Cardnull disk,
///      written by hdCreateFile in milestone 31's section.
///      There is no overwrite and no signature, as the
///      format has neither. The answer is 0, or the
///      all-ones family: all-ones a bad reach, a bad name
///      or a count past the bound, one less no ready disk,
///      two less the name already standing, four less no
///      room.
///   Anything else: not a service; the answer is all-ones.
///
/// There is no sound service, and the absence is deliberate:
/// the speaker is the kernel's own voice for now (milestone
/// 17's `sound` command plays its phrase from ring 0), and a
/// service that would let a guest — a feather — sing is
/// future work. The door takes no number for it yet, and a
/// guest asking for one hears the same all-ones no as any
/// other unknown service.
///
/// Service 0, the leaving, never arrives here: the floor answers
/// it, because coming home is stacks and table roots, not policy.
/// Service 3, the yielding (milestone 10), never arrives either,
/// for the same reason: whose turn it is is books and table
/// roots. What reaches this voice is speech — services 1 and 2 —
/// the graphical suite — services 4 to 9, answered by
/// graphicalService in milestone 18's section below — the
/// file services — 10 and 11, answered in milestone 31's
/// section below — and anything else, which is answered no.
@_cdecl("cardnull_syscall_handler")
public func syscallHandler(_ service: UInt64, _ first: UInt64,
                           _ second: UInt64, _ third: UInt64,
                           _ fourth: UInt64, _ fifth: UInt64) -> UInt64 {
    if service == 1 {
        if first < programBase { return UInt64.max }
        let offset = first - programBase
        if second > programEstateTop - programBase { return UInt64.max }
        if offset > (programEstateTop - programBase) - second {
            return UInt64.max
        }
        var index: UInt64 = 0
        while index < second {
            let byte = UnsafePointer<UInt8>(
                bitPattern: UInt(first + index))!.pointee
            printGuestByte(byte)
            index += 1
        }
        return second
    }
    if service == 2 {
        printGuestByte(UInt8(truncatingIfNeeded: first))
        return 1
    }
    if service == 10 {
        return doorReadFile(first, second, third, fourth)
    }
    if service == 11 {
        return doorWriteFile(first, second, third, fourth)
    }
    if service >= 4 && service <= 9 {
        return graphicalService(service, first, second, third,
                                fourth, fifth)
    }
    return UInt64.max
}

/// One byte of a guest's speech, drawn by the screen's rules —
/// the same ones `cat` prints files by.
func printGuestByte(_ byte: UInt8) {
    if byte == 0x0A {
        writeNewline()
    } else if byte == 0x09 {
        writeChar(0x20)
    } else if byte >= 0x20 && byte != 0x7F {
        writeChar(byte)
    }
}

/// `run`: the milestone's whole road in one walk — the file found
/// on the disc by the milestone-8 reader, its size weighed against
/// the estate's cap, a house of tables built for it, its bytes
/// read off the disc into that house, the floor's hand dropping
/// the machine into ring 3 at its first byte, and the report:
/// the exit code spoken truly when the guest leaves by the door,
/// the stopping's own words when it was stopped.
func runProgram() {
    if !filesReady() { return }
    let length = copyArgumentToScratch()
    if length == 0 {
        writeLine(runUsageLine)
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
    // A feather is not a bare program (milestone 11): its card
    // stands in front of its bytes, and a raw loader executing
    // the card as code is exactly what the format exists to
    // prevent. The first sector is peeked at, and a package is
    // named, refused, and sent to its own command.
    let fromBundle = resolvedFromBundle
    let extent = resolvedExtent
    let offset = resolvedOffset
    if resolvedSize >= UInt32(featherMagicLength + 1)
        && serveReadChunk(fromBundle, extent, offset, resolvedSize, 0)
        && featherMagicAt(discBuffer(), 0,
                          resolvedSize < UInt32(discSectorBytes)
                              ? Int(resolvedSize) : discSectorBytes) {
        writePathArgument(length)
        writeStatic(runFeatherMiddle)
        writePathArgument(length)
        writeNewline()
        return
    }
    if resolvedSize == 0 {
        writePathArgument(length)
        writeLine(runEmptySuffix)
        return
    }
    if UInt64(resolvedSize) > programMaxImageBytes {
        writeLine(runTooBigLine)
        return
    }
    let root = buildProgramSpace(resolvedSize)
    if root == 0 {
        writeLine(runNoMemoryLine)
        return
    }
    if !loadProgramImage(fromBundle, extent, offset, resolvedSize) {
        teardownProgramSpace(root)
        writeLine(discReadErrorLine)
        return
    }
    writeStatic(runRunningPrefix)
    writePathArgument(length)
    writeLine(runRunningSuffix)
    writeLine(sessionStopLine)
    resetGuestDoorState()
    programRunning = true
    let verdict = cardnullLaunchProgram(root, programBase, programStackTop)
    programRunning = false
    teardownProgramSpace(root)
    restoreGuestScreen()
    if verdict == programKilledVerdict {
        writeLine(programKilledLine)
    } else {
        writeStatic(programExitedPrefix)
        writeNumber(verdict)
        writeNewline()
    }
}

/// Writes one reach of the path scratch, as the typist wrote it:
/// the bytes from `start` up to `end`. `both` keeps two paths in
/// the one scratch, and its answers name each as it was asked
/// for, so the whole-scratch writer above is not enough.
func writePathSlice(_ start: Int, _ end: Int) {
    let path = discPath()
    var index = start
    while index < end {
        writeChar(path[index])
        index += 1
    }
}

/// Splits the argument already copied into the path scratch by
/// copyArgumentToScratch into exactly two tokens — no more, no
/// fewer, because `both` carries two guests and pretending
/// otherwise would be a quiet lie. The first token stands at the
/// scratch's head; the second's reach is left in bothSecondStart
/// and bothSecondEnd. False when the line does not hold exactly
/// two tokens; the caller answers with the usage.
func splitBothArguments(_ length: Int) -> Bool {
    let path = discPath()
    var index = 0
    while index < length && path[index] != 0x20 { index += 1 }
    bothFirstEnd = index
    if bothFirstEnd == 0 { return false }
    while index < length && path[index] == 0x20 { index += 1 }
    if index >= length { return false }
    bothSecondStart = index
    while index < length && path[index] != 0x20 { index += 1 }
    bothSecondEnd = index
    while index < length && path[index] == 0x20 { index += 1 }
    return index >= length
}

/// One guest file weighed for the road, in the reach of the
/// scratch where its path lies: resolved through the milestone-8
/// reader and measured against the estate's laws — a file, not a
/// directory; something in it; no more than the cap. The refusal
/// that fits is spoken, naming the path as typed, and false
/// returned; on success the resolved extent and size stand in
/// resolvedExtent and resolvedSize, as `run` leaves them. `run`
/// keeps its own inlined walk, word for word as milestone 9 left
/// it; this is `both`'s twin of it, shared by its two guests.
func resolveGuestFile(_ start: Int, _ end: Int) -> Bool {
    discReadFailed = false
    let outcome = serveResolvePathIn(start, end)
    if outcome == pathMissingCode {
        writeNotHerePrefix()
        writePathSlice(start, end)
        writeNewline()
        return false
    }
    if outcome == pathNotDirectoryCode {
        writePathSlice(start, end)
        writeLine(notDirectorySuffix)
        return false
    }
    if outcome == pathReadErrorCode {
        writeLine(discReadErrorLine)
        return false
    }
    if resolvedIsDirectory {
        writePathSlice(start, end)
        writeLine(isDirectorySuffix)
        return false
    }
    if resolvedSize == 0 {
        writePathSlice(start, end)
        writeLine(runEmptySuffix)
        return false
    }
    if UInt64(resolvedSize) > programMaxImageBytes {
        writeLine(runTooBigLine)
        return false
    }
    return true
}

/// One guest's report at a pair session's end, in the order the
/// guests were named: the path as typed, then its ending — the
/// exit code when it left by the door, the plain word when it
/// was stopped.
func reportBothGuest(_ start: Int, _ end: Int,
                     _ status: UInt64, _ verdict: UInt64) {
    writePathSlice(start, end)
    if status == pairStatusStopped {
        writeLine(bothStoppedSuffix)
    } else {
        writeStatic(bothExitedWord)
        writeNumber(verdict)
        writeNewline()
    }
}

/// `both`: milestone 10's whole road — `run`'s walk walked twice,
/// then the pair launch. Two files are weighed and read off the
/// disc, two estates built and filled; the floor's pair launch
/// enters the first guest and keeps the turning from there. When
/// it returns, both guests stand finished — left or stopped —
/// and the shell reads their standings and verdicts out of the
/// floor's result bookmarks, reports each truly, and takes both
/// estates back frame by frame, so `mem` reads the same numbers
/// before a session and after it, as it did for `run`.
func runBoth() {
    if !filesReady() { return }
    let length = copyArgumentToScratch()
    if length == 0 || !splitBothArguments(length) {
        writeLine(bothUsageLine)
        return
    }
    if !pagingReady {
        writeLine(runNoPagingLine)
        return
    }
    if !resolveGuestFile(0, bothFirstEnd) { return }
    let fromBundleA = resolvedFromBundle
    let extentA = resolvedExtent
    let offsetA = resolvedOffset
    let sizeA = resolvedSize
    if !resolveGuestFile(bothSecondStart, bothSecondEnd) { return }
    let fromBundleB = resolvedFromBundle
    let extentB = resolvedExtent
    let offsetB = resolvedOffset
    let sizeB = resolvedSize
    let rootA = buildProgramSpace(sizeA)
    if rootA == 0 {
        writeLine(runNoMemoryLine)
        return
    }
    if !loadProgramImage(fromBundleA, extentA, offsetA, sizeA) {
        teardownProgramSpace(rootA)
        writeLine(discReadErrorLine)
        return
    }
    let rootB = buildProgramSpace(sizeB)
    if rootB == 0 {
        teardownProgramSpace(rootA)
        writeLine(runNoMemoryLine)
        return
    }
    if !loadProgramImage(fromBundleB, extentB, offsetB, sizeB) {
        teardownProgramSpace(rootB)
        teardownProgramSpace(rootA)
        writeLine(discReadErrorLine)
        return
    }
    writeStatic(runRunningPrefix)
    writePathSlice(0, bothFirstEnd)
    writeStatic(bothAndWord)
    writePathSlice(bothSecondStart, bothSecondEnd)
    writeLine(bothTogetherSuffix)
    writeLine(sessionStopLine)
    resetGuestDoorState()
    programRunning = true
    pairRunning = true
    let verdictA = cardnullLaunchPair(rootA, programBase, programStackTop,
                                      rootB, programBase, programStackTop)
    pairRunning = false
    programRunning = false
    let statusA = cardnullPairStatusA()
    let statusB = cardnullPairStatusB()
    let verdictB = cardnullPairVerdictB()
    teardownProgramSpace(rootA)
    teardownProgramSpace(rootB)
    reportBothGuest(0, bothFirstEnd, statusA, verdictA)
    reportBothGuest(bothSecondStart, bothSecondEnd, statusB, verdictB)
    // The session's closing account (milestone 15): the turns
    // the machine took, spoken in the floor's own two numbers —
    // at the door, where a guest's yield or leaving handed the
    // machine over, and by the timer, where a spent slice took
    // it. A courteous pair speaks mostly door; a spinning one
    // speaks mostly timer; either way the numbers are what
    // happened, not what the milestone hoped.
    writeStatic(bothSwitchesPrefix)
    writeNumber(cardnullDoorSwitches())
    writeStatic(bothSwitchesDoorWord)
    writeNumber(cardnullTimerSwitches())
    writeLine(bothSwitchesTimerWord)
}

