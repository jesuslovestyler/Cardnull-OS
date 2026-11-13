// Cardnull OS — the kernel.
//
// This file is the kernel's boot and entry: the function the
// boot floor calls once the processor is awake, its page
// tables are set, and control passes from the thin assembly
// floor into Swift — and the floor's own lent hands.
//
// The kernel is one Swift module in several files, split at
// milestone 33.5 ("The Split") from the single file it grew
// as — the same code, moved, nothing changed. The files,
// named for their subsystems: Screen (the text screen),
// Floor (interrupts, memory, the heap), Disc (the ISO disc),
// Bundle (the files carried in memory), Guests (programs
// and sessions), Feathers (the package format and its
// door), Desktop (the graphical face and its windows),
// Files (the file manager and the Reader), Bible (the
// Bible window), Sound (the speaker and the HDA chip),
// Network (the wire), Disk (the hard disk and its files),
// Write (the Write window), USB (the stick), Shell (the
// command line), Power (the clock and the leaving). New
// subsystems get their own files; the kernel is never
// gathered back into one.
//
// It is written in Embedded Swift — Swift compiled
// freestanding, with no operating system beneath it and no
// standard library beyond what can live on bare metal.
// Nothing is imported; there is nothing to import from yet.
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

/// Provided by the boot floor (support.c): reads one double-word
/// from a processor I/O port — milestone 8's widening of the
/// hands above, for PCI configuration space, which speaks a full
/// 32 bits at a time. The disc controller is found there; its own
/// registers are memory-mapped and need no hand at all.
@_silgen_name("cardnull_inl")
func cardnullInl(_ port: UInt16) -> UInt32

/// Provided by the boot floor (support.c): writes one double-word
/// to a processor I/O port — the companion of the read above.
@_silgen_name("cardnull_outl")
func cardnullOutl(_ port: UInt16, _ value: UInt32)

/// Provided by the boot floor (support.c): reads one word from a
/// processor I/O port — milestone 32's widening of the hands
/// above, for the USB host controller, whose registers speak
/// sixteen bits at a time through its I/O door.
@_silgen_name("cardnull_inw")
func cardnullInw(_ port: UInt16) -> UInt16

/// Provided by the boot floor (support.c): writes one word to a
/// processor I/O port — the companion of the read above.
@_silgen_name("cardnull_outw")
func cardnullOutw(_ port: UInt16, _ value: UInt16)

/// Provided by the boot floor (support.c): raises the whole interrupt
/// machinery of milestone 4 — builds the IDT from the assembly stub
/// table, remaps the PIC pair to vectors 0x20/0x28, sets the PIT
/// ticking at 100 Hz, drains the keyboard controller, and opens the
/// interrupt gate (sti). Called once, before the shell's first sleep.
@_silgen_name("cardnull_setup_interrupts")
func cardnullSetupInterrupts()

/// Provided by the boot floor (support.c): one honest sleep — `hlt`
/// until the next interrupt arrives, then return. The shell loop
/// rests here between keystrokes instead of spinning on the ports.
@_silgen_name("cardnull_hlt_once")
func cardnullHltOnce()

/// Provided by the boot floor (support.c): closes the interrupt gate
/// (cli) and keeps it closed. The exception handler calls this before
/// its last words, so nothing can interrupt a halt.
@_silgen_name("cardnull_cli")
func cardnullCli()

