// Cardnull OS — the kernel, in parts.
//
// This file is one part of the kernel module, split from the
// single Kernel.swift at milestone 33.5 ("The Split"): the
// same code, moved — no behavior changed. The module's files
// are named for their subsystems; Kernel.swift keeps the
// boot and the entry. Written in Embedded Swift, in the
// open, in the public domain.
//
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
//   heap    the kernel heap's books: its field, and how the work
//           stands in it (milestone 7)
//   faulttest  the one command whose work is to fail — reaching
//           for an address no page covers, so the page fault's
//           report can be witnessed instead of merely believed
//           (milestone 7; the machine halts on its answer)
//   ls      the disc's contents, listed from its own directory
//           (milestone 8: the ATAPI driver's drive, the ISO9660
//           reader's walk; a path names the directory — or the
//           file — to list)
//   cat     a file's contents, printed off the disc itself
//           (milestone 8; the first argument-carrying command,
//           so these two are matched by their first word and the
//           rest of the line is theirs)
//   run     a program from the disc, loaded into ground of its
//           own and run in ring 3 (milestone 9; matched by its
//           first word, like ls and cat, the path being its own)
//   both    two programs from the disc, loaded into ground of
//           their own and run in ring 3, taking turns by the
//           door's yield service until both have finished
//           (milestone 10; matched by its first word, the two
//           paths being its own)
//   feather a package from the disc — a card that names its
//           program, proven against its checksum, printed, and
//           only then run in ring 3 down run's own road
//           (milestone 11; matched by its first word, the path
//           being its own)
//   files   the disc in a window: the Files window opens on
//           the desktop — from the text console, the face opens
//           with it standing — and the disc is browsed with
//           the mouse there: read in the Reader, run through
//           the Terminal, as the milestone 19 section tells
//           (milestone 19)
//   write   a page to write on: the Write window opens on
//           the desktop — from the text console, the face
//           opens with it standing — and words are written
//           there, opened from the hard disk and saved to
//           it, as the milestone 31 section tells
//           (milestone 31)
//   gui     the graphical face: a drawn desktop, one window, and
//           a pointer that answers the PS/2 mouse, until the
//           close box or Esc brings the shell home (milestone 12)
//   mouse   the mouse's report: the waking's transcript in its
//           own codes, exactly as the boot screen spoke it, with
//           the face's tallies of the mouse's answers beneath —
//           the desktop's codes, at home in the Terminal
//           (milestone 16)
//   sound   the machine's first voice: a short melody played on
//           the PC speaker — the timer's second channel behind
//           its gate — each note printed as it sounds, and the
//           speaker left silent at the phrase's end (milestone 17)
//   net     the first conversation on the wire: the Intel
//           network card found on the PCI bus, raised behind its
//           descriptor rings, and a DHCP discover asked of the
//           network — the offer reported with its addresses,
//           and the address not taken (milestone 20)
//   disk    the hard disk's account: what it is and what
//           stands on it (milestone 21)
//   format  make the hard disk a Cardnull disk, behind a
//           typed confirmation — it erases (milestone 21)
//   dsave   save a line of words as a file on the hard disk
//           (milestone 21; matched by its first word, the name
//           and the words being its own)
//   dls     the hard disk's files, listed from its own
//           directory (milestone 21)
//   dcat    a file's contents, printed off the hard disk
//           (milestone 21; matched by its first word, like cat)
//   rename  rename a file on the hard disk: the entry's name
//           alone is rewritten, and the name it leaves stands
//           free (milestone 30; matched by its first word, the
//           two names being its own)
//   copy    copy a file on the hard disk to a new name, its
//           bytes carried to a fresh run of sectors
//           (milestone 30; matched by its first word, like
//           rename)
//   delete  remove a file from the hard disk, behind the
//           typed confirmation — it unmakes the entry and
//           frees the name and the slot, and its data's
//           ground is never given again (milestone 30;
//           matched by its first word, like dcat)
//   install plant Cardnull on the hard disk: format it and
//           copy the disc's own files onto it — Cardnull
//           itself among them — behind the typed confirmation
//           (milestone 21; the kernel and bundle joined the
//           copying at milestone 28)
//   bootable prepare the hard disk to start the computer by
//           itself: the filesystem moved behind a partition,
//           our boot image at its head, behind the typed
//           confirmation (milestone 28)
//   usb     the USB stick's account: what is plugged in —
//           its name, its measure, and what stands on it —
//           or the plain word that no stick is there
//           (milestone 32)
//   uls     the USB stick's files, listed from its own
//           directory, when the stick is a Cardnull disk
//           (milestone 32)
//   ucat    a file's contents, printed off the USB stick
//           (milestone 32; matched by its first word, like
//           dcat)
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
let heapCommand: StaticString = "heap"
let faulttestCommand: StaticString = "faulttest"
let lsCommand: StaticString = "ls"
let catCommand: StaticString = "cat"
let runCommand: StaticString = "run"
let bothCommand: StaticString = "both"
let featherCommand: StaticString = "feather"
let filesCommand: StaticString = "files"
let writeCommand: StaticString = "write"
let bibleCommand: StaticString = "bible"
let shieldCommand: StaticString = "shield"
let howdoiCommand: StaticString = "howdoi"
let settingsCommand: StaticString = "settings"
let guiCommand: StaticString = "gui"
let mouseCommand: StaticString = "mouse"
let soundCommand: StaticString = "sound"
let netCommand: StaticString = "net"
let diskCommand: StaticString = "disk"
let formatCommand: StaticString = "format"
let dsaveCommand: StaticString = "dsave"
let dlsCommand: StaticString = "dls"
let dcatCommand: StaticString = "dcat"
let renameCommand: StaticString = "rename"
let copyCommand: StaticString = "copy"
let deleteCommand: StaticString = "delete"
let installCommand: StaticString = "install"
let bootableCommand: StaticString = "bootable"
let usbCommand: StaticString = "usb"
let ulsCommand: StaticString = "uls"
let ucatCommand: StaticString = "ucat"