/// Provided by the boot floor (support.c): the raw storage of the
/// keyboard ring buffer — 64 bytes the floor lends, because Embedded
/// Swift cannot name a fixed mutable byte array without a heap. Every
/// decision about those bytes is the kernel's, below; the floor only
/// keeps the memory.
@_silgen_name("cardnull_key_ring")
func cardnullKeyRing() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the raw storage of the
/// screen's character grid — 80 x 25 bytes the floor lends, for the
/// same reason as the key ring. Milestones 1-4 kept the characters
/// in the VGA text buffer itself and read typed lines back out of
/// the hardware; the framebuffer screen of milestone 5 holds pixels,
/// not letters, so the kernel keeps the grid itself now, and every
/// screen behind the one door reads and paints from it.
@_silgen_name("cardnull_text_grid")
func cardnullTextGrid() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the raw storage of the
/// mouse ring buffer — 256 bytes the floor lends, for the same
/// reason as the key ring. Milestone 12's IRQ12 handler fills it
/// one byte at a time; the graphical face drains it at its leisure
/// and makes packets of the bytes. Every decision about the bytes
/// is the kernel's, below; the floor only keeps the memory.
@_silgen_name("cardnull_mouse_ring")
func cardnullMouseRing() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the pointer's cushion —
/// 32 x 32 raw pixel words the floor lends. Before the face draws
/// its pointer it lifts the pixels underneath into this cushion,
/// and when the pointer moves or goes home it lays them back, so
/// the pointer never leaves a trail across the desktop. What the
/// words hold — one framebuffer pixel each, in the screen's own
/// packing — is the kernel's business, below.
@_silgen_name("cardnull_gui_cushion")
func cardnullGuiCushion() -> UnsafeMutablePointer<UInt32>

/// Provided by the boot floor (support.c): the raw storage of
/// the Terminal window's character grid — a fixed keeping of
/// 120 x 64 bytes the floor lends, for the same reason as the
/// text grid. Milestone 13's shell spoke through this grid while
/// the desktop stood and the Terminal window was open, so the
/// console's own conversation was never touched by the face;
/// milestone 14 made the window's visible shape a thing reckoned
/// from the window's size, so the keeping is now a capacity, not
/// a shape: the numbers are agreed with the kernel's
/// termStrideColumns and termRowsCapacity, and the visible
/// termColumns and termRows live within them.
@_silgen_name("cardnull_term_grid")
func cardnullTermGrid() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the Terminal
/// conversation's memory — 120 x 128 bytes the floor lends
/// milestone 26's scrollback: the lines that lift off the
/// Terminal grid's top, kept a whole stride-row each, in the
/// order they left. How many stand there and which of them
/// the window shows is the kernel's business, below.
@_silgen_name("cardnull_term_history")
func cardnullTermHistory() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the mouse report's
/// keeping — 160 bytes the floor lends for the two lines the
/// kernel composes at boot: whether the mouse answered its
/// waking, and what each step of the waking heard. The same
/// bytes are printed on the console and drawn on the desktop,
/// so the two tellings can never disagree.
@_silgen_name("cardnull_mouse_report")
func cardnullMouseReport() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the Files window's
/// keeping — 12,288 bytes the floor lends for milestone 19's
/// two new windows: the disc's entries as the Files window
/// read them, its status line, and the page the Reader window
/// is showing. The layout is the kernel's business, in the
/// milestone 19 section below (filesKeepingBytes and its
/// companions); the floor only keeps the memory, as with
/// every keeping before it.
@_silgen_name("cardnull_files_keeping")
func cardnullFilesKeeping() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (font8x8.c): the 8x8 bitmap font the
/// framebuffer backend draws letters from — 128 glyphs of 8 bytes,
/// one byte per row, bit 0 the leftmost pixel. Daniel Hepper's
/// font8x8_basic, drawn from the public-domain IBM VGA fonts and
/// public domain itself, as everything here is.
@_silgen_name("cardnull_font8x8")
func cardnullFont8x8() -> UnsafePointer<UInt8>

/// Provided by the boot floor (support.c): the raw storage of the
/// frame allocator's bitmap — 128 KiB of bits, one per 4 KiB frame,
/// covering the first 4 GiB of the machine. The floor lends the
/// memory for the same reason it lends the key ring and the text
/// grid; which frames exist and which are free is the kernel's
/// business, in the memory section below.
@_silgen_name("cardnull_frame_bitmap")
func cardnullFrameBitmap() -> UnsafeMutablePointer<UInt8>

/// Provided by the boot floor (support.c): the kernel image's own
/// first address, as the linker script named it. The allocator
/// reserves the whole image — code, data, page tables, stack — so
/// it never hands out the ground the kernel is standing on.
@_silgen_name("cardnull_kernel_start")
func cardnullKernelStart() -> UInt64

/// The companion bound: one past the kernel image's last byte.
@_silgen_name("cardnull_kernel_end")
func cardnullKernelEnd() -> UInt64

/// Provided by the boot floor (support.c): raises EFER's NXE bit,
/// the switch that makes the no-execute bit in a page entry law
/// instead of a reserved-bit fault. Milestone 7 calls it once,
/// just before loading its own page tables — the tables carrying
/// NX bits must never be walked before this stands.
@_silgen_name("cardnull_enable_nxe")
func cardnullEnableNxe()

/// Provided by the boot floor (support.c): loads CR3 — points the
/// processor at a new set of page tables. The write flushes the
/// translation caches, so the very next instruction already walks
/// the new tables.
@_silgen_name("cardnull_load_cr3")
func cardnullLoadCr3(_ root: UInt64)

/// Provided by the boot floor (support.c): forgets one page's
/// cached translation (`invlpg`). Milestone 8's disc driver maps
/// its controller's registers into the standing tables — pages
/// that were absent a moment ago — and the processor must be
/// told to look again rather than trust the remembered absence.
@_silgen_name("cardnull_invlpg")
func cardnullInvlpg(_ address: UInt64)

/// Provided by the boot floor (support.c): the kernel image's text
/// span, as the linker script named it. Milestone 7's page tables
/// mark these pages executable and not writable — the W of W^X.
@_silgen_name("cardnull_text_start")
func cardnullTextStart() -> UInt64

/// The companion bound: one past the text span's last byte.
@_silgen_name("cardnull_text_end")
func cardnullTextEnd() -> UInt64

/// Provided by the boot floor (support.c): the kernel image's
/// read-only span, as the linker script named it — neither writable
/// nor executable in the kernel's own tables.
@_silgen_name("cardnull_rodata_start")
func cardnullRodataStart() -> UInt64

/// The companion bound: one past the read-only span's last byte.
@_silgen_name("cardnull_rodata_end")
func cardnullRodataEnd() -> UInt64

/// Provided by the boot floor (support.c): raises milestone 9's
/// ring-3 furniture — a task state segment whose ring-0 stack
/// pointer names a stack of the kernel's own, its descriptor
/// written into the GDT slot boot.S left empty, and the task
/// register loaded. Called once from kmain *before* the kernel's
/// own page tables are built: the GDT sits in read-only data, and
/// only the floor's borrowed map still lets it be written.
@_silgen_name("cardnull_setup_user_mode")
func cardnullSetupUserMode()

/// Provided by the boot floor (boot.S): the going-out hand of
/// milestone 9. Moves the machine onto the given page tables and
/// enters the guest at its entry address in ring 3, with the
/// given stack top. Returns only when the guest has left — by
/// its exit service, with its exit code, or by abandonment, with
/// the verdict the fault handler handed the floor.
@_silgen_name("cardnull_launch_program")
func cardnullLaunchProgram(_ tables: UInt64, _ entry: UInt64,
                           _ stackTop: UInt64) -> UInt64

/// Provided by the boot floor (boot.S): the other way home. Called
/// from the page-fault handler when a guest has faulted in its own
/// mode: the floor restores the kernel's tables and the shell's
/// stack and returns the verdict to the launch hand's caller, as
/// if the guest had exited with it. Never returns here.
@_silgen_name("cardnull_abandon_program")
func cardnullAbandonProgram(_ verdict: UInt64) -> Never

/// Provided by the boot floor (boot.S): milestone 10's going-out
/// hand for two guests. Bookmarks home exactly as the single
/// launch does, writes each guest's whole state into one of the
/// floor's two guest books — its tables, its entry, its stack,
/// its flags, every other word wiped clean — and enters guest A.
/// From there the guests trade the machine by the door's yield
/// service until both have left or been stopped; only then does
/// this hand return, carrying guest A's verdict. Guest B's
/// verdict and the two standings wait in the floor's result
/// bookmarks, read out by the three hands below.
@_silgen_name("cardnull_launch_pair")
func cardnullLaunchPair(_ tablesA: UInt64, _ entryA: UInt64,
                        _ stackTopA: UInt64, _ tablesB: UInt64,
                        _ entryB: UInt64, _ stackTopB: UInt64) -> UInt64