/// help's answer: the list itself.
let helpTitle: StaticString = "Commands:"
let helpHelpLine: StaticString = "  help    show this list"
let helpAboutLine: StaticString = "  about   what Cardnull OS is"
let helpVerseLine: StaticString = "  verse   a verse of Scripture"
let helpClearLine: StaticString = "  clear   clear the screen"
let helpUptimeLine: StaticString = "  uptime  how long the kernel has been awake"
let helpMemLine: StaticString = "  mem     the machine's memory, counted from its map"
let helpHeapLine: StaticString = "  heap    the kernel heap, counted from its books"
let helpFaultLine: StaticString = "  faulttest  take a page fault on purpose"
let helpLsLine: StaticString = "  ls      list the disc's files (ls /path)"
let helpCatLine: StaticString = "  cat     print a file from the disc (cat /path)"
let helpRunLine: StaticString = "  run     run a program from the disc (run /path)"
let helpBothLine: StaticString =
    "  both    run two programs, taking turns (both /A.BIN /B.BIN)"
let helpFeatherLine: StaticString =
    "  feather open a feather package and run it (feather /path)"
let helpFilesLine: StaticString =
    "  files   open the Files window - the disc, browsable"
let helpWriteLine: StaticString =
    "  write   open the Write window - a page to write on"
let helpBibleLine: StaticString =
    "  bible   open the Bible window - the Douay-Rheims Bible"
let helpShieldLine: StaticString =
    "  shield  open the Shield window - the guard's standing"
let helpHowdoiLine: StaticString =
    "  howdoi  open the Help window - plain answers to plain questions"
let helpSettingsLine: StaticString =
    "  settings  open the Settings window - the clock, the mouse, the start"
let helpGuiLine: StaticString =
    "  gui     open the graphical desktop (Esc brings you home)"
let helpMouseLine: StaticString =
    "  mouse   the mouse's report: its waking and its answers"
let helpSoundLine: StaticString =
    "  sound   play a short melody on the speaker"
let helpNetLine: StaticString =
    "  net     take a lease on the network (DHCP) and answer it"
let helpDiskLine: StaticString =
    "  disk    the hard disk: what it is, and what stands on it"
let helpFormatLine: StaticString =
    "  format  make the hard disk a Cardnull disk (erases it)"
let helpDsaveLine: StaticString =
    "  dsave   save words to the hard disk (dsave NAME words...)"
let helpDlsLine: StaticString =
    "  dls     list the files on the hard disk"
let helpDcatLine: StaticString =
    "  dcat    print a file from the hard disk (dcat NAME)"
let helpRenameLine: StaticString =
    "  rename  rename a file on the hard disk (rename OLD NEW)"
let helpCopyLine: StaticString =
    "  copy    copy a file on the hard disk (copy OLD NEW)"
let helpDeleteLine: StaticString =
    "  delete  remove a file from the hard disk (delete NAME)"
let helpInstallLine: StaticString =
    "  install install Cardnull onto the hard disk (erases it)"
let helpBootableLine: StaticString =
    "  bootable prepare the hard disk to start the computer by itself"
let helpUsbLine: StaticString =
    "  usb     the USB stick: what is plugged in, and what stands on it"
let helpUlsLine: StaticString =
    "  uls     list the files on the USB stick"
let helpUcatLine: StaticString =
    "  ucat    print a file from the USB stick (ucat NAME)"

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

/// heap's vocabulary: labels and units, with the numbers spoken
/// between them by writeNumber. Block counts keep their plural
/// honest, the way uptime's units do.
let heapTitle: StaticString = "Heap:"
let heapRegionLabel: StaticString = "  Region: "
let heapBytesParen: StaticString = " bytes ("
let heapMiBClose: StaticString = " MiB)"
let heapUsedLabel: StaticString = "  Used: "
let heapFreeLabel: StaticString = "  Free: "
let heapBytesIn: StaticString = " bytes in "
let heapBlockWord: StaticString = " block"
let heapBlocksWord: StaticString = " blocks"
let heapSelfTestPassedLine: StaticString = "  Heap self-test: passed"
let heapSelfTestFailedLine: StaticString = "  Heap self-test: FAILED"
let heapNoHeapLine: StaticString = "No heap was raised."

/// heap's answer: the heap's field and how the work stands in it —
/// the region's size, the used and free bytes with their block
/// counts beside them (whole-block bytes, headers included: used
/// plus free is the region, exactly), and the self-test's verdict.
/// Every number is the block chain's own reading, re-reckoned at
/// every change; nothing here is remembered from the build machine.
func printHeap() {
    if !heapReady {
        writeLine(heapNoHeapLine)
        return
    }
    writeLine(heapTitle)
    writeStatic(heapRegionLabel)
    writeNumber(heapRegionBytes)
    writeStatic(heapBytesParen)
    writeNumber(heapRegionBytes / 1048576)
    writeLine(heapMiBClose)
    writeStatic(heapUsedLabel)
    writeNumber(heapUsedBytes)
    writeStatic(heapBytesIn)
    writeNumber(heapUsedBlocks)
    writeLine(heapUsedBlocks == 1 ? heapBlockWord : heapBlocksWord)
    writeStatic(heapFreeLabel)
    writeNumber(heapFreeBytes)
    writeStatic(heapBytesIn)
    writeNumber(heapFreeBlocks)
    writeLine(heapFreeBlocks == 1 ? heapBlockWord : heapBlocksWord)
    writeLine(heapSelfTestOK ? heapSelfTestPassedLine
                             : heapSelfTestFailedLine)
}

/// faulttest's words: the announcement before the reach (the
/// report itself will overwrite the screen's top rows when it
/// comes), the honest word when paging is not standing and there
/// is no fault to take, and — against every expectation — the word
/// for the reach having been answered.
let faultAnnounceLine: StaticString =
    "Reaching for an address no page covers: 0xDEAD0000."
let faultExpectLine: StaticString =
    "If the kernel's tables are honest, the fault reports itself and halts."
let faultNoPagingLine: StaticString =
    "Paging is not standing; on the borrowed map, everything answers."
let faultSurvivedLine: StaticString =
    "No fault came. The address answered: "

/// faulttest's work: announce the reach, then take it. Under the
/// kernel's own tables the touch faults, the handler writes its
/// report across the top of the screen, and the machine halts —
/// this function never comes back. It can only return to be
/// answered here if the address somehow answered, and then it
/// says so, plainly: that, too, would be a truth worth hearing.
func runFaultTest() {
    if !pagingReady {
        writeLine(faultNoPagingLine)
        return
    }
    writeLine(faultAnnounceLine)
    writeLine(faultExpectLine)
    let value = touchUnmapped()
    writeStatic(faultSurvivedLine)
    writeNumber(UInt64(value))
    writeNewline()
}