/// Provided by the boot floor (boot.S): the pair's fault road.
/// Called from the page-fault handler when a guest has faulted
/// while a partner lives: the floor writes the fallen guest down
/// as stopped, with the verdict the handler named, and takes the
/// machine to the survivor — or home, if the survivor is finished
/// too. Never returns here.
@_silgen_name("cardnull_abandon_guest_in_pair")
func cardnullAbandonGuestInPair(_ verdict: UInt64) -> Never

/// Provided by the boot floor (boot.S): guest B's verdict from
/// the last pair session, read out of the floor's result
/// bookmarks after the pair launch has returned.
@_silgen_name("cardnull_pair_verdict_b")
func cardnullPairVerdictB() -> UInt64

/// Provided by the boot floor (boot.S): guest A's standing from
/// the last pair session — 1 when it left by the door, 2 when it
/// was stopped — read out of the floor's result bookmarks.
@_silgen_name("cardnull_pair_status_a")
func cardnullPairStatusA() -> UInt64

/// Provided by the boot floor (boot.S): guest B's standing from
/// the last pair session, the companion to the hand above.
@_silgen_name("cardnull_pair_status_b")
func cardnullPairStatusB() -> UInt64

// Milestone 15's hands: the stop word (set here when Esc is
// pressed while a session stands; the floor's timer stub ends
// the session on its next tick) and the pair session's two
// switch counts, read once the launch has returned.
@_silgen_name("cardnull_set_stop_request")
func cardnullSetStopRequest(_ value: UInt64)

@_silgen_name("cardnull_door_switches")
func cardnullDoorSwitches() -> UInt64

@_silgen_name("cardnull_timer_switches")
func cardnullTimerSwitches() -> UInt64

/// The kernel's first word, spoken by milestone 1 and kept on screen
/// by every milestone after it.
///
/// A StaticString, not a String: Embedded Swift has no heap and no
/// String type yet, so the banner lives in the kernel's read-only data
/// as raw UTF-8 bytes — which is all the screen needs from it.
public let cardnullBanner: StaticString = "CARDNULL"