/// True when the typed line is nothing but spaces — the typist
/// pressed Enter on an empty line, which earns only a fresh prompt.
func lineIsBlank() -> Bool {
    let start = cellOffset(lineStartRow, lineStartCol)
    let end = cellOffset(cursorRow, cursorCol)
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
    let start = cellOffset(lineStartRow, lineStartCol)
    let end = cellOffset(cursorRow, cursorCol)
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
    if consoleInTerminal {
        // In the window, clear wipes the window's grid alone —
        // the desktop around it is not the shell's to blacken.
        let termGrid = cardnullTermGrid()
        for row in 0 ..< termRows {
            for col in 0 ..< termColumns {
                termGrid[row * termStrideColumns + col] = 0x20
            }
        }
        termMarkAllDirty()
        cursorRow = 0
        cursorCol = 0
        startLine()
        return
    }
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
    let isHeap = commandMatches(heapCommand)
    let isFaulttest = commandMatches(faulttestCommand)
    let isLs = firstWordMatches(lsCommand)
    let isCat = firstWordMatches(catCommand)
    let isRun = firstWordMatches(runCommand)
    let isBoth = firstWordMatches(bothCommand)
    let isFeather = firstWordMatches(featherCommand)
    let isFiles = commandMatches(filesCommand)
    let isWrite = commandMatches(writeCommand)
    let isBible = commandMatches(bibleCommand)
    let isShield = commandMatches(shieldCommand)
    let isHowdoi = commandMatches(howdoiCommand)
    let isSettings = commandMatches(settingsCommand)
    let isGui = commandMatches(guiCommand)
    let isMouse = commandMatches(mouseCommand)
    let isSound = commandMatches(soundCommand)
    let isNet = commandMatches(netCommand)
    let isDisk = commandMatches(diskCommand)
    let isFormat = commandMatches(formatCommand)
    let isDsave = firstWordMatches(dsaveCommand)
    let isDls = commandMatches(dlsCommand)
    let isDcat = firstWordMatches(dcatCommand)
    let isRename = firstWordMatches(renameCommand)
    let isCopy = firstWordMatches(copyCommand)
    let isDelete = firstWordMatches(deleteCommand)
    let isInstall = commandMatches(installCommand)
    let isBootable = commandMatches(bootableCommand)
    let isUsb = commandMatches(usbCommand)
    let isUls = commandMatches(ulsCommand)
    let isUcat = firstWordMatches(ucatCommand)

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
            writeLine(helpHeapLine)
            writeLine(helpFaultLine)
            writeLine(helpLsLine)
            writeLine(helpCatLine)
            writeLine(helpRunLine)
            writeLine(helpBothLine)
            writeLine(helpFeatherLine)
            writeLine(helpFilesLine)
            writeLine(helpWriteLine)
            writeLine(helpBibleLine)
            writeLine(helpShieldLine)
            writeLine(helpHowdoiLine)
            writeLine(helpSettingsLine)
            writeLine(helpGuiLine)
            writeLine(helpMouseLine)
            writeLine(helpSoundLine)
            writeLine(helpNetLine)
            writeLine(helpDiskLine)
            writeLine(helpFormatLine)
            writeLine(helpDsaveLine)
            writeLine(helpDlsLine)
            writeLine(helpDcatLine)
            writeLine(helpRenameLine)
            writeLine(helpCopyLine)
            writeLine(helpDeleteLine)
            writeLine(helpInstallLine)
            writeLine(helpBootableLine)
            writeLine(helpUsbLine)
            writeLine(helpUlsLine)
            writeLine(helpUcatLine)
        } else if isAbout {
            writeLine(aboutLine1)
            writeLine(aboutLine2)
            writeLine(aboutLine3)
            writeLine(aboutLine4)
            // The files' source, in the one true sentence
            // (milestone 23): carried in memory, or read from
            // the disc.
            printFilesSourceLine()
        } else if isVerse {
            writeLine(verseLine)
            writeLine(verseAttribution)
        } else if isUptime {
            printUptime()
        } else if isMem {
            printMemory()
        } else if isHeap {
            printHeap()
        } else if isFaulttest {
            runFaultTest()
        } else if isLs {
            runList()
        } else if isCat {
            runCat()
        } else if isRun {
            runProgram()
        } else if isBoth {
            runBoth()
        } else if isFeather {
            runFeather()
        } else if isFiles {
            runFilesCommand()
        } else if isWrite {
            runWriteCommand()
        } else if isBible {
            runBibleCommand()
        } else if isShield {
            runShieldCommand()
        } else if isHowdoi {
            runHowdoiCommand()
        } else if isSettings {
            runSettingsCommand()
        } else if isGui {
            if consoleInTerminal {
                // Already here: this window is the desktop's own
                // shell, and opening the face from inside the face
                // would only fold the world in on itself.
                writeLine(guiAlreadyLine)
            } else {
                runGui()
            }
        } else if isMouse {
            printMouseStanding()
        } else if isSound {
            runSound()
        } else if isNet {
            runNet()
        } else if isDisk {
            runDisk()
        } else if isFormat {
            runFormat()
        } else if isDsave {
            runDsave()
        } else if isDls {
            runDls()
        } else if isDcat {
            runDcat()
        } else if isRename {
            runRename()
        } else if isCopy {
            runCopy()
        } else if isDelete {
            runDelete()
        } else if isInstall {
            runInstall()
        } else if isBootable {
            runBootable()
        } else if isUsb {
            runUsb()
        } else if isUls {
            runUls()
        } else if isUcat {
            runUcat()
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