/// Milestone 1 put CARDNULL on the screen; milestone 2 left it there
/// and listened; milestone 3 made the screen a scrolling terminal and
/// the prompt a shell that answers. Milestone 4 changes how the
/// kernel waits: the interrupt machinery is raised after the first
/// prompt, and from then on the kernel *rests* — sleeping in `hlt`
/// until the timer's heartbeat or a keypress wakes it, draining the
/// keyboard ring through the same hands the polling years used. The
/// commands do not change; the waiting does. Milestone 5 changes
/// where the screen lives: the floor hands over the Multiboot2
/// information address as kmain's argument, the kernel reads the
/// framebuffer tag from it before anything is drawn, and the same
/// shell then speaks through whichever screen the boot provided —
/// the VGA text grid behind the BIOS door, drawn pixels behind the
/// UEFI door — with the characters kept in the kernel's own grid
/// either way, so nothing above the painting layer can tell the two
/// doors apart.
@_cdecl("kmain")
public func kmain(_ multibootInfo: UInt64) {
    // Choose the screen before anything is drawn: read the
    // bootloader's information for a usable framebuffer.
    chooseScreen(infoAddress: multibootInfo)

    // Read the bootloader's cargo note (milestone 23): the
    // module tag, when one rode — the bundle's span, noted
    // before the allocator is raised so initMemory can
    // reserve the cargo out of its pool. The proving of the
    // bundle itself waits until after the disc's report,
    // below, where its news is spoken.
    noteBootModule(multibootInfo)

    // Read the machine's power tables (milestone 33): the
    // ACPI pointers the bootloader passed on, parsed now
    // while the floor's identity map still stands, so the
    // desktop's Shut Down can ask the machine to power off
    // by its own tables when the time comes.
    initPower(multibootInfo)

    // Read the bootloader's other word (milestone 6): the memory
    // map. The frame allocator is raised over it now — reservations
    // laid, self-test run — so the `mem` command can speak the
    // machine's true numbers from the shell's first breath. The
    // framebuffer's range is one of the reservations, which is why
    // this waits until the screen is chosen.
    initMemory(infoAddress: multibootInfo)

    // Raise the ring-3 furniture (milestone 9) while the floor's
    // borrowed map still stands: the task state segment and its
    // GDT descriptor live in the kernel's read-only span, which
    // the borrowed map leaves writable and milestone 7's tables
    // will not. No guest exists yet — the furniture is simply
    // ready before the house changes hands.
    cardnullSetupUserMode()

    // Move into our own house (milestone 7): page tables of the
    // kernel's building, raised out of the allocator's frames —
    // the usable RAM identity-mapped under W^X, the kernel's text
    // executable and unwritable, everything else writable and
    // unexecutable, the dark left unmapped — and then, on the far
    // side of the CR3 switch, the heap: one unbroken field of
    // frames with a chain of blocks in it, self-tested before the
    // shell opens. Both buildings happen under the floor's map and
    // the closed interrupt gate; the screen is not yet wiped, and
    // nothing has been promised that a failure here could break —
    // if either raising fails, its command simply says so.
    initPaging(infoAddress: multibootInfo)
    initHeap()

    // Wipe the screen the bootloader left behind: the grid emptied
    // and repainted — and on the framebuffer, the whole pixel field
    // blackened first — so the first word stands on a clean field.
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

    // The banner, at the top-left cell. A StaticString's bytes are
    // stored NUL-terminated in read-only data (Embedded Swift's trimmed
    // StaticString offers the pointer but not the length), so walk to
    // the terminator — and never past the edge of the first row.
    var cell = 0
    while cell < screenColumns {
        let character = cardnullBanner.utf8Start[cell]
        if character == 0 { break }
        putCell(row: 0, col: cell, character: character)
        cell += 1
    }

    // Ask the disc its name (milestone 8): the probe walks the
    // four IDE positions and keeps the first ATAPI drive that
    // answers, and the reader checks the disc's own signature.
    // The report is spoken now, on the banner's clean field, so
    // the shell opens beneath the news of what machine it is
    // running on — or the plain word that no drive answered,
    // which `ls` and `cat` will repeat when asked.
    initDisc()
    printDiscReport()

    // Prove the bundle, if one rode (milestone 23): magic,
    // table, checksum — spoken right under the disc's news,
    // so the boot transcript carries the source sentence
    // before the shell opens. A bundle that did not prove is
    // confessed here and never served from; the disc serves.
    validateBundle()
    printBundleReport()

    // Raise the interrupts: IDT, PICs, the 100 Hz heartbeat, and an
    // open gate. From here the machine can speak first — a keypress
    // no longer waits to be asked after, and the tick counts whether
    // anyone is watching or not. The raising stands before the
    // mouse's waking now (milestone 13): the waking's waits are
    // reckoned on this heartbeat, and it conducts its polled
    // conversation with the two input IRQs masked at the PICs, so
    // no handler reaches into its middle either.
    cardnullSetupInterrupts()

    // Wake the mouse (milestone 13): the full standard ceremony —
    // reset, self-test, name, defaults, reporting — every wait
    // bounded by the timer and every answer kept. The report is
    // spoken here, on the banner's clean field beneath the disc's
    // news, so the shell opens under the truth about the mouse
    // as it does under the truth about the disc.
    initMouse()
    printMouseReport()

    // The first prompt, and the cursor resting just past it.
    startLine()
    moveHardwareCursor()

    // The face is the front door now (milestone 13): with boot's
    // news spoken, the desktop opens on its own — the Terminal
    // window standing on it holds this very shell, so nothing is
    // lost by the move. The Welcome window's close box or Esc
    // brings the text shell home, and the gui command opens the
    // face again. A boot that brought no framebuffer has no face
    // to open; the shell simply keeps the room, as it always has.
    if useFramebuffer {
        runGui()
    }

    // The kernel's whole work, from here on: drain whatever the
    // keyboard handler has laid in the ring — echoing the typing and
    // answering the finished lines, exactly as the polling loop did —
    // and when the ring is empty, sleep until the next interrupt. A
    // keystroke that lands in the breath between the last look and
    // the sleep waits at most for the next heartbeat, a hundredth of
    // a second away, which no finger will ever notice.
    while true {
        while let code = nextScancode() {
            handleScancode(code)
        }
        // Milestone 29's citizenship: the wire is minded in the
        // idle breath before the sleep — the service itself
        // stands guard over when it may and may not run.
        netService()
        cardnullHltOnce()
    }
}
