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

// ---------------------------------------------------------------------------
// The screen.
//
// Two doors, one room (milestone 5). Behind the BIOS door the screen
// is the PC text grid: a memory-mapped array at physical address
// 0xB8000, 80 columns x 25 rows, two bytes per cell — the character,
// then its attribute (color). Behind the UEFI door there is no text
// grid at all: the firmware's graphics protocol hands over a linear
// framebuffer, a field of pixels, and letters must be drawn into it
// glyph by glyph from the floor's bitmap font.
//
// The kernel therefore keeps the characters itself now, in a grid
// the floor lends, and paints that grid through whichever screen is
// live. The choice is made once, at boot, from the Multiboot2
// information the floor preserved: a usable direct-color framebuffer
// tag means the framebuffer is the screen; otherwise the VGA text
// grid is. Everything above this layer — the echo, the scrolling,
// the shell reading its typed lines back — reads the kernel's grid
// and neither knows nor cares which door the machine came through.
//
// Milestone 1 wrote the banner and rested; milestone 2 kept a small
// conversation with the grid. Milestone 3 made it a true terminal:
// one door for all output (typed echo and the shell's answers walk
// through the same writeChar), and when the last row fills, the
// whole page lifts — scrolling, the way every terminal since the
// teletype has made room for the next line.
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

// ---------------------------------------------------------------------------
// Milestone 13: the shell has two homes — the console's own grid,
// and the Terminal window's smaller grid on the desktop. The four
// marks above belong to whichever home is active; each home's
// marks are kept aside while the other is in use, and the output
// door (writeChar and its kin) opens onto the active home alone.
// The Terminal's grid is 40 x 31: at the face's twofold glyph
// size that is a window a shell can honestly live in.
// ---------------------------------------------------------------------------

/// True while the output door opens onto the Terminal window's
/// grid — set exactly while the desktop stands with the window
/// open. Everything else in the kernel neither knows nor cares.
var consoleInTerminal = false

/// The Terminal grid's keeping and its visible shape. The
/// keeping is fixed — a stride of termStrideColumns and room
/// for termRowsCapacity rows, agreed with the floor — and the
/// storage never changes its layout. The visible shape,
/// termColumns by termRows, is reckoned from the Terminal
/// window's size whenever the window changes its shape
/// (milestone 14: it opens large, and can be maximized and
/// restored): only the visible window into the keeping moves,
/// and the cells beyond the visible shape are kept spaces, so
/// a typed line read back across a row's end meets nothing but
/// the spaces a wrapped line would imply. In milestone 13 the
/// two were one and the same — a fixed 40 x 31.
let termStrideColumns = 120
let termRowsCapacity = 64
var termColumns = 40
var termRows = 31

/// Each home's four marks, kept aside while the other is in use.
var textSavedCursorRow = typingTopRow
var textSavedCursorCol = 0
var textSavedLineStartRow = typingTopRow
var textSavedLineStartCol = 2
var termSavedCursorRow = 0
var termSavedCursorCol = 0
var termSavedLineStartRow = 0
var termSavedLineStartCol = 2

/// Whether the Terminal's conversation has been opened even
/// once: its first opening wipes its grid and lays its first
/// prompt; later openings take up its kept marks instead.
var termStarted = false

/// The Terminal's repaint bookkeeping: the span of its rows the
/// writing hands have touched since the face last painted them,
/// or -1 when the window stands exactly as painted. The face
/// repaints only the span — a keystroke's echo never repaints
/// the whole window.
var termDirtyTop = -1
var termDirtyBottom = -1

// ---------------------------------------------------------------------------
// Milestone 26: the Terminal's memory. Until now a line that
// lifted off the grid's top was gone — the conversation could
// not be read back, and Tyler's wheel, turned over the
// Terminal on his own desk, asked for a view the window did
// not keep. The keeping (the floor's cardnullTermHistory) now
// holds the lifted lines, and the window's view can stand
// lifted into them: the wheel turns it, the page keys walk
// it, and a keypress brings it home to the live end before
// the key is answered, so typing always lands in the present.
// ---------------------------------------------------------------------------

/// How many lifted lines the floor's keeping holds.
let termHistoryLines = 128

/// The lines that have lifted off the Terminal grid's top and
/// stand in the keeping, oldest first.
var termHistoryCount = 0

/// The view's lift: how many of the conversation's newest
/// lines stand hidden below the window while it reads older
/// ones. 0 is the live view — the conversation as it stands.
/// The lift is a distance from the conversation's end, and it
/// keeps that distance as new lines arrive: an arriving line
/// moves the read lines down a line, the way the page itself
/// moves — the view never pretends the conversation stood
/// still beneath it.
var termViewOffset = 0

/// Keeps one line that is lifting off the Terminal grid's
/// top: the whole stride-row moves into the keeping, and a
/// keeping already full lets its eldest go. Called by
/// scrollUp's Terminal road before the grid itself lifts.
func termHistoryKeepTopLine() {
    let grid = cardnullTermGrid()
    let history = cardnullTermHistory()
    if termHistoryCount == termHistoryLines {
        for line in 1 ..< termHistoryLines {
            for col in 0 ..< termStrideColumns {
                history[(line - 1) * termStrideColumns + col] =
                    history[line * termStrideColumns + col]
            }
        }
    } else {
        termHistoryCount += 1
    }
    let slot = (termHistoryCount - 1) * termStrideColumns
    for col in 0 ..< termStrideColumns {
        history[slot + col] = grid[col]
    }
}

/// The character one of the window's displayed rows shows at
/// a column, under the view's present lift: the lift's own
/// rows read the keeping's tail; the rows beneath read the
/// grid, shifted by the lift. The lift is clamped to the
/// keeping first — a view can never stand taller than the
/// memory that feeds it.
func termDisplayChar(_ displayRow: Int, _ col: Int) -> UInt8 {
    if termViewOffset > 0 {
        let lift = min(termViewOffset, termHistoryCount)
        if displayRow < lift {
            let line = termHistoryCount - lift + displayRow
            if line < 0 { return 0x20 }
            return cardnullTermHistory()[
                line * termStrideColumns + col]
        }
        return cardnullTermGrid()[
            (displayRow - lift) * termStrideColumns + col]
    }
    return cardnullTermGrid()[displayRow * termStrideColumns + col]
}

/// Scrolls the Terminal's view by whole lines — positive
/// toward the older lines, negative back toward the live
/// end — clamped at both ends of the conversation and
/// repainted whole where it stands, down filesScrollBy's
/// road: a scroll that cannot move paints nothing. While the
/// view stands lifted, the writing hands' dirty marks gather
/// unanswered (the face's loop leaves them standing); the
/// return to the live end answers them by wiping the slate —
/// the whole window has just been repainted from the grid.
func termScrollBy(_ lines: Int) {
    let target = min(max(termViewOffset + lines, 0),
                     termHistoryCount)
    if target == termViewOffset { return }
    termViewOffset = target
    pointerHide()
    guiPaintTerminal()
    pointerShow()
    if termViewOffset == 0 {
        termDirtyTop = -1
        termDirtyBottom = -1
    }
}

/// The active home's width and height — the one reckoning every
/// console hand below shares, so the shell's arithmetic is the
/// same in either home and only the numbers differ.
@inline(__always)
func consoleCols() -> Int {
    consoleInTerminal ? termColumns : screenColumns
}

@inline(__always)
func consoleRows() -> Int {
    consoleInTerminal ? termRows : screenRows
}

/// The active home's grid itself.
@inline(__always)
func activeGrid() -> UnsafeMutablePointer<UInt8> {
    consoleInTerminal ? cardnullTermGrid() : cardnullTextGrid()
}

/// The linear offset of one cell of the active home — the
/// stride being the grid's own keeping-width: the text grid's
/// 80, the Terminal keeping's fixed 120. The shell reads its
/// typed lines back by walking offsets reckoned here, so the
/// reading and the storage can never disagree when the
/// Terminal's visible width changes with its window.
@inline(__always)
func cellOffset(_ row: Int, _ col: Int) -> Int {
    row * (consoleInTerminal ? termStrideColumns : screenColumns) + col
}

/// Notes one Terminal row as touched by the writing hands.
func termMarkDirty(_ row: Int) {
    if termDirtyTop < 0 || row < termDirtyTop { termDirtyTop = row }
    if row > termDirtyBottom { termDirtyBottom = row }
}

/// Notes the whole Terminal grid as touched.
func termMarkAllDirty() {
    termDirtyTop = 0
    termDirtyBottom = termRows - 1
}

// ---------------------------------------------------------------------------
// Which screen is live, and the framebuffer's shape when it is.
//
// The boot floor preserved EBX: the address of the Multiboot2
// information structure GRUB built. It is a row of tags; the
// framebuffer tag (type 8) names the pixel field GRUB set up for us
// — its address, the bytes in one row of it (the pitch, which may
// pad past the visible width), its width and height in pixels, its
// depth, and where the red, green, and blue fields sit inside each
// pixel. The header asked for no particular mode; what GRUB
// actually set is what the tag says, and the kernel believes the
// tag, not the request.
// ---------------------------------------------------------------------------

/// True when the framebuffer is the screen (the UEFI door, or a BIOS
/// boot where GRUB set a graphics mode); false for the VGA text grid.
var useFramebuffer = false

/// The framebuffer's facts, read from the tag. The address is a
/// physical address inside the floor's 4 GiB identity map.
var framebufferAddress: UInt64 = 0
var framebufferPitch = 0
var framebufferWidth = 0
var framebufferHeight = 0
var framebufferBpp = 0

/// White, packed in the mode's own channel fields — each channel at
/// its full brightness, wherever the mode keeps it. Black is 0 in
/// any packing, so only white needs reckoning.
var framebufferWhite: UInt32 = 0

/// The framebuffer's channel layout, remembered from the tag:
/// where the red, green, and blue fields sit inside a pixel and
/// how wide each is. Milestone 5 needed only white and black,
/// which any packing renders the same; milestone 12's face paints
/// in colour, and colour must be packed in the mode's own fields
/// or it comes out as some other colour entirely. All six are 0
/// until a framebuffer is chosen.
var framebufferRedPosition = 0
var framebufferRedSize = 0
var framebufferGreenPosition = 0
var framebufferGreenSize = 0
var framebufferBluePosition = 0
var framebufferBlueSize = 0

/// The glyph magnification: 2 when the pixel field is roomy enough
/// (a cell becomes 16x16 pixels, near the text grid's own stature),
/// else 1 (8x8 cells, small but honest).
var glyphScale = 1

/// Little-endian readers for the boot information's raw bytes.
@inline(__always)
func bootInfoU32(_ base: UnsafeMutablePointer<UInt8>, _ offset: Int) -> UInt32 {
    UInt32(base[offset])
        | UInt32(base[offset + 1]) << 8
        | UInt32(base[offset + 2]) << 16
        | UInt32(base[offset + 3]) << 24
}

@inline(__always)
func bootInfoU64(_ base: UnsafeMutablePointer<UInt8>, _ offset: Int) -> UInt64 {
    UInt64(bootInfoU32(base, offset)) | UInt64(bootInfoU32(base, offset + 4)) << 32
}

/// Reads one channel's full-brightness contribution to the packed
/// white pixel: its field filled with ones, shifted to its place.
@inline(__always)
func channelWhite(_ position: UInt8, _ size: UInt8) -> UInt32 {
    if size == 0 { return 0 }
    if size >= 32 { return UInt32.max }
    return ((UInt32(1) << UInt32(size)) - 1) << UInt32(position)
}

/// Walks the Multiboot2 information tags and chooses the screen. A
/// direct-color (RGB) framebuffer of 24 or 32 bits per pixel, large
/// enough to hold the 80x25 grid of 8x8 glyphs, becomes the screen;
/// anything else — no tag, an indexed palette, a postage stamp —
/// leaves the VGA text grid in charge, exactly as milestones 1-4
/// found it.
func chooseScreen(infoAddress: UInt64) {
    if infoAddress == 0 { return }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let totalSize = Int(bootInfoU32(base, 0))
    var offset = 8
    while offset + 8 <= totalSize {
        let type = bootInfoU32(base, offset)
        let size = Int(bootInfoU32(base, offset + 4))
        if type == 0 || size < 8 { break }
        if type == 8 && size >= 38 {
            let address = bootInfoU64(base, offset + 8)
            let pitch = bootInfoU32(base, offset + 16)
            let width = bootInfoU32(base, offset + 20)
            let height = bootInfoU32(base, offset + 24)
            let bpp = base[offset + 28]
            let colorType = base[offset + 29]
            if address != 0 && colorType == 1 && (bpp == 32 || bpp == 24)
                && width >= UInt32(screenColumns * 8)
                && height >= UInt32(screenRows * 8) {
                framebufferAddress = address
                framebufferPitch = Int(pitch)
                framebufferWidth = Int(width)
                framebufferHeight = Int(height)
                framebufferBpp = Int(bpp)
                // The channel fields begin after a TWO-byte reserved
                // field (offsets 30-31) — the spec's quiet trap, and
                // the one this kernel fell into first: read a byte
                // early and red is reckoned from the reserved zero,
                // painting the whole screen cyan. Red at 32, green
                // at 34, blue at 36, each a position and a size.
                framebufferWhite =
                    channelWhite(base[offset + 32], base[offset + 33])
                    | channelWhite(base[offset + 34], base[offset + 35])
                    | channelWhite(base[offset + 36], base[offset + 37])
                framebufferRedPosition = Int(base[offset + 32])
                framebufferRedSize = Int(base[offset + 33])
                framebufferGreenPosition = Int(base[offset + 34])
                framebufferGreenSize = Int(base[offset + 35])
                framebufferBluePosition = Int(base[offset + 36])
                framebufferBlueSize = Int(base[offset + 37])
                useFramebuffer = true
            }
        }
        offset += (size + 7) & ~7
    }
    if useFramebuffer {
        glyphScale = framebufferWidth >= screenColumns * 16
            && framebufferHeight >= screenRows * 16 ? 2 : 1
    }
}

// ---------------------------------------------------------------------------
// Painting: the grid the kernel keeps, drawn through the live screen.
// ---------------------------------------------------------------------------

/// Reads back one character of the grid the kernel keeps. The shell
/// reads the typed line straight off this grid — what the typist
/// sees is literally what the kernel obeys, and no separate line
/// buffer exists to disagree with it.
@inline(__always)
func screenChar(cell offset: Int) -> UInt8 {
    activeGrid()[offset]
}

/// Writes one pixel of the framebuffer: white or black, at the
/// mode's own depth. At 24 bits the three channel bytes are simply
/// all-on or all-off — for pure white and pure black, the order of
/// the channels cannot matter, so no packing is needed there.
@inline(__always)
func putPixel(x: Int, y: Int, white on: Bool) {
    let rowStart = framebufferAddress + UInt64(y * framebufferPitch)
    if framebufferBpp == 32 {
        let pixel = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(rowStart + UInt64(x * 4)))!
        pixel.pointee = on ? framebufferWhite : 0
    } else {
        let pixel = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(rowStart + UInt64(x * 3)))!
        let value: UInt8 = on ? 0xFF : 0x00
        pixel[0] = value
        pixel[1] = value
        pixel[2] = value
    }
}

/// Draws one grid cell into the framebuffer: the glyph the grid
/// holds there, white on black, magnified by the glyph scale. The
/// cursor, when asked for, is an honest underline — the cell's
/// bottom two glyph rows lit solid, the way terminals have always
/// marked the place where the next letter lands.
func paintCellFramebuffer(row: Int, col: Int, underline: Bool) {
    let glyph = Int(screenChar(cell: row * screenColumns + col) & 0x7F)
    let font = cardnullFont8x8()
    let originX = col * 8 * glyphScale
    let originY = row * 8 * glyphScale
    for glyphY in 0 ..< 8 {
        let bits = font[glyph * 8 + glyphY]
        for glyphX in 0 ..< 8 {
            var on = bits & (UInt8(1) << UInt8(glyphX)) != 0
            if underline && glyphY >= 6 { on = true }
            for stepX in 0 ..< glyphScale {
                for stepY in 0 ..< glyphScale {
                    putPixel(x: originX + glyphX * glyphScale + stepX,
                             y: originY + glyphY * glyphScale + stepY,
                             white: on)
                }
            }
        }
    }
}

/// Paints one grid cell through whichever screen is live: a word
/// written into the VGA text buffer, or a glyph drawn into the
/// framebuffer. No cursor mark — the cursor is moveHardwareCursor's
/// affair.
func paintCell(row: Int, col: Int) {
    if useFramebuffer {
        paintCellFramebuffer(row: row, col: col, underline: false)
    } else {
        let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
        buffer[row * screenColumns + col] =
            UInt16(textAttribute) << 8
            | UInt16(screenChar(cell: row * screenColumns + col))
    }
}

/// Paints the whole grid, cell by cell. Scrolling and clearing both
/// end here: the grid is the truth, and the screen is made to match
/// it, so the two can never drift apart.
func repaintScreen() {
    for row in 0 ..< screenRows {
        for col in 0 ..< screenColumns {
            paintCell(row: row, col: col)
        }
    }
    framebufferCursorRow = -1
    framebufferCursorCol = -1
}

/// Writes one character into the grid and paints the cell it lands
/// in — the single act every screen change in the kernel is built
/// from, through either door.
@inline(__always)
func putCell(row: Int, col: Int, character: UInt8) {
    if consoleInTerminal {
        cardnullTermGrid()[row * termStrideColumns + col] = character
        termMarkDirty(row)
        return
    }
    cardnullTextGrid()[row * screenColumns + col] = character
    paintCell(row: row, col: col)
}

/// Where the framebuffer cursor's underline is currently drawn, or
/// -1 when it is nowhere (after a repaint, before its first move).
/// The VGA text screen has its own hardware cursor and needs no
/// such bookkeeping.
var framebufferCursorRow = -1
var framebufferCursorCol = -1

/// Moves the screen's own blinking cursor to the typing position, so
/// the eye can see where the next letter will land. In the text grid
/// the cursor's address lives in the display controller, spoken to
/// through ports 0x3D4 (which register) and 0x3D5 (its value):
/// register 0x0F takes the low byte of the cell offset, 0x0E the
/// high byte. In the framebuffer there is no hardware cursor, so
/// the kernel draws its own: the old cell repainted plain, the new
/// cell repainted with its underline.
func moveHardwareCursor() {
    if consoleInTerminal {
        // The face paints the Terminal's cursor itself; the
        // console's cursor machinery must not draw over it.
        return
    }
    if useFramebuffer {
        if framebufferCursorRow == cursorRow
            && framebufferCursorCol == cursorCol { return }
        if framebufferCursorRow >= 0 {
            paintCellFramebuffer(row: framebufferCursorRow,
                                 col: framebufferCursorCol, underline: false)
        }
        paintCellFramebuffer(row: cursorRow, col: cursorCol, underline: true)
        framebufferCursorRow = cursorRow
        framebufferCursorCol = cursorCol
        return
    }
    let position = cursorRow * consoleCols() + cursorCol
    cardnullOutb(0x3D4, 0x0F)
    cardnullOutb(0x3D5, UInt8(truncatingIfNeeded: position))
    cardnullOutb(0x3D4, 0x0E)
    cardnullOutb(0x3D5, UInt8(truncatingIfNeeded: position >> 8))
}

/// Lifts the whole page by one row: every row of the grid takes the
/// row beneath it, the last row is wiped clean for whatever comes
/// next, and the screen is repainted from the grid. The banner
/// scrolls away with everything else when the conversation outgrows
/// one screen — a real terminal keeps no favorites.
func scrollUp() {
    if consoleInTerminal {
        // The Terminal's road (milestone 26): the line that
        // lifts off the top is kept before it goes — the
        // conversation can be read back now.
        termHistoryKeepTopLine()
        let grid = cardnullTermGrid()
        for row in 1 ..< termRows {
            for col in 0 ..< termColumns {
                grid[(row - 1) * termStrideColumns + col] =
                    grid[row * termStrideColumns + col]
            }
        }
        for col in 0 ..< termColumns {
            grid[(termRows - 1) * termStrideColumns + col] = 0x20
        }
        if lineStartRow > 0 {
            lineStartRow -= 1
        } else {
            lineStartCol = 0
        }
        termMarkAllDirty()
        return
    }
    let grid = cardnullTextGrid()
    for row in 1 ..< screenRows {
        for col in 0 ..< screenColumns {
            grid[(row - 1) * screenColumns + col] =
                grid[row * screenColumns + col]
        }
    }
    for col in 0 ..< screenColumns {
        grid[(screenRows - 1) * screenColumns + col] = 0x20
    }
    if lineStartRow > 0 {
        lineStartRow -= 1
    } else {
        lineStartCol = 0
    }
    repaintScreen()
}

/// Writes one character at the cursor and advances — the kernel's one
/// door for output, used by the echo of a keystroke and by the shell's
/// answers alike. Advancing off the right edge wraps to the next row;
/// advancing off the bottom of the screen scrolls the page up and the
/// writing continues on the fresh last row.
func writeChar(_ character: UInt8) {
    putCell(row: cursorRow, col: cursorCol, character: character)
    cursorCol += 1
    if cursorCol == consoleCols() {
        cursorCol = 0
        cursorRow += 1
        if cursorRow == consoleRows() {
            scrollUp()
            cursorRow = consoleRows() - 1
        }
    }
}

/// Steps to the start of the next row, scrolling if the screen is
/// full. Output and prompts both begin a line this way.
func writeNewline() {
    cursorCol = 0
    cursorRow += 1
    if cursorRow == consoleRows() {
        scrollUp()
        cursorRow = consoleRows() - 1
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
        cursorCol = consoleCols() - 1
    } else {
        cursorCol -= 1
    }
    putCell(row: cursorRow, col: cursorCol, character: 0x20)
}

// ---------------------------------------------------------------------------
// The keyboard.
//
// What a key *means* is decided here: the translation of scancodes
// into characters. How a scancode *arrives* changed with milestone 4
// — it comes by interrupt now, through the ring buffer in the next
// section — but the meaning of each code is exactly what milestones 2
// and 3 taught the kernel, and it lives here unchanged.
//
// The controller speaks through two ports:
//
//   0x64  status: its lowest bit is set while a byte waits.
//   0x60  data:   the byte itself — a scancode, set 1.
//
// A key press sends its *make* code; a release sends the same code
// with the top bit set (the *break* code). Shift is tracked by hand:
// its makes set the flag, its breaks clear it. Caps Lock is a toggle:
// each press flips it, and it joins with Shift the way typewriters
// taught us — a letter is capital when exactly one of them is active.
// Milestone 3 completed the typewriter: every punctuation key of the
// main block, plain and shifted, joins the letters, digits, and space
// that milestone 2 took.
// ---------------------------------------------------------------------------

/// The keyboard controller's data door — the port the IRQ1 handler
/// takes each scancode from. (The status port, 0x64, belonged to the
/// polling years; nothing reads it now but the floor's one drain
/// before the interrupt gate opens.)
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
// Interrupts (milestone 4).
//
// Until now the kernel asked; now it is told. The floor has built an
// IDT, moved the PIC pair to vectors 0x20/0x28 where they no longer
// collide with the exceptions, and set the PIT ticking at 100 Hz.
// Two interrupts does the kernel take, and a third company it keeps
// against its will:
//
//   IRQ0  the timer: the machine's heartbeat, counted and nothing
//         more — everything time means is reckoned from the count,
//         outside the handler.
//   IRQ1  the keyboard: the handler takes the scancode out of the
//         controller and lays it in a small ring buffer, and the
//         shell drains the ring at its leisure through the same
//         handleScancode the polling years used.
//   IRQ12 the mouse (milestone 12): the handler takes one byte —
//         a third of a packet — out of the same controller and
//         lays it in the mouse's own ring; the graphical face
//         drains that ring and makes packets of the bytes. It
//         lives on the slave PIC, so its thanks are owed twice:
//         to the slave first, then to the master it hangs from.
//   0-31  the exceptions: a stub per vector, all ending here, in a
//         handler that prints one plain line and halts — a fault is
//         spoken aloud, never a silent triple fault in the dark.
//
// A handler's law in this kernel: touch only static state, do little,
// and always thank the PIC — an interrupt not acknowledged is the
// last one the machine will ever deliver.
// ---------------------------------------------------------------------------

/// The master PIC's command port. IRQ0 and IRQ1 both live on the
/// master, so both handlers send their thanks here; the word 0x20 is
/// the EOI command. (That it equals the port's number is a small
/// coincidence of the old design, nothing more.)
let picCommandPort: UInt16 = 0x20
let picEOI: UInt8 = 0x20

/// The heartbeat's count: ticks since boot, one per timer interrupt,
/// a hundred to the second. Written by the timer handler alone; read
/// by the uptime command. Everything time means in Cardnull OS today
/// is this one honest number.
var ticks: UInt64 = 0

/// IRQ0's whole work: count the tick, thank the PIC. Nothing else
/// happens in here — scheduling, sleeping, and everything yet
/// unbuilt will read the count from outside, at their leisure.
@_cdecl("cardnull_timer_interrupt")
public func timerInterrupt() {
    ticks &+= 1
    cardnullOutb(picCommandPort, picEOI)
}

/// The keyboard ring's shape: 64 slots, the number agreed with the
/// floor's storage in support.c. A power of two, so the wrap is a
/// mask, not a division.
let keyRingSize = 64

/// The ring's two hands. The keyboard handler fills at the head; the
/// shell drains at the tail. One slot is always left empty, so head
/// meeting tail unambiguously means "nothing waiting".
var keyRingHead = 0
var keyRingTail = 0

/// IRQ1's whole work: take the scancode out of the controller — the
/// read itself is what clears the controller to speak again — lay it
/// in the ring if there is room (if the ring is full, the byte is
/// let go; fingers are slower than this kernel, and a dropped
/// keystroke beats a wedged one), and thank the PIC.
///
/// One exception, milestone 15's: while a guest session stands,
/// the Esc make code is the session's key, not the shell's. It
/// is not rung; the stop word is set instead, and the floor's
/// timer ends the session inside a tick (a tenth of a second at
/// the outside) — the road home for a guest that never yields
/// and so never opens the door where it could be stopped. The
/// shell's own Esc rulings are untouched: no session stands
/// when they apply, and every other byte rings exactly as
/// before, session or none.
@_cdecl("cardnull_keyboard_interrupt")
public func keyboardInterrupt() {
    let code = cardnullInb(keyboardDataPort)
    if programRunning && code == 0x01 {
        cardnullSetStopRequest(1)
    } else {
        let next = (keyRingHead + 1) & (keyRingSize - 1)
        if next != keyRingTail {
            cardnullKeyRing()[keyRingHead] = code
            keyRingHead = next
        }
    }
    cardnullOutb(picCommandPort, picEOI)
}

/// Takes one waiting scancode out of the ring, or nil when the
/// keyboard has said nothing since the last look.
func nextScancode() -> UInt8? {
    if keyRingTail == keyRingHead { return nil }
    let code = cardnullKeyRing()[keyRingTail]
    keyRingTail = (keyRingTail + 1) & (keyRingSize - 1)
    return code
}

/// The slave PIC's command port. IRQ12 lives on the slave, so its
/// handler thanks the slave here — with the same EOI word the
/// master's handlers use — and then thanks the master as well, for
/// the cascade wire the knock arrived on. An interrupt thanked
/// only once, on the wrong chip, is the last one either delivers.
let picSlaveCommandPort: UInt16 = 0xA0

/// The mouse ring's shape: 256 slots, the number agreed with the
/// floor's storage in support.c. A power of two, so the wrap is a
/// mask, not a division.
let mouseRingSize = 256

/// The mouse ring's two hands, kept exactly as the keyboard's are:
/// the handler fills at the head; the face drains at the tail.
var mouseRingHead = 0
var mouseRingTail = 0

/// IRQ12's whole work: take the byte out of the controller — the
/// read itself is what clears the controller to speak again — lay
/// it in the mouse ring if there is room (a full ring lets the
/// byte go; a pointer's old news is not worth wedging the machine
/// for), and thank both PICs, the slave first and then the master.
/// What the byte means — which third of which packet — is the
/// face's business, below; the handler keeps no such company.
@_cdecl("cardnull_mouse_interrupt")
public func mouseInterrupt() {
    let byte = cardnullInb(keyboardDataPort)
    let next = (mouseRingHead + 1) & (mouseRingSize - 1)
    if next != mouseRingTail {
        cardnullMouseRing()[mouseRingHead] = byte
        mouseRingHead = next
    }
    cardnullOutb(picSlaveCommandPort, picEOI)
    cardnullOutb(picCommandPort, picEOI)
}

/// Takes one waiting byte out of the mouse ring, or nil when the
/// mouse has said nothing since the last look.
func nextMouseByte() -> UInt8? {
    if mouseRingTail == mouseRingHead { return nil }
    let byte = cardnullMouseRing()[mouseRingTail]
    mouseRingTail = (mouseRingTail + 1) & (mouseRingSize - 1)
    return byte
}

/// The exceptions' one answer. A fault leaves no promise standing —
/// not the cursor's bookkeeping, not the screen's story — so the
/// line is written into the top row of the grid, over whatever was
/// there, and painted through whichever screen is live; then the
/// machine rests with its gate closed. No vector number, no register
/// dump: one plain sentence, honestly.
let exceptionLine: StaticString = "Exception - halting."

@_cdecl("cardnull_exception_handler")
public func exceptionHandler(_ vector: UInt64) {
    cardnullCli()
    var index = 0
    while true {
        let character = exceptionLine.utf8Start[index]
        if character == 0 { break }
        putCell(row: 0, col: index, character: character)
        index += 1
    }
    cardnullHalt()
}

// ---------------------------------------------------------------------------
// The page fault's answer (milestone 7).
//
// Vector 14 no longer shares the exceptions' one plain sentence.
// Since the kernel keeps its own page tables, a page fault is a
// report the machine owes in detail: the processor kept the address
// that was reached for in CR2 and a small testimony of the reaching
// in the error code, and the floor's hand-written stub for this one
// vector carries both up. The handler below writes the report into
// the top rows of the grid — over whatever was there, exactly as
// the exception line above does, because a fault leaves no promise
// standing — and then rests the machine with its gate closed: a
// controlled halt, never a reboot loop. Nothing here tries to fix
// the fault and resume; there is nothing yet that could honestly
// be resumed into. That day may come with programs of our own.
// ---------------------------------------------------------------------------

/// Writes a static string into one grid row starting at a column,
/// through putCell like everything drawn after a fault, and
/// returns the column just past its last character.
func writeStaticAt(_ row: Int, _ startCol: Int, _ text: StaticString) -> Int {
    var col = startCol
    var index = 0
    while col < consoleCols() {
        let character = text.utf8Start[index]
        if character == 0 { break }
        putCell(row: row, col: col, character: character)
        col += 1
        index += 1
    }
    return col
}

/// Writes a value in hexadecimal into one grid row — addresses and
/// error codes are hex by long custom, and the report speaks them
/// so — with exactly the digits asked for, leading zeros kept.
func writeHexAt(_ row: Int, _ startCol: Int, _ value: UInt64,
                _ digits: Int) -> Int {
    var col = startCol
    var shift = (digits - 1) * 4
    while shift >= 0 && col < consoleCols() {
        let nibble = UInt8((value >> UInt64(shift)) & 0xF)
        let character: UInt8 = nibble < 10 ? 0x30 + nibble
                                           : 0x41 + (nibble - 10)
        putCell(row: row, col: col, character: character)
        col += 1
        shift -= 4
    }
    return col
}

/// Writes a value in decimal into one grid row: the digits reckoned
/// by a falling divisor, the same trick writeNumber walks on the
/// shell's road, here onto fixed cells of a report that cannot
/// scroll.
func writeDecimalAt(_ row: Int, _ startCol: Int, _ value: UInt64) -> Int {
    var col = startCol
    var divisor: UInt64 = 1
    while value / divisor >= 10 { divisor *= 10 }
    var remaining = value
    while true {
        if col < consoleCols() {
            putCell(row: row, col: col,
                    character: 0x30 + UInt8(remaining / divisor))
            col += 1
        }
        remaining %= divisor
        if divisor == 1 { break }
        divisor /= 10
    }
    return col
}

/// The page fault report's vocabulary: the title and labels, and
/// the error code's testimony taken apart into words — present or
/// not, the kind of reaching, whose mode, and the reserved-bit and
/// instruction-fetch flags when they stand.
let pageFaultTitle: StaticString = "Page fault - halting."
let pageFaultGuestTitle: StaticString =
    "Page fault in a guest program - the guest was stopped."
let pageFaultAddressLabel: StaticString = "  Address: 0x"
let pageFaultErrorLabel: StaticString = "  Error code: 0x"
let pageFaultOpenParen: StaticString = " ("
let pageFaultCloseParen: StaticString = ")"
let pageFaultComma: StaticString = ", "
let reasonNotPresent: StaticString = "page not present"
let reasonProtection: StaticString = "protection violation"
let reasonWrite: StaticString = "write"
let reasonRead: StaticString = "read"
let reasonFetch: StaticString = "instruction fetch"
let reasonUser: StaticString = "user mode"
let reasonSupervisor: StaticString = "supervisor mode"
let reasonReserved: StaticString = "reserved bit set"

/// Vector 14's own handler, called by the floor's hand-written
/// stub with the two facts the processor kept: the error code it
/// pushed and the CR2 address.
///
/// Two roads since milestone 9. The old road — a fault of the
/// kernel's own, in supervisor mode — writes the report and halts,
/// cleanly, with the gate closed, and never returns; faulttest
/// still walks it. The new road is a fault in user mode while a
/// guest program runs: the same report is written under the
/// guest's title, and then, instead of the halt, the floor's
/// abandon hand carries the machine home — the guest is stopped
/// where it stands, and the shell that launched it receives the
/// verdict and answers for it below. A user-mode fault with no
/// guest running keeps the old road: it cannot happen by any road
/// the kernel knows, and honesty halts on it.
///
/// Milestone 10 forks the new road once more: while a pair
/// session stands, the abandon hand is the pair's own, which
/// writes the fallen guest down as stopped and takes the machine
/// to its partner — the report above is the fallen guest's whole
/// obituary, and the survivor runs on in the same session, in its
/// own ground, exactly where it last stood.
@_cdecl("cardnull_page_fault_handler")
public func pageFaultHandler(_ errorCode: UInt64, _ faultAddress: UInt64) {
    cardnullCli()
    if programRunning && errorCode & 0x4 != 0 {
        programFaultAddress = faultAddress
        programFaultError = errorCode
        printPageFaultReport(errorCode, faultAddress, pageFaultGuestTitle)
        if pairRunning {
            cardnullAbandonGuestInPair(programKilledVerdict)
        }
        cardnullAbandonProgram(programKilledVerdict)
    }
    printPageFaultReport(errorCode, faultAddress, pageFaultTitle)
    cardnullHalt()
}

/// The report itself — title, faulting address, error code in hex
/// and in words — written onto fixed rows, because a report is no
/// place for scrolling.
func printPageFaultReport(_ errorCode: UInt64, _ faultAddress: UInt64,
                          _ title: StaticString) {
    _ = writeStaticAt(0, 0, title)
    var col = writeStaticAt(1, 0, pageFaultAddressLabel)
    _ = writeHexAt(1, col, faultAddress, 16)
    col = writeStaticAt(2, 0, pageFaultErrorLabel)
    col = writeHexAt(2, col, errorCode, 4)
    col = writeStaticAt(2, col, pageFaultOpenParen)
    if errorCode & 0x10 != 0 {
        col = writeStaticAt(2, col, reasonFetch)
    } else if errorCode & 0x2 != 0 {
        col = writeStaticAt(2, col, reasonWrite)
    } else {
        col = writeStaticAt(2, col, reasonRead)
    }
    col = writeStaticAt(2, col, pageFaultComma)
    col = writeStaticAt(2, col,
                        errorCode & 0x1 != 0 ? reasonProtection
                                             : reasonNotPresent)
    col = writeStaticAt(2, col, pageFaultComma)
    col = writeStaticAt(2, col,
                        errorCode & 0x4 != 0 ? reasonUser
                                             : reasonSupervisor)
    if errorCode & 0x8 != 0 {
        col = writeStaticAt(2, col, pageFaultComma)
        col = writeStaticAt(2, col, reasonReserved)
    }
    _ = writeStaticAt(2, col, pageFaultCloseParen)
}

// ---------------------------------------------------------------------------
// Memory (milestone 6).
//
// The kernel stops merely standing in the machine's RAM and learns
// its shape. GRUB's word about the machine — the same Multiboot2
// information the screen was chosen from — carries a memory map
// (tag type 6): a row of regions, each a base, a length, and a
// kind, and only kind 1 is RAM a kernel may use. The kernel reads
// that map once, at boot, and builds a page-frame allocator over
// it: one bit per 4 KiB frame in storage the floor lends, a set bit
// meaning "spoken for" and a clear bit "free to hand out".
//
// The allocator's honesty rules:
//
//   - Every frame begins life spoken for. Only frames lying wholly
//     inside a region the map calls available RAM are ever cleared
//     into the free pool — so holes, firmware reservations, and
//     anything the map does not name stay untouchable.
//   - Reservations are then laid back over the pool: the first
//     mebibyte (the BIOS's own country), the kernel image itself
//     (the linker's bounds, lent by the floor), the framebuffer
//     when one is live, the Multiboot2 information itself, and
//     every frame any non-available region so much as touches.
//   - The counts the `mem` command speaks — usable RAM, total
//     frames, free frames, used frames — are reckoned from the map
//     and the bitmap at runtime. Nothing is remembered from the
//     build machine; nothing is invented.
//
// Frames beyond the bitmap's reach — past the first 4 GiB, which is
// also as far as the boot floor's identity map reaches — are not
// managed yet; the usable-bytes figure still counts them honestly
// from the map, and the frame pool covers what the kernel can
// actually touch. Nothing is paged and there is no heap: handing
// frames out, one by one, is this milestone's whole work.
// ---------------------------------------------------------------------------

/// The frame's size: 4 KiB, the processor's small page.
let pageSize: UInt64 = 4096

/// The bitmap's size in bytes, agreed with the floor's storage in
/// support.c. Eight bits to the byte, so this many bytes of bitmap
/// speak for frameBitmapCapacityBytes * 8 frames — 1,048,576 of
/// them, the whole first 4 GiB.
let frameBitmapCapacityBytes = 131072
let maxManagedFrames = 1048576

/// Did the bootloader hand over a memory map at all? Until it is
/// read, every count below is zero and `mem` says so plainly.
var memMapFound = false

/// The map's own testimony: the total length of every region it
/// calls available RAM, in bytes, counted exactly as written.
var memTotalUsableBytes: UInt64 = 0

/// How many 4 KiB frames lie wholly inside those available regions
/// (and within the bitmap's reach). This is the allocator's whole
/// estate: free frames plus used frames always equals it.
var memTotalFrames: UInt64 = 0

/// How many of those frames are free to hand out right now. Kept by
/// hand alongside the bitmap — every reserve, allocation, and free
/// moves it by exactly the frames it moves — so the `mem` answer
/// never has to recount a million bits.
var memFreeFrames: UInt64 = 0

/// The highest frame number the bitmap must cover: one past the
/// last frame of the last available region, within reach.
var memSpanFrames = 0

/// Where the allocator's search for a free frame resumes. Freed
/// frames lower it again, so a freed frame is the next one handed
/// out — which is also what makes the self-test below able to watch
/// a frame come back.
var memAllocHint = 0

/// The self-test's verdict, spoken by `mem`: at boot, once the
/// reservations are laid, the allocator takes two frames, gives one
/// back, takes another, gives all back — and passes only if every
/// taking succeeded, no two holdings were the same frame, and the
/// free count came home exactly to where it began.
var memSelfTestOK = false

/// Finds one tag in the Multiboot2 information, by type, and
/// returns its offset — or -1 when the bootloader left no such tag.
/// The tag walk the screen-choosing used, shared now with memory.
func findTagOffset(_ wanted: UInt32, infoAddress: UInt64) -> Int {
    if infoAddress == 0 { return -1 }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let totalSize = Int(bootInfoU32(base, 0))
    var offset = 8
    while offset + 8 <= totalSize {
        let type = bootInfoU32(base, offset)
        let size = Int(bootInfoU32(base, offset + 4))
        if type == 0 || size < 8 { break }
        if type == wanted { return offset }
        offset += (size + 7) & ~7
    }
    return -1
}

/// The first frame lying wholly inside a region that starts at the
/// given address: the region's base rounded up to a frame boundary,
/// capped at the bitmap's reach.
@inline(__always)
func availStartFrame(_ regionBase: UInt64) -> Int {
    let frame = Int((regionBase + pageSize - 1) / pageSize)
    return frame > maxManagedFrames ? maxManagedFrames : frame
}

/// One past the last frame lying wholly inside the region: its end
/// rounded down, capped the same way.
@inline(__always)
func availEndFrame(_ regionBase: UInt64, _ regionLength: UInt64) -> Int {
    let frame = Int((regionBase + regionLength) / pageSize)
    return frame > maxManagedFrames ? maxManagedFrames : frame
}

/// One frame's bit: true when the frame is spoken for.
@inline(__always)
func frameIsUsed(_ frame: Int) -> Bool {
    cardnullFrameBitmap()[frame >> 3]
        & (UInt8(1) << UInt8(frame & 7)) != 0
}

/// Sets one frame's bit. The counts are the callers' affair; this
/// only speaks to the bitmap.
@inline(__always)
func setFrameUsed(_ frame: Int, _ used: Bool) {
    let bitmap = cardnullFrameBitmap()
    let mask = UInt8(1) << UInt8(frame & 7)
    if used {
        bitmap[frame >> 3] |= mask
    } else {
        bitmap[frame >> 3] &= ~mask
    }
}

/// Lays a reservation over every frame the given range so much as
/// touches — a range's frames are reckoned outward, first frame at
/// the range's floor, end at its ceiling, because a frame half
/// covered by the kernel is wholly unusable. Only frames currently
/// free move the count; reserving a hole reserves nothing twice.
func reserveRange(base: UInt64, length: UInt64) {
    if length == 0 { return }
    var frame = Int(base / pageSize)
    var end = Int((base + length + pageSize - 1) / pageSize)
    if end > memSpanFrames { end = memSpanFrames }
    while frame < end {
        if !frameIsUsed(frame) {
            setFrameUsed(frame, true)
            memFreeFrames -= 1
        }
        frame += 1
    }
}

/// Reads the bootloader's memory map and raises the allocator over
/// it. Called once from kmain, after the screen is chosen (the
/// framebuffer's range is one of the reservations) and before the
/// shell opens. If no map came, nothing is raised and `mem` will
/// say so — the shell runs on exactly as before, standing in RAM it
/// simply cannot describe.
func initMemory(infoAddress: UInt64) {
    if infoAddress == 0 { return }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let tagOffset = findTagOffset(6, infoAddress: infoAddress)
    if tagOffset < 0 { return }
    let tagSize = Int(bootInfoU32(base, tagOffset + 4))
    let entrySize = Int(bootInfoU32(base, tagOffset + 8))
    if entrySize < 24 || tagSize < 16 { return }
    let entryCount = (tagSize - 16) / entrySize
    let entriesStart = tagOffset + 16
    let bitmap = cardnullFrameBitmap()

    // First pass: the estate's measure. Count the available
    // regions' bytes exactly as the map writes them, and the whole
    // frames lying inside them, and learn how wide a bitmap the
    // machine's RAM needs.
    var index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        let regionBase = bootInfoU64(base, entry)
        let regionLength = bootInfoU64(base, entry + 8)
        if bootInfoU32(base, entry + 16) == 1 {
            memTotalUsableBytes += regionLength
            let start = availStartFrame(regionBase)
            let end = availEndFrame(regionBase, regionLength)
            if end > start {
                memTotalFrames += UInt64(end - start)
                if end > memSpanFrames { memSpanFrames = end }
            }
        }
        index += 1
    }
    if memSpanFrames == 0 { return }

    // Every frame begins life spoken for: the bitmap is filled with
    // ones, so any frame the map does not expressly free — holes,
    // reservations, the unmapped dark — can never be handed out.
    for byteIndex in 0 ..< frameBitmapCapacityBytes {
        bitmap[byteIndex] = 0xFF
    }

    // Second pass: the available regions' frames are cleared into
    // the free pool.
    index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        let regionBase = bootInfoU64(base, entry)
        let regionLength = bootInfoU64(base, entry + 8)
        if bootInfoU32(base, entry + 16) == 1 {
            var frame = availStartFrame(regionBase)
            let end = availEndFrame(regionBase, regionLength)
            while frame < end {
                setFrameUsed(frame, false)
                frame += 1
            }
        }
        index += 1
    }
    memFreeFrames = memTotalFrames

    // The reservations, laid back over the pool.
    reserveRange(base: 0, length: 0x100000)          // the first mebibyte
    let kernelStart = cardnullKernelStart()
    let kernelEnd = cardnullKernelEnd()
    if kernelEnd > kernelStart {
        reserveRange(base: kernelStart, length: kernelEnd - kernelStart)
    }
    if useFramebuffer {
        reserveRange(base: framebufferAddress,
                     length: UInt64(framebufferPitch * framebufferHeight))
    }
    reserveRange(base: infoAddress,
                 length: UInt64(bootInfoU32(base, 0)))   // the map itself
    if bootModuleEnd > bootModuleStart {
        // The bundle's span (milestone 23): the cargo is not
        // the yard — its frames stand in mem's used count and
        // are never handed to the heap or a guest.
        reserveRange(base: bootModuleStart,
                     length: bootModuleEnd - bootModuleStart)
    }

    // Third pass: anything the map does not call available RAM —
    // ACPI tables, firmware reservations, the PCI dark — keeps any
    // available frame it touches out of the pool for good.
    index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        if bootInfoU32(base, entry + 16) != 1 {
            reserveRange(base: bootInfoU64(base, entry),
                         length: bootInfoU64(base, entry + 8))
        }
        index += 1
    }

    memMapFound = true
    runMemorySelfTest()
}

/// Hands out one free frame and returns its physical address, or 0
/// when the pool is empty — 0 is never a true answer, since frame
/// zero is reserved from the beginning and can never be handed out.
/// The search resumes where the last one ended, so frames are dealt
/// in order and a just-freed frame is found again at once.
func allocFrame() -> UInt64 {
    if !memMapFound || memSpanFrames == 0 { return 0 }
    var looked = 0
    while looked < memSpanFrames {
        let frame = memAllocHint + looked < memSpanFrames
            ? memAllocHint + looked
            : memAllocHint + looked - memSpanFrames
        if !frameIsUsed(frame) {
            setFrameUsed(frame, true)
            memFreeFrames -= 1
            memAllocHint = frame + 1
            if memAllocHint >= memSpanFrames { memAllocHint = 0 }
            return UInt64(frame) * pageSize
        }
        looked += 1
    }
    return 0
}

/// Gives one frame back to the pool. The caller's word is the only
/// guard: a frame may be freed only by whoever took it from
/// allocFrame — freeing a reservation would hand the kernel's own
/// ground to the next taker, and nothing in this young allocator
/// can tell the difference yet. Milestone 7's heap will keep books;
/// today, the kernel frees only what it took, in the self-test.
func freeFrame(_ address: UInt64) {
    if address % pageSize != 0 { return }
    let frame = Int(address / pageSize)
    if frame <= 0 || frame >= memSpanFrames { return }
    if frameIsUsed(frame) {
        setFrameUsed(frame, false)
        memFreeFrames += 1
        if frame < memAllocHint { memAllocHint = frame }
    }
}

/// The allocator's proof of life, run once at boot: take two
/// frames, give one back, take another, give everything back —
/// passing only if every taking succeeded, no two holdings were
/// ever the same frame, and the free count comes home exactly to
/// where it began. Its verdict rides in memSelfTestOK, and `mem`
/// speaks it; if it ever failed, the counts would still be true,
/// and the failure would be on the screen for anyone to see.
func runMemorySelfTest() {
    let before = memFreeFrames
    let first = allocFrame()
    let second = allocFrame()
    if first == 0 || second == 0 || first == second {
        if first != 0 { freeFrame(first) }
        if second != 0 { freeFrame(second) }
        memSelfTestOK = false
        return
    }
    freeFrame(first)
    let third = allocFrame()
    if third == 0 {
        freeFrame(second)
        memSelfTestOK = false
        return
    }
    freeFrame(second)
    freeFrame(third)
    memSelfTestOK = memFreeFrames == before
}


// ---------------------------------------------------------------------------
// Paging (milestone 7).
//
// Until now the kernel has run on borrowed tables: the boot floor
// built one identity map of the first 4 GiB — every page present,
// writable, executable — and the kernel simply stood in it. That
// was the floor's honest scaffolding, and scaffolding is not a
// house. Now the kernel builds tables of its own and moves in:
//
//   - Four levels, 4 KiB leaves, identity-mapped — a page's virtual
//     address is still its physical address, which is the truthful
//     shape for a kernel this young — but only for what is honestly
//     the kernel's to stand on: the usable RAM the bootloader's map
//     names, the kernel image, the live framebuffer, the VGA text
//     page that is the fallback screen, and the bootloader's own
//     information. Everything else — the PCI dark, the firmware's
//     country, the holes — is simply not there, and reaching for it
//     faults, by the page-fault handler's report above.
//   - The tables' frames are taken from the milestone-6 allocator,
//     so the map is built out of the very memory it describes.
//   - W^X, the first law of the hardening road, is laid in the
//     leaves: the kernel's text pages executable and not writable;
//     its read-only data neither writable nor executable; every
//     other mapped page writable and NOT executable. Nothing in
//     the kernel's world is both writable and executable.
//   - The switch itself is three breaths: build the tables while
//     the floor's map still carries the machine, raise EFER's NXE
//     (so the no-execute bit is law, not a reserved-bit fault),
//     and load CR3. If the shell answers afterward — screen,
//     keyboard, heartbeat, and all — the tables are the machine's
//     truth, and there is no stronger proof this milestone can
//     offer.
//
// The branch entries (PML4, PDPT, PD) carry present|writable and
// no law of their own: the leaf decides, as the processor's own
// rule reckons the strictest word along the walk. User pages did
// not exist when this was written — there were no users; every
// page was the kernel's, supervisor-only. Milestone 9's guests
// are the first exception, and they receive their user pages in
// cloned tables of their own, never in these.
// ---------------------------------------------------------------------------

/// The leaf flags of the kernel's three countries.
let ptePresent: UInt64 = 0x1
let pteWritable: UInt64 = 0x2
let pteNoExecute: UInt64 = 0x8000_0000_0000_0000

/// A fourth flag, no country's law but the guests': the user bit —
/// the difference between ground ring 3 may touch and ground it
/// may only be shown the wall of. It is never set in the kernel's
/// own tables; milestone 9 sets it only inside a guest's cloned
/// tables, on the one branch that leads to the guest's estate and
/// on that estate's leaves (see the programs section below).
let pteUser: UInt64 = 0x4

/// Did our own tables take over? Until the CR3 switch is behind
/// us this is false, and the fault test below will not pretend
/// otherwise: on the floor's borrowed map, everything answers.
var pagingReady = false

/// The physical address of our PML4 — a frame of the allocator's,
/// like every table below it.
var pagingRootAddress: UInt64 = 0

/// One entry of a page table, read or written through the identity
/// map both the floor's tables and ours keep.
@inline(__always)
func pagingEntry(_ table: UInt64, _ index: Int) -> UInt64 {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(table))![index]
}

@inline(__always)
func setPagingEntry(_ table: UInt64, _ index: Int, _ value: UInt64) {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(table))![index] = value
}

/// The frame-address mask of a table entry: the bits that are the
/// next table's (or the page's) physical address.
let pagingAddressMask: UInt64 = 0x000F_FFFF_FFFF_F000

/// Takes one frame from the allocator and wipes it clean — a
/// newborn table must read as all-absent, or the walk below would
/// follow yesterday's noise into the dark. Returns 0 when the pool
/// cannot pay, which the caller treats as the whole raising failed.
func pagingNewTable() -> UInt64 {
    let frame = allocFrame()
    if frame == 0 { return 0 }
    let entries = UnsafeMutablePointer<UInt64>(bitPattern: UInt(frame))!
    for index in 0 ..< 512 {
        entries[index] = 0
    }
    return frame
}

/// Maps one 4 KiB page, identity — the page's virtual address is
/// its physical address — under the given leaf flags, growing
/// branch tables along the walk as the allocator can pay for them.
/// A page already mapped is simply re-stamped: the later, more
/// particular law wins, which is how the kernel image's countries
/// are drawn over the RAM they stand in.
func mapPage(_ address: UInt64, _ leafFlags: UInt64) -> Bool {
    var table = pagingRootAddress
    var shift = 39
    while shift >= 21 {
        let index = Int((address >> UInt64(shift)) & 0x1FF)
        var entry = pagingEntry(table, index)
        if entry & ptePresent == 0 {
            let fresh = pagingNewTable()
            if fresh == 0 { return false }
            entry = fresh | ptePresent | pteWritable
            setPagingEntry(table, index, entry)
        }
        table = entry & pagingAddressMask
        shift -= 9
    }
    setPagingEntry(table, Int((address >> 12) & 0x1FF),
                   (address & ~UInt64(0xFFF)) | leafFlags)
    return true
}

/// Maps a whole range, page by page: the range's own pages are the
/// ones its floor and ceiling name, so a range ending mid-page does
/// not drag its neighbour in.
func mapRange(_ base: UInt64, _ length: UInt64,
              _ leafFlags: UInt64) -> Bool {
    if length == 0 { return true }
    var address = base & ~UInt64(0xFFF)
    let end = (base + length + pageSize - 1) & ~UInt64(0xFFF)
    while address < end {
        if !mapPage(address, leafFlags) { return false }
        address += pageSize
    }
    return true
}

/// Builds the kernel's own page tables and moves the machine into
/// them. Called once from kmain, after the frame allocator stands
/// (the tables are its frames) and before the interrupts open (a
/// fault mid-switch would have no IDT to catch it — but the whole
/// building happens under the floor's still-standing map, and the
/// switch itself is a single instruction with the screen, stack,
/// and code already mapped on the far side). If anything cannot be
/// paid for, the raising stops, pagingReady stays false, and the
/// kernel goes on standing on the floor's tables exactly as
/// before — poorer, but honest about it.
func initPaging(infoAddress: UInt64) {
    if !memMapFound || infoAddress == 0 { return }
    let base = UnsafeMutablePointer<UInt8>(bitPattern: UInt(infoAddress))!
    let tagOffset = findTagOffset(6, infoAddress: infoAddress)
    if tagOffset < 0 { return }
    let tagSize = Int(bootInfoU32(base, tagOffset + 4))
    let entrySize = Int(bootInfoU32(base, tagOffset + 8))
    if entrySize < 24 || tagSize < 16 { return }
    let entryCount = (tagSize - 16) / entrySize
    let entriesStart = tagOffset + 16

    pagingRootAddress = pagingNewTable()
    if pagingRootAddress == 0 { return }

    let ramFlags = ptePresent | pteWritable | pteNoExecute

    // The usable RAM, reckoned afresh from the map — the same
    // estate the allocator keeps, whole frames only, and nothing
    // past the first 4 GiB, which is this kernel's whole reach
    // today. Table frames are taken as the building goes; every
    // one of them lies inside this estate and is mapped by it.
    var index = 0
    while index < entryCount {
        let entry = entriesStart + index * entrySize
        if bootInfoU32(base, entry + 16) == 1 {
            let regionBase = bootInfoU64(base, entry)
            var regionEnd = regionBase &+ bootInfoU64(base, entry + 8)
            if regionBase < 0x1_0000_0000 {
                if regionEnd > 0x1_0000_0000 { regionEnd = 0x1_0000_0000 }
                let wholeEnd = regionEnd & ~UInt64(0xFFF)
                if wholeEnd > regionBase {
                    if !mapRange(regionBase, wholeEnd - regionBase,
                                 ramFlags) { return }
                }
            }
        }
        index += 1
    }

    // The bootloader's own information: the kernel reads it and
    // never writes it, so it comes back read-only — and not
    // executable, like everything that is not code.
    let infoSize = UInt64(bootInfoU32(base, 0))
    if infoSize > 0 {
        if !mapRange(infoAddress, infoSize,
                     ptePresent | pteNoExecute) { return }
    }

    // The VGA text page — the fallback screen behind a boot with
    // no framebuffer — writable device memory, never code.
    if !mapRange(0xB8000, pageSize, ramFlags) { return }

    // The live framebuffer, when there is one: the screen the
    // kernel is painting this very moment.
    if useFramebuffer {
        if !mapRange(framebufferAddress,
                     UInt64(framebufferPitch * framebufferHeight),
                     ramFlags) { return }
    }

    // The kernel image's own countries, drawn over the RAM they
    // stand in: read-only data first, then the text — so any page
    // the two spans somehow shared would end under the stricter
    // law of the two.
    let rodataStart = cardnullRodataStart()
    let rodataEnd = cardnullRodataEnd()
    if rodataEnd > rodataStart {
        if !mapRange(rodataStart, rodataEnd - rodataStart,
                     ptePresent | pteNoExecute) { return }
    }
    let textStart = cardnullTextStart()
    let textEnd = cardnullTextEnd()
    if textEnd > textStart {
        if !mapRange(textStart, textEnd - textStart,
                     ptePresent) { return }
    }

    // The switch: NXE first (the tables about to load are full of
    // the bit), then CR3. The instruction after the load already
    // walks the new tables; the stack under us and the screen
    // before us are mapped on both sides of it.
    cardnullEnableNxe()
    cardnullLoadCr3(pagingRootAddress)
    pagingReady = true
}

/// The address the `faulttest` command reaches for: a page in the
/// third gigabyte's high country, where no RAM, no frame buffer,
/// and no device of this machine has ever lived — under our own
/// tables, simply not there.
let faultTestAddress: UInt64 = 0xDEAD0000

/// Reaches for one byte at the fault test's address and brings it
/// back — a plain load through a raw pointer, marked never-inline
/// so the reach is a real reach and not a compiler's rumour of one.
/// Under honest paging this function is never allowed to return.
@inline(never)
func touchUnmapped() -> UInt8 {
    let pointer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(faultTestAddress))!
    return pointer.pointee
}


// ---------------------------------------------------------------------------
// The heap (milestone 7).
//
// Frames are honest, but they are coarse: a program — and a kernel
// with work ahead of it — needs memory in the sizes the work asks
// for, not only in 4 KiB slabs. So the kernel now keeps a heap: one
// unbroken field of frames taken from the allocator at boot, and
// within it a chain of blocks, each carrying a small header — its
// whole size, and whether it is spoken for. Allocation is
// first-fit: the first free block that can hold the ask is taken,
// and split when the remainder is still a block worth keeping.
// Freeing marks the block free and then walks the chain once,
// marrying each pair of neighbouring free blocks back into one —
// so the field does not shatter into splinters as work comes and
// goes.
//
// The books are kept by walking that same chain: used bytes and
// free bytes are the sums of the blocks' whole sizes, headers
// included, and used plus free always equals the region's size —
// the partition is the truth, and `heap` speaks it. The heap's
// pages are the RAM pages they are: writable, never executable,
// under the kernel's own tables.
//
// The heap stands in its own field and nowhere else: a request it
// cannot answer gets 0, never a neighbour's memory. And one law
// from the frame allocator still holds — the heap hands out only
// what it took; frames it borrowed are its estate for the kernel's
// whole life, returned to the pool never (what would the kernel
// do with an empty workbench?).
// ---------------------------------------------------------------------------

/// The heap's whole estate: 4 MiB of frames, a workbench sized for
/// the work ahead — filesystems and programs will want buffers —
/// and a small, honest fraction of the machines we run on.
let heapRegionBytes: UInt64 = 4 * 1024 * 1024

/// Every block begins with two words: its whole size in bytes
/// (header included) and its state — 1 spoken for, 0 free.
let heapHeaderBytes: UInt64 = 16

/// The smallest block worth keeping when a split leaves a
/// remainder: header plus one aligned payload word.
let heapMinBlockBytes: UInt64 = 32

/// Was a heap raised at all? Without the frame allocator there is
/// nothing to raise one from, and `heap` will say so plainly.
var heapReady = false

/// The heap field's first address; its size is heapRegionBytes.
var heapBase: UInt64 = 0

/// The heap's books, reckoned by walking the block chain after
/// every change: whole-block bytes and block counts, used and
/// free. Used plus free always equals heapRegionBytes.
var heapUsedBytes: UInt64 = 0
var heapFreeBytes: UInt64 = 0
var heapUsedBlocks: UInt64 = 0
var heapFreeBlocks: UInt64 = 0

/// The self-test's verdict, spoken by `heap`: at boot, blocks are
/// taken, written with known patterns, read back byte for byte,
/// freed, and taken again — the freed chair must be the first one
/// offered — and it passes only if every pattern survives, no
/// neighbour is disturbed, and the books come home to an empty
/// heap exactly as they began.
var heapSelfTestOK = false

/// One block's whole size, from its header.
@inline(__always)
func heapBlockSize(_ block: UInt64) -> UInt64 {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(block))![0]
}

/// One block's state: true when spoken for.
@inline(__always)
func heapBlockUsed(_ block: UInt64) -> Bool {
    UnsafeMutablePointer<UInt64>(bitPattern: UInt(block))![1] != 0
}

/// Writes one block's header: its whole size and its state.
@inline(__always)
func heapSetBlock(_ block: UInt64, _ size: UInt64, _ used: Bool) {
    let header = UnsafeMutablePointer<UInt64>(bitPattern: UInt(block))!
    header[0] = size
    header[1] = used ? 1 : 0
}

/// Walks the block chain and re-reckons the books from it — the
/// chain is the truth; the counters are only its latest reading.
/// Also proves the partition as it goes: the walk must land
/// exactly on the field's end, and if it cannot, the sums are
/// still the walk's honest sums but the caller may know the walk
/// broke (the self-test asks).
@discardableResult
func heapRecount() -> Bool {
    var usedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var usedBlocks: UInt64 = 0
    var freeBlocks: UInt64 = 0
    var block = heapBase
    let end = heapBase + heapRegionBytes
    while block < end {
        let size = heapBlockSize(block)
        if size == 0 || block + size > end { break }
        if heapBlockUsed(block) {
            usedBytes += size
            usedBlocks += 1
        } else {
            freeBytes += size
            freeBlocks += 1
        }
        block += size
    }
    heapUsedBytes = usedBytes
    heapFreeBytes = freeBytes
    heapUsedBlocks = usedBlocks
    heapFreeBlocks = freeBlocks
    return block == end
}

/// Takes one block from the heap: the first free block that can
/// hold the ask — payload rounded up to a sixteen-byte step, plus
/// the header — split when what remains is still a block worth
/// keeping. Returns the payload's address, or 0 when the heap
/// cannot answer; 0 is never a true answer, since every payload
/// stands sixteen bytes into a block and the field itself is no
/// neighbour of zero.
func heapAlloc(_ requested: Int) -> UInt64 {
    if !heapReady || requested <= 0 { return 0 }
    let payload = (UInt64(requested) + 15) & ~UInt64(15)
    let needed = payload + heapHeaderBytes
    var block = heapBase
    let end = heapBase + heapRegionBytes
    while block < end {
        let size = heapBlockSize(block)
        if size == 0 { return 0 }
        if !heapBlockUsed(block) && size >= needed {
            if size - needed >= heapMinBlockBytes {
                heapSetBlock(block + needed, size - needed, false)
                heapSetBlock(block, needed, true)
            } else {
                heapSetBlock(block, size, true)
            }
            heapRecount()
            return block + heapHeaderBytes
        }
        block += size
    }
    return 0
}

/// Gives one block back: the payload's header is found sixteen
/// bytes behind it, the block is marked free, and the chain is
/// walked once to marry neighbouring free blocks back together —
/// a freed block between two free ones makes all three one field
/// again. The books are re-reckoned from the healed chain.
func heapFree(_ payloadAddress: UInt64) {
    if !heapReady || payloadAddress == 0 { return }
    let block = payloadAddress - heapHeaderBytes
    if block < heapBase || block >= heapBase + heapRegionBytes { return }
    if !heapBlockUsed(block) { return }
    heapSetBlock(block, heapBlockSize(block), false)
    var current = heapBase
    let end = heapBase + heapRegionBytes
    while current < end {
        let size = heapBlockSize(current)
        if size == 0 { break }
        if !heapBlockUsed(current) {
            let next = current + size
            if next < end && !heapBlockUsed(next) {
                heapSetBlock(current, size + heapBlockSize(next), false)
                continue   // the same block, now longer: try again
            }
        }
        current += size
    }
    heapRecount()
}

/// Raises the heap: takes its frames from the allocator — one
/// unbroken run, for a heap scattered in pieces would be no field
/// at all — lays one free block over the whole run, and runs the
/// self-test. If the run breaks or the pool runs dry, every taken
/// frame is handed back and no heap stands: `heap` will say so,
/// which is the honest answer to a machine with nothing to spare.
func initHeap() {
    if !memMapFound { return }
    let framesNeeded = heapRegionBytes / pageSize
    var first: UInt64 = 0
    var previous: UInt64 = 0
    var taken: UInt64 = 0
    var unbroken = true
    while taken < framesNeeded {
        let frame = allocFrame()
        if frame == 0 { unbroken = false; break }
        if taken == 0 {
            first = frame
        } else if frame != previous + pageSize {
            unbroken = false
            // The stray frame is handed back with the run below.
            freeFrame(frame)
            break
        }
        previous = frame
        taken += 1
    }
    if !unbroken {
        var frame = first
        var returned: UInt64 = 0
        while returned < taken {
            freeFrame(frame)
            frame += pageSize
            returned += 1
        }
        return
    }
    heapBase = first
    heapSetBlock(heapBase, heapRegionBytes, false)
    heapReady = true
    heapRecount()
    runHeapSelfTest()
}

/// The pattern the self-test writes: a byte reckoned from the
/// block's own tag and the byte's place, so every block's writing
/// is its own and a neighbour's spill cannot masquerade as it.
@inline(__always)
func heapPatternByte(_ tag: UInt8, _ index: Int) -> UInt8 {
    tag ^ UInt8(truncatingIfNeeded: index)
}

/// Fills a block's payload with its pattern, byte by byte.
func heapFill(_ payload: UInt64, _ count: Int, _ tag: UInt8) {
    let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(payload))!
    for index in 0 ..< count {
        bytes[index] = heapPatternByte(tag, index)
    }
}

/// Reads a block's pattern back and compares it, byte for byte.
func heapCheck(_ payload: UInt64, _ count: Int, _ tag: UInt8) -> Bool {
    let bytes = UnsafeMutablePointer<UInt8>(bitPattern: UInt(payload))!
    for index in 0 ..< count {
        if bytes[index] != heapPatternByte(tag, index) { return false }
    }
    return true
}

/// The heap's proof of life, run once at boot: take three blocks,
/// fill each with its own pattern, read them all back; free the
/// middle one and take a smaller fourth — it must be offered the
/// freed chair, first-fit's plain promise — fill it too, and read
/// every survivor's pattern again, so a neighbour's disturbance
/// cannot hide. Then give everything back, and pass only if the
/// books come home exactly: nothing used, and the whole field free
/// in a single block, as it began.
func runHeapSelfTest() {
    let a = heapAlloc(100)
    let b = heapAlloc(1000)
    let c = heapAlloc(64)
    if a == 0 || b == 0 || c == 0 {
        if a != 0 { heapFree(a) }
        if b != 0 { heapFree(b) }
        if c != 0 { heapFree(c) }
        heapSelfTestOK = false
        return
    }
    heapFill(a, 100, 0xA1)
    heapFill(b, 1000, 0xB2)
    heapFill(c, 64, 0xC3)
    if !heapCheck(a, 100, 0xA1) || !heapCheck(b, 1000, 0xB2)
        || !heapCheck(c, 64, 0xC3) {
        heapFree(a)
        heapFree(b)
        heapFree(c)
        heapSelfTestOK = false
        return
    }
    heapFree(b)
    let d = heapAlloc(500)
    if d != b {
        if d != 0 { heapFree(d) }
        heapFree(a)
        heapFree(c)
        heapSelfTestOK = false
        return
    }
    heapFill(d, 500, 0xD4)
    if !heapCheck(d, 500, 0xD4) || !heapCheck(a, 100, 0xA1)
        || !heapCheck(c, 64, 0xC3) {
        heapFree(a)
        heapFree(c)
        heapFree(d)
        heapSelfTestOK = false
        return
    }
    heapFree(a)
    heapFree(c)
    heapFree(d)
    heapSelfTestOK = heapRecount()
        && heapUsedBytes == 0 && heapUsedBlocks == 0
        && heapFreeBytes == heapRegionBytes && heapFreeBlocks == 1
}

// ---------------------------------------------------------------------------
// The disc (milestone 8).
//
// The OS reads its own disc. Until now the kernel was the disc's
// only cargo and never looked at the rest of it; now it carries a
// driver for the drive it booted from and a reader for the format
// the disc is written in, and the shell gains two commands, `ls`
// and `cat`, to prove both.
//
//   - The driver speaks ATAPI over AHCI. The machines this
//     kernel boots on — the test rig and Tyler's alike — hang
//     their CD-ROM off an AHCI controller: an IDE device on one
//     of the controller's buses, with no legacy IDE port
//     hardware anywhere in the machine. The controller is found
//     in PCI configuration space by its class, its registers
//     are mapped into the kernel's own tables, and its ports
//     are asked in order: a port counts only when the device
//     signed to it signs itself ATAPI (0xEB140101) and the
//     drive answers IDENTIFY PACKET DEVICE as a packet device.
//     The boot report names the port that answered and what the
//     drive calls itself. Sectors are asked for one at a time
//     with the READ (10) packet, carried over the ATA PACKET
//     command, and the controller's own engine walks each
//     sector into memory — DMA, because AHCI knows no other
//     road.
//   - The reader speaks ISO9660, read-only. The Primary Volume
//     Descriptor at sector 16 must carry its CD001 signature or
//     the disc is answered as a filesystem this kernel does not
//     know. The root directory's record is taken from the
//     descriptor, and directory entries are walked record by
//     record within each sector — a record never crosses a
//     sector's edge, which is the format's own rule. Names on
//     the disc stand in capitals wearing a ";1" version suffix;
//     the reader shows them without the suffix and matches the
//     shell's paths letter for letter without caring about
//     case, the way the shell has always folded its commands.
//
// Nothing here writes: no sector is written, no name is changed,
// nothing is cached past the sector in hand. A file the disc
// does not hold is answered as missing; a directory asked to be
// printed as a file is answered as a directory; a read the drive
// refuses is answered as a read error. The truth, in all cases,
// over a comfortable fiction.
// ---------------------------------------------------------------------------

/// A disc sector's size: CD-ROM sectors carry 2048 bytes of data.
let discSectorBytes = 2048

/// How long the driver waits on the controller, in register
/// reads, before it calls the wait failed. Deliberately
/// generous: a drive spinning up is slower than any loop this
/// kernel runs, and a wait that ends in an honest error beats
/// a hang.
let discWaitLimit = 4000000

/// Did a drive answer the raising? Until one does, every disc
/// command answers with the absence, plainly.
var discDriveFound = false

/// Did the disc in the drive carry the ISO9660 signature? A
/// drive can answer honestly while its disc is a stranger.
var discIsoFound = false

/// The disc controller's register base — its fifth base-address
/// register, read from PCI configuration space — and the port
/// the drive answered on. The controller's registers are
/// memory-mapped, standing in the PCI dark the paging section
/// leaves unmapped on purpose; the driver maps its own door at
/// the raising.
var ahciBase: UInt64 = 0
var ahciPort = 0

/// The driver's two DMA fields, taken from the frame allocator
/// at the disc's raising and kept for the kernel's life: one
/// frame holds the chosen port's command list and, at its
/// 0x400 offset, the field the drive's own answer frames land
/// in; the other holds the one command table — the command
/// frame, the packet bytes, and the data descriptor. Their
/// addresses are physical as well as virtual, the identity
/// map's gift, which is what a DMA engine must be told.
var ahciListFrame: UInt64 = 0
var ahciTableFrame: UInt64 = 0

/// The sector buffer and the path scratch: two fields taken from
/// the heap at the disc's raising and kept for the kernel's life.
/// The buffer holds the one sector in hand — no caching, so no
/// stale sector can ever be mistaken for the disc's truth. The
/// scratch holds the command's path argument, copied off the
/// screen, up to its capacity in bytes.
var discBufferAddress: UInt64 = 0
var discPathAddress: UInt64 = 0
let discPathCapacity = 160

/// The found drive's own name for itself, from its IDENTIFY
/// answer: up to forty characters, kept in a heap scratch, with
/// its reckoned length beside it. Zero length means the drive
/// gave no name worth repeating, and the report says "ATAPI
/// CD-ROM" instead.
var discModelAddress: UInt64 = 0
var discModelLength = 0

/// The root directory's place and size, from the volume
/// descriptor: every path the shell resolves starts here.
var isoRootExtent: UInt32 = 0
var isoRootSize: UInt32 = 0

/// The last read's failure, remembered so a command can answer
/// "the disc could not be read" instead of a confident falsehood:
/// set by the sector reader's retries, cleared as each command
/// begins its work.
var discReadFailed = false

/// The sector buffer, as the pointer every disc reader shares.
@inline(__always)
func discBuffer() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(discBufferAddress))!
}

/// The path scratch, as a pointer.
@inline(__always)
func discPath() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(discPathAddress))!
}

/// A little-endian word and double-word read from the buffer in
/// hand — the ISO9660 fields the reader trusts are the format's
/// little-endian halves of its both-endian pairs.
@inline(__always)
func discU16(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int) -> UInt32 {
    UInt32(buffer[offset]) | UInt32(buffer[offset + 1]) << 8
}

@inline(__always)
func discU32(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int) -> UInt32 {
    discU16(buffer, offset) | discU16(buffer, offset + 2) << 16
}

/// A breath of bus time: reads of the POST port, the ancient way
/// of letting a chip catch up, repeated as long as asked. The
/// port read has a side effect the compiler cannot argue away,
/// which is the whole of the trick.
func atapiBreath(_ reads: Int) {
    var count = 0
    while count < reads {
        _ = cardnullInb(0x80)
        count += 1
    }
}

/// One register of the controller, read or written through
/// memory. AHCI registers are memory-mapped, so no floor hand
/// is needed — but these hands are functions the compiler may
/// not inline away, so a polling loop truly looks each time it
/// asks, and a written word truly lands when it is written.
@inline(never)
func mmioRead32(_ address: UInt64) -> UInt32 {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!
        .pointee
}

@inline(never)
func mmioWrite32(_ address: UInt64, _ value: UInt32) {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!
        .pointee = value
}

/// One byte of a memory-mapped register, read or written the
/// same way — milestone 27's widening of the hands above, for
/// the sound controller's byte-sized registers (its ring
/// controls and its stream controls), which a 32-bit hand would
/// disturb by touching their neighbours.
@inline(never)
func mmioRead8(_ address: UInt64) -> UInt8 {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(address))!
        .pointee
}

@inline(never)
func mmioWrite8(_ address: UInt64, _ value: UInt8) {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(address))!
        .pointee = value
}

/// One word — sixteen bits — of a memory-mapped register, for
/// the sound controller's word-sized registers (its reset word,
/// its codec wake word, its ring pointers, its stream format).
@inline(never)
func mmioRead16(_ address: UInt64) -> UInt16 {
    UnsafeMutablePointer<UInt16>(bitPattern: UInt(address))!
        .pointee
}

@inline(never)
func mmioWrite16(_ address: UInt64, _ value: UInt16) {
    UnsafeMutablePointer<UInt16>(bitPattern: UInt(address))!
        .pointee = value
}

/// One word of PCI configuration space, through the floor's
/// double-word hands: the address port names the device, the
/// function, and the word, the data port carries it. This
/// kernel knows bus 0 only — the controller it seeks has lived
/// there on every machine it has met — but it asks every
/// function of every device: a chipset wears several devices
/// in one slot, and the disc controller is the second function
/// of its own.
func pciConfigRead32(_ device: UInt32, _ function: UInt32,
                     _ offset: UInt32) -> UInt32 {
    cardnullOutl(0xCF8, 0x80000000 | (device << 11)
                 | (function << 8) | (offset & 0xFC))
    return cardnullInl(0xCFC)
}

func pciConfigWrite32(_ device: UInt32, _ function: UInt32,
                      _ offset: UInt32, _ value: UInt32) {
    cardnullOutl(0xCF8, 0x80000000 | (device << 11)
                 | (function << 8) | (offset & 0xFC))
    cardnullOutl(0xCFC, value)
}

/// The chosen port's register addresses: the host registers
/// begin at the base; each port's field begins 0x100 in, with
/// 0x80 bytes per port.
@inline(__always)
func ahciReg(_ offset: UInt64) -> UInt64 {
    ahciBase + 0x100 + UInt64(ahciPort) * 0x80 + offset
}

/// Prepares the port's one slot for a command: the command
/// table is emptied, the command frame is laid at its head —
/// type 0x27, the mark that says "this writes the command
/// register", then the command and its feature word — one data
/// descriptor is laid at the table's 0x80 naming the sector
/// buffer and the count, and the slot's header is written in
/// the command list. Nothing is sent: a PACKET command's bytes
/// are the caller's to place first, in the packet area at 0x40.
func ahciPrepare(_ command: UInt8, _ features: UInt8,
                 _ packet: Bool, _ byteCount: Int) -> Bool {
    if ahciTableFrame == 0 { return false }
    let table = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciTableFrame))!
    var index = 0
    while index < 0x100 {
        table[index] = 0
        index += 1
    }
    table[0] = 0x27
    table[1] = 0x80
    table[2] = command
    table[3] = features
    let words = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(ahciTableFrame))!
    words[0x80 / 4] = UInt32(discBufferAddress & 0xFFFFFFFF)
    words[0x80 / 4 + 1] = UInt32(discBufferAddress >> 32)
    words[0x80 / 4 + 3] = UInt32(byteCount - 1) | 0x80000000
    let header = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(ahciListFrame))!
    var flags: UInt32 = 5 | 1 << 16
    if packet { flags |= 1 << 5 }
    header[0] = flags
    header[1] = 0
    header[2] = UInt32(ahciTableFrame & 0xFFFFFFFF)
    header[3] = UInt32(ahciTableFrame >> 32)
    return true
}

/// Fires the prepared slot and waits for the controller to hand
/// it back: completion is the slot's bit clearing, a task-file
/// error mark in the port's interrupt word refuses the wait,
/// and a transfer shorter than asked for is no success.
func ahciFire(_ byteCount: Int) -> Bool {
    mmioWrite32(ahciReg(0x10), 0xFFFFFFFF)
    mmioWrite32(ahciReg(0x38), 1)
    var waited = 0
    while mmioRead32(ahciReg(0x38)) & 1 != 0 {
        if mmioRead32(ahciReg(0x10)) & 0x40000000 != 0 {
            return false
        }
        waited += 1
        if waited >= discWaitLimit { return false }
    }
    if mmioRead32(ahciReg(0x10)) & 0x40000000 != 0 { return false }
    if mmioRead32(ahciReg(0x20)) & 0x01 != 0 { return false }
    let header = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(ahciListFrame))!
    return header[1] == UInt32(byteCount)
}

/// Raises the drive: finds the AHCI controller in PCI space,
/// takes the first port whose device signs itself ATAPI and
/// whose link stands, gives that port its fields, and wakes it.
/// On success the port is kept in ahciPort, ready for commands.
func ahciRaiseDrive() -> Bool {
    // The controller by its class: mass storage, SATA subclass,
    // the AHCI programming interface — the one door the modern
    // chipset world offers its disc drives.
    var device: UInt32 = 0
    var foundDevice: UInt32 = 0
    var foundFunction: UInt32 = 0
    var abar: UInt32 = 0
    while device < 32 && abar == 0 {
        var function: UInt32 = 0
        while function < 8 {
            let id = pciConfigRead32(device, function, 0)
            if id & 0xFFFF != 0xFFFF {
                let classes = pciConfigRead32(device, function,
                                              0x08)
                if classes >> 24 == 0x01
                    && (classes >> 16) & 0xFF == 0x06
                    && (classes >> 8) & 0xFF == 0x01 {
                    let bar = pciConfigRead32(device, function,
                                              0x24) & 0xFFFFFFF0
                    if bar != 0 {
                        abar = bar
                        foundDevice = device
                        foundFunction = function
                        break
                    }
                }
            }
            function += 1
        }
        device += 1
    }
    if abar == 0 { return false }
    // The controller must be allowed to see memory and to
    // master the bus: its engine's walking is the whole road in.
    let commandWord = pciConfigRead32(foundDevice, foundFunction,
                                      0x04)
    pciConfigWrite32(foundDevice, foundFunction, 0x04,
                     commandWord | 0x06)
    ahciBase = UInt64(abar)
    // The registers stand in the PCI dark the paging section
    // leaves unmapped on purpose; the driver maps its own door.
    if pagingReady {
        let regFlags = ptePresent | pteWritable | pteNoExecute
        if !mapPage(ahciBase, regFlags) { return false }
        if !mapPage(ahciBase + 0x1000, regFlags) { return false }
        cardnullInvlpg(ahciBase)
        cardnullInvlpg(ahciBase + 0x1000)
    }
    // AHCI mode on, then the map of which ports exist at all.
    mmioWrite32(ahciBase + 0x04,
                mmioRead32(ahciBase + 0x04) | 0x80000000)
    let present = mmioRead32(ahciBase + 0x0C)
    var port = 0
    var chosen = false
    while port < 32 && !chosen {
        if present & (UInt32(1) << UInt32(port)) != 0 {
            ahciPort = port
            // The device's signature in its port's register —
            // an ATAPI device signs 0xEB140101 — and the link's
            // word: 3 in the detect field means a device stands
            // there and the talking is done.
            if mmioRead32(ahciReg(0x24)) == 0xEB140101
                && mmioRead32(ahciReg(0x28)) & 0x0F == 3 {
                chosen = true
            }
        }
        port += 1
    }
    if !chosen { return false }
    // Still the port, then give it its fields.
    var cmd = mmioRead32(ahciReg(0x18))
    mmioWrite32(ahciReg(0x18), cmd & ~0x11)
    var waited = 0
    while mmioRead32(ahciReg(0x18)) & 0x8000 != 0 {
        waited += 1
        if waited >= discWaitLimit { return false }
    }
    ahciListFrame = allocFrame()
    ahciTableFrame = allocFrame()
    if ahciListFrame == 0 || ahciTableFrame == 0 { return false }
    let listBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciListFrame))!
    var index = 0
    while index < 4096 {
        listBytes[index] = 0
        index += 1
    }
    let tableBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciTableFrame))!
    index = 0
    while index < 4096 {
        tableBytes[index] = 0
        index += 1
    }
    mmioWrite32(ahciReg(0x00),
                UInt32(ahciListFrame & 0xFFFFFFFF))
    mmioWrite32(ahciReg(0x04), UInt32(ahciListFrame >> 32))
    let fisField = ahciListFrame + 0x400
    mmioWrite32(ahciReg(0x08), UInt32(fisField & 0xFFFFFFFF))
    mmioWrite32(ahciReg(0x0C), UInt32(fisField >> 32))
    mmioWrite32(ahciReg(0x30), 0xFFFFFFFF)
    mmioWrite32(ahciReg(0x10), 0xFFFFFFFF)
    cmd = mmioRead32(ahciReg(0x18))
    cmd |= 0x10 | 0x02 | 1 << 24
    mmioWrite32(ahciReg(0x18), cmd)
    mmioWrite32(ahciReg(0x18), cmd | 0x1)
    // The last wait: the link stands and the drive is neither
    // busy nor asking for a hand.
    waited = 0
    while true {
        if mmioRead32(ahciReg(0x28)) & 0x0F == 3
            && mmioRead32(ahciReg(0x20)) & 0x88 == 0 {
            return true
        }
        waited += 1
        if waited >= discWaitLimit { return false }
    }
}

/// Asks the raised drive its name: IDENTIFY PACKET DEVICE, the
/// one ATA command a packet device answers directly — and the
/// answer must call itself a packet device (the configuration
/// word's top two bits, 10 binary) before its name is trusted.
/// The name is words 27 to 46 of the answer, each word holding
/// two characters with the first in its high byte, so the pair
/// stands swapped in memory and is swapped back here; trailing
/// spaces are the padding, not the name's ending.
func ahciIdentify() -> Bool {
    if !ahciPrepare(0xA1, 0, false, 512) { return false }
    if !ahciFire(512) { return false }
    let buffer = discBuffer()
    if discU16(buffer, 0) >> 14 != 2 { return false }
    if discModelAddress != 0 {
        let model = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(discModelAddress))!
        var length = 0
        var index = 0
        while index < 40 {
            let byte = buffer[54 + (index & ~1) + (1 - (index & 1))]
            model[index] = byte
            if byte != 0x20 && byte != 0 { length = index + 1 }
            index += 1
        }
        discModelLength = length
    }
    return true
}

/// Reads one sector by its logical block address into the
/// buffer, through the READ (10) packet: the PACKET command is
/// prepared (feature word 1 — the packet's data may travel by
/// the controller's engine rather than by hand, the only road
/// AHCI offers), the twelve packet bytes are placed in the
/// table's packet area — the opcode, then the address in the
/// big-endian order the SCSI world speaks, then the count of
/// one — and the slot is fired. Any refusal, error, or silence
/// along the way is a plain false.
func discReadSectorOnce(_ lba: UInt32) -> Bool {
    if !ahciPrepare(0xA0, 0x01, true, discSectorBytes) {
        return false
    }
    let table = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(ahciTableFrame))!
    table[0x40] = 0x28                        // READ (10)
    table[0x41] = 0
    table[0x42] = UInt8((lba >> 24) & 0xFF)
    table[0x43] = UInt8((lba >> 16) & 0xFF)
    table[0x44] = UInt8((lba >> 8) & 0xFF)
    table[0x45] = UInt8(lba & 0xFF)
    table[0x46] = 0
    table[0x47] = 0
    table[0x48] = 1                           // one sector
    table[0x49] = 0
    table[0x4A] = 0
    table[0x4B] = 0
    return ahciFire(discSectorBytes)
}

/// Reads one sector with the patience a real drive sometimes
/// needs: three attempts, a breath between them — a drive still
/// spinning up after the bootloader's day may refuse the first
/// asking and answer the second. The final failure is
/// remembered in discReadFailed for the command to speak.
func discReadSector(_ lba: UInt32) -> Bool {
    var attempt = 0
    while attempt < 3 {
        if discReadSectorOnce(lba) { return true }
        atapiBreath(200000)
        attempt += 1
    }
    discReadFailed = true
    return false
}

/// Raises the disc: take the buffer and scratches from the heap,
/// find and wake the drive behind the AHCI controller, and ask
/// its name. Then read the volume descriptor at sector 16 and
/// ask for its signature: the type byte 1, the letters CD001,
/// and the root directory's record at offset 156, whose extent
/// and size become every path's start.
func initDisc() {
    if !heapReady { return }
    discBufferAddress = heapAlloc(discSectorBytes)
    discPathAddress = heapAlloc(discPathCapacity)
    discModelAddress = heapAlloc(40)
    if discBufferAddress == 0 { return }
    if !ahciRaiseDrive() { return }
    if !ahciIdentify() { return }
    discDriveFound = true
    if !discReadSector(16) { return }
    let buffer = discBuffer()
    if buffer[0] != 1 { return }
    if buffer[1] != 0x43 || buffer[2] != 0x44 || buffer[3] != 0x30
        || buffer[4] != 0x30 || buffer[5] != 0x31 { return }
    isoRootExtent = discU32(buffer, 156 + 2)
    isoRootSize = discU32(buffer, 156 + 10)
    if isoRootExtent == 0 { return }
    discIsoFound = true
}

/// The disc report's vocabulary: the words the boot line is
/// built from, spoken once while the banner's field is clean.
let discReportPrefix: StaticString = "Disc: "
let discGenericName: StaticString = "ATAPI CD-ROM"
let discReportPortWord: StaticString = ", AHCI port "
let discReportSuffix: StaticString = "."
let discAbsentLine: StaticString = "No CD-ROM drive answered."
let discUnknownFsLine: StaticString =
    "The disc answered, but its filesystem is not ISO9660."

/// The boot report: one line naming the drive that answered —
/// its own name for itself when it gave one, and the controller
/// port it answered on — or the absence, plainly, when none
/// did. Spoken from kmain before the first prompt, so the shell
/// opens beneath the news.
func printDiscReport() {
    if !discDriveFound {
        writeLine(discAbsentLine)
        return
    }
    writeStatic(discReportPrefix)
    if discModelLength > 0 && discModelAddress != 0 {
        let model = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(discModelAddress))!
        var index = 0
        while index < discModelLength {
            writeChar(model[index])
            index += 1
        }
    } else {
        writeStatic(discGenericName)
    }
    writeStatic(discReportPortWord)
    writeNumber(UInt64(ahciPort))
    writeLine(discReportSuffix)
    if !discIsoFound {
        writeLine(discUnknownFsLine)
    }
}

/// One directory entry's facts, as the walkers below find them:
/// kept in globals, as the heap keeps its books, because a
/// freestanding kernel returning a pocketful of fields from
/// every helper grows hard to read. entryFound says whether
/// they mean anything at all.
var entryFound = false
var entryExtent: UInt32 = 0
var entrySize: UInt32 = 0
var entryIsDirectory = false

/// Compares one directory record's name against a path component
/// held in the path scratch: the record's name with its ";1"
/// version suffix forgiven, letter for letter with case folded —
/// and the two nameless entries, whose names are the single
/// bytes 0 and 1, matched against "." and ".." as the world's
/// shells have always called them.
func isoNameMatches(_ buffer: UnsafeMutablePointer<UInt8>,
                    _ record: Int, _ componentStart: Int,
                    _ componentLength: Int) -> Bool {
    let path = discPath()
    let nameLength = Int(buffer[record + 32])
    if nameLength == 1 && buffer[record + 33] == 0 {
        return componentLength == 1 && path[componentStart] == 0x2E
    }
    if nameLength == 1 && buffer[record + 33] == 1 {
        return componentLength == 2 && path[componentStart] == 0x2E
            && path[componentStart + 1] == 0x2E
    }
    var effective = nameLength
    var index = 0
    while index < nameLength {
        if buffer[record + 33 + index] == 0x3B {   // ';'
            effective = index
            break
        }
        index += 1
    }
    if effective != componentLength { return false }
    index = 0
    while index < effective {
        var discByte = buffer[record + 33 + index]
        var pathByte = path[componentStart + index]
        if discByte >= 0x61 && discByte <= 0x7A { discByte -= 0x20 }
        if pathByte >= 0x61 && pathByte <= 0x7A { pathByte -= 0x20 }
        if discByte != pathByte { return false }
        index += 1
    }
    return true
}

/// Looks one component up in one directory: the directory's
/// sectors are read in turn, and within each, its records are
/// walked from the first byte — a record's own length says
/// where the next begins, a zero length means the rest of the
/// sector is padding, and the directory's reckoned size says
/// where the walking honestly stops.
func isoFindEntry(_ dirExtent: UInt32, _ dirSize: UInt32,
                  _ componentStart: Int,
                  _ componentLength: Int) -> Bool {
    entryFound = false
    if dirSize == 0 { return false }
    let buffer = discBuffer()
    var sectorIndex: UInt32 = 0
    let sectorCount = (dirSize + UInt32(discSectorBytes) - 1)
        / UInt32(discSectorBytes)
    while sectorIndex < sectorCount {
        if !discReadSector(dirExtent + sectorIndex) { return false }
        var inSector = discSectorBytes
        let remaining = dirSize - sectorIndex * UInt32(discSectorBytes)
        if remaining < UInt32(discSectorBytes) {
            inSector = Int(remaining)
        }
        var offset = 0
        while offset < inSector {
            let recordLength = Int(buffer[offset])
            if recordLength == 0 { break }
            if recordLength >= 34
                && isoNameMatches(buffer, offset, componentStart,
                                  componentLength) {
                entryExtent = discU32(buffer, offset + 2)
                entrySize = discU32(buffer, offset + 10)
                entryIsDirectory = buffer[offset + 25] & 0x02 != 0
                entryFound = true
                return true
            }
            offset += recordLength
        }
        sectorIndex += 1
    }
    return false
}

/// The path resolution's outcome: found, or the honest reason
/// it was not — a name the disc does not hold, a file asked to
/// be a directory along the way, or a read the drive refused.
let pathFoundCode = 0
let pathMissingCode = 1
let pathNotDirectoryCode = 2
let pathReadErrorCode = 3

/// The resolved entry's facts, when the code says found.
var resolvedExtent: UInt32 = 0
var resolvedSize: UInt32 = 0
var resolvedIsDirectory = false

/// The last component's place in the path scratch, remembered
/// for the answers that name the file they were asked about.
var lastComponentStart = 0
var lastComponentLength = 0

/// Resolves the path in the scratch, component by component
/// from the root: slashes are forgiven in any number, a leading
/// one or none at all means the same root, and an empty path is
/// the root itself. Each component must be found in the
/// directory the walk is standing in; each but the last must
/// be a directory to walk into.
func isoResolvePath(_ length: Int) -> Int {
    return isoResolvePathIn(0, length)
}

/// The same walk over one reach of the scratch — the bytes from
/// `start` up to `end` — because milestone 10's `both` keeps two
/// paths in the one scratch and must resolve the second where it
/// lies. The components' places in the scratch are the absolute
/// ones the finder already speaks, so nothing else changes: the
/// bounds are the only new word.
func isoResolvePathIn(_ start: Int, _ end: Int) -> Int {
    let path = discPath()
    resolvedExtent = isoRootExtent
    resolvedSize = isoRootSize
    resolvedIsDirectory = true
    lastComponentStart = 0
    lastComponentLength = 0
    var index = start
    while index < end && path[index] == 0x2F { index += 1 }
    if index >= end { return pathFoundCode }
    while true {
        let componentStart = index
        while index < end && path[index] != 0x2F { index += 1 }
        let componentLength = index - componentStart
        lastComponentStart = componentStart
        lastComponentLength = componentLength
        discReadFailed = false
        if !isoFindEntry(resolvedExtent, resolvedSize,
                         componentStart, componentLength) {
            return discReadFailed ? pathReadErrorCode : pathMissingCode
        }
        // More components beyond the slashes?
        var next = index
        while next < end && path[next] == 0x2F { next += 1 }
        if next < end {
            if !entryIsDirectory { return pathNotDirectoryCode }
            resolvedExtent = entryExtent
            resolvedSize = entrySize
            index = next
        } else {
            resolvedExtent = entryExtent
            resolvedSize = entrySize
            resolvedIsDirectory = entryIsDirectory
            return pathFoundCode
        }
    }
}

/// Writes the path in the scratch, as the typist wrote it — the
/// answers that name a file name it as it was asked for.
func writePathArgument(_ length: Int) {
    let path = discPath()
    var index = 0
    while index < length {
        writeChar(path[index])
        index += 1
    }
}

/// Prints one directory entry for `ls`: two spaces, the name as
/// the disc keeps it minus its version suffix, padding to a
/// modest column, and then its size — or the directory mark.
/// The two nameless entries are not printed: a listing that
/// begins with "." and ".." tells the reader nothing the prompt
/// did not already say.
func printDirectoryEntry(_ buffer: UnsafeMutablePointer<UInt8>,
                         _ record: Int) {
    let nameLength = Int(buffer[record + 32])
    if nameLength == 1 && buffer[record + 33] <= 1 { return }
    var effective = nameLength
    var index = 0
    while index < nameLength {
        if buffer[record + 33 + index] == 0x3B {
            effective = index
            break
        }
        index += 1
    }
    writeChar(0x20)
    writeChar(0x20)
    index = 0
    while index < effective {
        writeChar(buffer[record + 33 + index])
        index += 1
    }
    var padding = 14 - effective
    if padding < 1 { padding = 1 }
    while padding > 0 {
        writeChar(0x20)
        padding -= 1
    }
    if buffer[record + 25] & 0x02 != 0 {
        writeLine(lsDirMark)
    } else {
        writeNumber(UInt64(discU32(buffer, record + 10)))
        writeNewline()
    }
}

/// `ls`'s work on one directory: a header naming the disc and
/// the path, then every entry the directory holds, walked the
/// same way the finder walks — or the word that the directory
/// holds nothing but its two nameless entries.
func listDirectory(_ extent: UInt32, _ size: UInt32,
                   _ argumentLength: Int) {
    writeStatic(lsHeaderPrefix)
    if argumentLength > 0 {
        writePathArgument(argumentLength)
    } else {
        writeChar(0x2F)
    }
    writeLine(lsHeaderSuffix)
    if size == 0 {
        writeLine(lsEmptyLine)
        return
    }
    let buffer = discBuffer()
    var printed = 0
    var sectorIndex: UInt32 = 0
    let sectorCount = (size + UInt32(discSectorBytes) - 1)
        / UInt32(discSectorBytes)
    while sectorIndex < sectorCount {
        if !discReadSector(extent + sectorIndex) {
            writeLine(discReadErrorLine)
            return
        }
        var inSector = discSectorBytes
        let remaining = size - sectorIndex * UInt32(discSectorBytes)
        if remaining < UInt32(discSectorBytes) {
            inSector = Int(remaining)
        }
        var offset = 0
        while offset < inSector {
            let recordLength = Int(buffer[offset])
            if recordLength == 0 { break }
            if recordLength >= 34 {
                let nameLength = Int(buffer[offset + 32])
                if !(nameLength == 1 && buffer[offset + 33] <= 1) {
                    printed += 1
                }
                printDirectoryEntry(buffer, offset)
            }
            offset += recordLength
        }
        sectorIndex += 1
    }
    if printed == 0 {
        writeLine(lsEmptyLine)
    }
}

/// ls's and cat's shared vocabulary: the answers to a missing
/// disc, a missing name, and a refused read.
let lsHeaderPrefix: StaticString = "Disc "
let lsHeaderSuffix: StaticString = ":"
let lsDirMark: StaticString = "<DIR>"
let lsEmptyLine: StaticString = "  (nothing here)"
let discReadErrorLine: StaticString = "The disc could not be read."
let notOnDiscPrefix: StaticString = "Not on the disc: "
let notDirectorySuffix: StaticString = " is not a directory."
let isDirectorySuffix: StaticString = " is a directory, not a file."
let catUsageLine: StaticString = "cat wants a file: cat /WELCOME.TXT"

/// The shell's argument, copied off the screen into the path
/// scratch: the typed line's bytes after its first word, trimmed
/// of the spaces at both ends, up to the scratch's capacity.
/// Returns the copied length — zero when the line held nothing
/// after its word, which `ls` takes as "the root" and `cat` as
/// a question it must answer with its usage.
func copyArgumentToScratch() -> Int {
    let start = cellOffset(lineStartRow, lineStartCol)
    let end = cellOffset(cursorRow, cursorCol)
    var cell = start
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    while cell < end && screenChar(cell: cell) != 0x20 { cell += 1 }
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    var last = end
    while last > cell && screenChar(cell: last - 1) == 0x20 {
        last -= 1
    }
    if discPathAddress == 0 { return 0 }
    let path = discPath()
    var length = 0
    while cell < last && length < discPathCapacity {
        path[length] = screenChar(cell: cell)
        length += 1
        cell += 1
    }
    return length
}

/// The first word of the typed line, against a command word:
/// the match the argument-carrying commands are found by,
/// where commandMatches' whole-line strictness would refuse
/// the argument that makes them useful.
func firstWordMatches(_ command: StaticString) -> Bool {
    let start = cellOffset(lineStartRow, lineStartCol)
    let end = cellOffset(cursorRow, cursorCol)
    var cell = start
    while cell < end && screenChar(cell: cell) == 0x20 { cell += 1 }
    var index = 0
    while command.utf8Start[index] != 0 {
        if cell >= end { return false }
        var character = screenChar(cell: cell)
        if character >= 0x41 && character <= 0x5A {
            character += 0x20
        }
        if character != command.utf8Start[index] { return false }
        cell += 1
        index += 1
    }
    return cell >= end || screenChar(cell: cell) == 0x20
}

/// `ls`: the root's listing with no argument, a directory's
/// with a path, and a file's own single line when the path
/// names a file — the answer is the disc's, in every case.
func runList() {
    if !filesReady() { return }
    let length = copyArgumentToScratch()
    discReadFailed = false
    if length == 0 {
        if bundleValid {
            listBundleDirectory()
        } else {
            listDirectory(isoRootExtent, isoRootSize, 0)
        }
        return
    }
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
        if bundleValid {
            listBundleDirectory()
        } else {
            listDirectory(resolvedExtent, resolvedSize, length)
        }
        return
    }
    // A file: its own line — the name as asked, padded as the
    // listing pads, and its size.
    writeChar(0x20)
    writeChar(0x20)
    let path = discPath()
    var index = 0
    var written = 0
    while index < lastComponentLength {
        writeChar(path[lastComponentStart + index])
        index += 1
        written += 1
    }
    var padding = 14 - written
    if padding < 1 { padding = 1 }
    while padding > 0 {
        writeChar(0x20)
        padding -= 1
    }
    writeNumber(UInt64(resolvedSize))
    writeNewline()
}

/// `cat`: a file's whole contents, read off the disc sector by
/// sector and spoken through the one output door. Line feeds
/// end lines; carriage returns — the other half of some files'
/// endings — are let go; a tab steps to a plain space; any
/// other character the screen cannot honestly draw is passed
/// over, so a text file is itself and a binary file is not
/// mistaken for one.
func runCat() {
    if !filesReady() { return }
    let length = copyArgumentToScratch()
    if length == 0 {
        writeLine(catUsageLine)
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
    let buffer = discBuffer()
    var printed: UInt32 = 0
    var sectorIndex: UInt32 = 0
    let fromBundle = resolvedFromBundle
    let extent = resolvedExtent
    let offset = resolvedOffset
    let size = resolvedSize
    while printed < resolvedSize {
        if !serveReadChunk(fromBundle, extent, offset, size,
                           sectorIndex) {
            writeNewline()
            writeLine(discReadErrorLine)
            return
        }
        var count = resolvedSize - printed
        if count > UInt32(discSectorBytes) {
            count = UInt32(discSectorBytes)
        }
        var index = 0
        while index < Int(count) {
            let byte = buffer[index]
            if byte == 0x0A {
                writeNewline()
            } else if byte == 0x09 {
                writeChar(0x20)
            } else if byte >= 0x20 && byte != 0x7F {
                writeChar(byte)
            }
            index += 1
        }
        printed += count
        sectorIndex += 1
    }
    writeNewline()
}

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
/// the graphical suite — services 4 to 8, answered by
/// graphicalService in milestone 18's section below — and
/// anything else, which is answered no.
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

// ---------------------------------------------------------------------------
// The graphical face (milestone 12).
//
// The last stone of the first ladder: the OS gets a face. Since
// milestone 5 the screen has been a field of pixels with letters
// drawn on it; this milestone draws the rest — a desktop, one
// window standing on it, and a pointer that answers the mouse.
//
// The face was deliberately small in this milestone, and its
// smallness was stated plainly at the time: one window, in one
// place, that could not be dragged or resized; one button that
// counted its clicks; one close box. There is still no window
// manager here and no program but the kernel draws — graphical
// guests are a later era, and nothing in this section pretends
// otherwise — but the face has grown since: milestone 13 gave
// it a second window, the Terminal, and milestone 14 gave the
// desktop room, a bottom bar, dragging, and a Terminal that
// opens large; those stones speak in their own places below.
//
// How it is put together:
//
//   Painting. The kernel draws straight into the framebuffer the
//   boot handed over — the same ground the text console paints
//   its grid into, already reserved out of the frame pool's reach
//   at boot. No back buffer is kept: the desktop is drawn once,
//   whole, and after that only small rects are ever repainted
//   (the button's face, the click count). The face therefore
//   takes NO frames and NO heap: entering and leaving it leaves
//   `mem` and `heap` reading exactly as they read before, which
//   the milestone's proof leans on.
//
//   Colour. A colour is reckoned once into the framebuffer's own
//   packing — each 8-bit channel scaled into the field the boot
//   tag named for it — and laid down as one raw word. At 24 bits
//   the "word" is the pixel's three bytes, each channel's byte in
//   its own slot. guiRawPixel is the only place that knows this.
//
//   The pointer. A twelve-by-sixteen arrow, drawn from the art
//   below. It is the only thing that ever moves across finished
//   painting, so it alone needs an undo: before it is drawn, the
//   pixels beneath it are lifted into the floor's cushion, and
//   when it moves or goes home they are laid back — no trail,
//   because the ground is restored, not repainted from memory.
//
//   The mouse. The PS/2 mouse is woken once at boot (initMouse,
//   in this section, called from kmain while the interrupt gate
//   is still closed) and speaks by IRQ12 into the mouse ring. The face
//   drains the ring and makes packets of the bytes: three to a
//   packet — buttons and signed motion first, then the X travel,
//   then the Y. The first byte always carries bit 3; a byte
//   without it is a byte astray and is let go, which is how the
//   face resynchronises if a byte is ever lost. The mouse
//   reckons up as forward; the screen reckons down, so the Y
//   travel is turned over. Clicks are read from the packet's own
//   button bit — the real PS/2 button state, nothing simulated.
//
//   The way home. Two doors, always open: the window's close
//   box, and Esc on the keyboard. While the face holds the room
//   it drains the key ring itself and answers nothing but Esc;
//   every other key is let go. Leaving restores the console
//   exactly: the text grid was never touched — the conversation
//   stands in it still — so the whole pixel field is blackened
//   (the desktop ranged past the grid's rows) and the grid is
//   painted back through the screen, and the shell's prompt
//   opens beneath it in the same session.
// ---------------------------------------------------------------------------

/// The face's palette. Each colour is a plain 0xRRGGBB word here;
/// guiRawPixel translates it into the screen's own packing.
let guiDesktopTopColor: UInt32 = 0x3D0D1A     // deep cardinal
let guiDesktopBottomColor: UInt32 = 0x100308  // settling to near black
let guiGoldColor: UInt32 = 0xD9B36A
let guiHintColor: UInt32 = 0xCBB9A0
let guiParchmentColor: UInt32 = 0xF4EDDE
let guiCardinalColor: UInt32 = 0x7A1220
let guiCloseColor: UInt32 = 0xA01828
let guiBorderColor: UInt32 = 0x2A1A12
let guiShadowColor: UInt32 = 0x0A0206
let guiInkColor: UInt32 = 0x241A12
let guiButtonColor: UInt32 = 0xE4D9C2
let guiPressedColor: UInt32 = 0xC9B184
let guiWhiteColor: UInt32 = 0xFFFFFF
let guiPointerEdgeColor: UInt32 = 0x101010
/// The title bar of the window that does not hold the room: the
/// cardinal quieted toward grey, so the eye can tell at a glance
/// which of the two windows the keyboard is speaking to.
let guiDimBarColor: UInt32 = 0x4A2A30
/// The title bar of a window being carried (milestone 16):
/// the cardinal lit, brighter than either standing colour, so
/// the hand can feel the window is held for the whole drag.
let guiHeldBarColor: UInt32 = 0x9E2438
/// The Terminal's ground: a deep warm ink, against which the
/// shell's parchment letters stand the way they do on paper.
let guiTermBgColor: UInt32 = 0x201612
/// The bottom bar's ground (milestone 14): darker than the
/// gradient's foot and plainer, a worked surface rather than
/// sky — the desktop's furniture stands on it.
let guiBarColor: UInt32 = 0x1C0A10

/// The face's words.
let guiDesktopName: StaticString = "Cardnull OS"
let guiWindowTitle: StaticString = "Welcome"
/// The bar's word for the mouse (milestone 16): plain words,
/// the desktop's own standing — "Mouse ready" when the mouse
/// answers, "Mouse not answering" when it does not. No codes
/// stand on the desktop; the waking's transcript keeps its
/// home in the Terminal, under the `mouse` command.
let guiMouseReadyWord: StaticString = "Mouse ready"
let guiMouseSilentWord: StaticString = "Mouse not answering"

/// The mouse's standing, in the bar's plain words.
func guiMouseStandingWord() -> StaticString {
    mouseAnswering ? guiMouseReadyWord : guiMouseSilentWord
}
let guiGreetingLine: StaticString = "Welcome to Cardnull OS."
/// The house verse, wrapped for the Welcome card's narrower
/// parchment (milestone 14): the words are John 1:1's own,
/// unchanged — only the line breaks moved, four lines now
/// where the wider window carried three.
let guiVerseLine1: StaticString = "In the beginning was"
let guiVerseLine2: StaticString = "the Word, and the Word"
let guiVerseLine3: StaticString = "was with God, and the"
let guiVerseLine4: StaticString = "Word was God."
let guiTermTitle: StaticString = "Terminal"
let guiHomeLabel: StaticString = "Home"
let guiUptimeLabel: StaticString = "Uptime "
let guiVerseAttribution: StaticString = "- John 1:1 (Douay-Rheims)"
let guiButtonText: StaticString = "Click me"
let guiClicksLabel: StaticString = "Clicks: "
let guiAlreadyLine: StaticString =
    "You are already here - this window is the desktop's shell."
let guiNoScreenLine: StaticString =
    "The boot brought no graphics screen; the desktop cannot open."

/// Scales one 8-bit colour channel into the width the framebuffer
/// keeps for it: the component spread over the field's whole
/// range, so full brightness is the field filled with ones.
func guiPackChannel(_ component: UInt32, _ position: Int,
                    _ size: Int) -> UInt32 {
    if size == 0 { return 0 }
    let full = (UInt32(1) << UInt32(size)) - 1
    return ((component * full + 127) / 255) << UInt32(position)
}

/// Reckons one colour (0xRRGGBB) into the raw word the
/// framebuffer keeps for it: at 32 bits, the channels packed in
/// their named fields; at 24, each channel's full byte laid in
/// its own byte slot — which is the same reckoning, read as
/// bytes, since a 24-bit field is exactly a byte wide.
func guiRawPixel(_ rgb: UInt32) -> UInt32 {
    guiPackChannel((rgb >> 16) & 0xFF, framebufferRedPosition,
                   framebufferRedSize)
        | guiPackChannel((rgb >> 8) & 0xFF, framebufferGreenPosition,
                         framebufferGreenSize)
        | guiPackChannel(rgb & 0xFF, framebufferBluePosition,
                         framebufferBlueSize)
}

/// Lays one raw pixel word into the framebuffer. No clipping —
/// the callers keep the face on the screen, and the two readers
/// and writers of raw words are used by nothing else.
@inline(__always)
func guiWriteRaw(_ x: Int, _ y: Int, _ raw: UInt32) {
    let rowStart = framebufferAddress + UInt64(y * framebufferPitch)
    if framebufferBpp == 32 {
        let pixel = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(rowStart + UInt64(x * 4)))!
        pixel.pointee = raw
    } else {
        let pixel = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(rowStart + UInt64(x * 3)))!
        pixel[0] = UInt8(raw & 0xFF)
        pixel[1] = UInt8((raw >> 8) & 0xFF)
        pixel[2] = UInt8((raw >> 16) & 0xFF)
    }
}

/// Takes one raw pixel word back out of the framebuffer — the
/// pointer's cushion is filled through this hand.
@inline(__always)
func guiReadRaw(_ x: Int, _ y: Int) -> UInt32 {
    let rowStart = framebufferAddress + UInt64(y * framebufferPitch)
    if framebufferBpp == 32 {
        let pixel = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(rowStart + UInt64(x * 4)))!
        return pixel.pointee
    }
    let pixel = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(rowStart + UInt64(x * 3)))!
    return UInt32(pixel[0]) | UInt32(pixel[1]) << 8
        | UInt32(pixel[2]) << 16
}

/// Fills a rect with one colour, clipped to the screen. The
/// colour is reckoned into the screen's packing once, however
/// many pixels the rect holds.
func guiFillRect(_ x: Int, _ y: Int, _ width: Int, _ height: Int,
                 _ rgb: UInt32) {
    let x0 = max(x, 0)
    let y0 = max(y, 0)
    let x1 = min(x + width, framebufferWidth)
    let y1 = min(y + height, framebufferHeight)
    if x1 <= x0 || y1 <= y0 { return }
    let raw = guiRawPixel(rgb)
    for row in y0 ..< y1 {
        for col in x0 ..< x1 {
            guiWriteRaw(col, row, raw)
        }
    }
}

/// Draws one glyph of the floor's 8x8 font at a magnification,
/// in one colour, over whatever is already painted — the
/// unpainted pixels of the glyph are left exactly as they were,
/// so text can stand on any ground the face has laid.
func guiDrawGlyph(_ x: Int, _ y: Int, _ scale: Int,
                  _ character: UInt8, _ rgb: UInt32) {
    let glyph = Int(character & 0x7F)
    let font = cardnullFont8x8()
    for glyphY in 0 ..< 8 {
        let bits = font[glyph * 8 + glyphY]
        if bits == 0 { continue }
        for glyphX in 0 ..< 8 {
            if bits & (UInt8(1) << UInt8(glyphX)) != 0 {
                guiFillRect(x + glyphX * scale, y + glyphY * scale,
                            scale, scale, rgb)
            }
        }
    }
}

/// Draws a line of text, and returns the column just past its
/// last glyph — so a number can be set beside its label, the
/// way the fault report's hands do it on the grid.
@discardableResult
func guiDrawText(_ x: Int, _ y: Int, _ scale: Int,
                 _ text: StaticString, _ rgb: UInt32) -> Int {
    var penX = x
    var index = 0
    while true {
        let character = text.utf8Start[index]
        if character == 0 { break }
        guiDrawGlyph(penX, y, scale, character, rgb)
        penX += 8 * scale
        index += 1
    }
    return penX
}

/// Draws a value in decimal: the digits reckoned by a falling
/// divisor and set down one at a time, like writeDecimalAt on
/// the grid — here in pixels, for the click count.
func guiDrawDecimal(_ x: Int, _ y: Int, _ scale: Int,
                    _ value: UInt64, _ rgb: UInt32) {
    var divisor: UInt64 = 1
    while value / divisor >= 10 { divisor *= 10 }
    var remaining = value
    var penX = x
    while true {
        guiDrawGlyph(penX, y, scale, 0x30 + UInt8(remaining / divisor),
                     rgb)
        penX += 8 * scale
        remaining %= divisor
        if divisor == 1 { break }
        divisor /= 10
    }
}

// ---------------------------------------------------------------------------
// Title-bar furniture (milestone 16): one keeping for both
// windows' boxes. A box is 40 x 28, standing 8 from the
// window's right edge and 4 below its top; the Terminal's
// maximize box stands 8 left of its close box by the same
// rule. A box's hit-test is its painted rect exactly — the
// numbers below feed the painters and the tests alike — so
// the hand always finds what the eye sees.
// ---------------------------------------------------------------------------

let guiBoxW = 40
let guiBoxH = 28
let guiBoxTop = 4
let guiBoxRightPad = 8
let guiBoxGap = 8

/// A window's close box: its left edge, from the window's own
/// corner and width.
func guiCloseBoxX(_ winX: Int, _ winW: Int) -> Int {
    winX + winW - guiBoxRightPad - guiBoxW
}

/// A window's maximize box: the close box's left-hand
/// neighbour, one gap away.
func guiMaxBoxX(_ winX: Int, _ winW: Int) -> Int {
    guiCloseBoxX(winX, winW) - guiBoxGap - guiBoxW
}

/// Paints a close box at the given place: its face, and the X
/// across it — two diagonals, each drawn two pixels thick so
/// it reads at a glance. Both windows' close boxes are this
/// one painting, at their own places.
func guiPaintXBox(_ boxX: Int, _ boxY: Int) {
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiCloseColor)
    for step in 0 ..< 14 {
        guiFillRect(boxX + 13 + step, boxY + 7 + step, 2, 2,
                    guiWhiteColor)
        guiFillRect(boxX + 26 - step, boxY + 7 + step, 2, 2,
                    guiWhiteColor)
    }
}

// ---------------------------------------------------------------------------
// The window: the Welcome card. Its geometry is reckoned at
// the face's opening from the screen's own size — 448 x 320
// where the screen has room for it, less where it does not —
// and it can be carried about by its title bar since milestone
// 14. Every part's place is a fixed offset from the window's
// corner, so the painting hands and the click's hit-tests read
// the same numbers and cannot disagree.
// ---------------------------------------------------------------------------

var guiWinX = 0
var guiWinY = 0
var guiWinW = 0
var guiWinH = 0

/// The close box: the title bar's right-hand end, in the
/// shared keeping above.
func guiCloseBoxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiWinX, guiWinW)
        && x < guiCloseBoxX(guiWinX, guiWinW) + guiBoxW
        && y >= guiWinY + guiBoxTop
        && y < guiWinY + guiBoxTop + guiBoxH
}

/// The button: 220 x 48, standing 32 from the window's left edge
/// and 36 above its bottom (milestone 14: the compact card
/// keeps it nearer its foot).
func guiButtonContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWinX + 32 && x < guiWinX + 252
        && y >= guiWinY + guiWinH - 84
        && y < guiWinY + guiWinH - 36
}

/// Paints the card's close box, at its own place in the
/// shared keeping.
func guiPaintCloseBox() {
    guiPaintXBox(guiCloseBoxX(guiWinX, guiWinW),
                 guiWinY + guiBoxTop)
}

/// Paints the button, in its resting face or its pressed one —
/// the pressed face stands from the click until the button is
/// released, the face's one piece of theatre, and honest
/// theatre: it is the real button state that paints it.
func guiPaintButton() {
    let buttonX = guiWinX + 32
    let buttonY = guiWinY + guiWinH - 84
    guiFillRect(buttonX, buttonY, 220, 48,
                guiButtonHeld ? guiPressedColor : guiButtonColor)
    guiFillRect(buttonX, buttonY, 220, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY + 46, 220, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY, 2, 48, guiBorderColor)
    guiFillRect(buttonX + 218, buttonY, 2, 48, guiBorderColor)
    guiDrawText(buttonX + 46, buttonY + 16, 2, guiButtonText,
                guiInkColor)
}

/// Paints the click count beside the button: the label and the
/// number, over a fresh patch of the window's parchment — the
/// patch is repainted whole each time, so a shrinking count
/// leaves no ghost of its longer self behind.
func guiPaintClicks() {
    let clicksX = guiWinX + 272
    let clicksY = guiWinY + guiWinH - 76
    guiFillRect(clicksX, clicksY, 168, 32, guiParchmentColor)
    let endX = guiDrawText(clicksX + 8, clicksY + 8, 2,
                           guiClicksLabel, guiInkColor)
    guiDrawDecimal(endX + 4, clicksY + 8, 2, UInt64(guiClickCount),
                   guiInkColor)
}

/// Paints the card's title strip alone: the bar in the colour
/// of its standing — bright while the card holds the room,
/// dimmed while it does not, and lit while the card is being
/// carried (the held look, milestone 16) — the name, and the
/// close box. (The strip runs edge to edge, as it always has:
/// the whole painter lays the window's border first and the
/// bar's fill over its top rows.) The whole-window painter
/// lays its strip through this same hand, so a strip repainted
/// by itself, at a drag's taking hold or setting down, can
/// never disagree with a whole paint.
func guiPaintWindowTitleBar(_ held: Bool) {
    guiFillRect(guiWinX, guiWinY, guiWinW, 36,
                held ? guiHeldBarColor
                    : (guiRoomHolder() == 1 ? guiCardinalColor
                                            : guiDimBarColor))
    guiDrawText(guiWinX + 16, guiWinY + 10, 2, guiWindowTitle,
                guiWhiteColor)
    guiPaintCloseBox()
}

/// Paints the window whole: its shadow, its parchment body and
/// border, the cardinal title bar with its name and close box,
/// the greeting, the house verse in its four lines with its
/// attribution, and the button with its count beside it. In
/// milestone 14 this is a compact card — 448 x 320 at the full
/// screen — where milestones 12 and 13 carried a window as
/// large as the Terminal's own; the words it carries are the
/// same, only their wrapping changed.
func guiPaintWindow() {
    guiFillRect(guiWinX + 10, guiWinY + 12, guiWinW, guiWinH,
                guiShadowColor)
    guiFillRect(guiWinX, guiWinY, guiWinW, guiWinH,
                guiParchmentColor)
    guiFillRect(guiWinX, guiWinY, guiWinW, 2, guiBorderColor)
    guiFillRect(guiWinX, guiWinY + guiWinH - 2, guiWinW, 2,
                guiBorderColor)
    guiFillRect(guiWinX, guiWinY, 2, guiWinH, guiBorderColor)
    guiFillRect(guiWinX + guiWinW - 2, guiWinY, 2, guiWinH,
                guiBorderColor)
    guiPaintWindowTitleBar(false)
    guiDrawText(guiWinX + 32, guiWinY + 56, 2, guiGreetingLine,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 100, 2, guiVerseLine1,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 124, 2, guiVerseLine2,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 148, 2, guiVerseLine3,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 172, 2, guiVerseLine4,
                guiInkColor)
    guiDrawText(guiWinX + 32, guiWinY + 204, 2, guiVerseAttribution,
                guiInkColor)
    guiPaintButton()
    guiPaintClicks()
}

/// Paints the desktop whole: the gradient — deep cardinal at
/// the top settling toward near-black at the bottom, each row's
/// colour mixed once and laid across the row — then the OS's
/// name standing large above the windows, the windows in their
/// standing order (the one holding the room painted last, on
/// top), and the bottom bar across the foot, painted last of
/// all so nothing ever covers it. Milestone 19 made the room
/// four-way — the Welcome side, the Terminal, the Files
/// window, the Reader — and the standing order a reckoning
/// rather than a pair of branches: the windows beneath stand
/// in their fixed order (Welcome, Terminal, Files, Reader)
/// and the room's holder is painted over them, last. Which
/// window holds the room is guiRoomHolder's one reckoning,
/// read by the painters and the press alike. Milestone 25
/// stands a fifth window in the same reckoning — the
/// feather's, while its session stands — painted over the
/// elders always (a guest's face has no bar launcher to
/// raise it from burial), its focus told by its title bar.
/// A whole paint answers any dirty marks the Terminal's
/// writing hands left behind, so they are cleared as it ends.
func guiPaintDesktop() {
    let span = max(framebufferHeight - 1, 1)
    for row in 0 ..< framebufferHeight {
        let red = 0x3D + (0x10 - 0x3D) * row / span
        let green = 0x0D + (0x03 - 0x0D) * row / span
        let blue = 0x1A + (0x08 - 0x1A) * row / span
        let rgb = UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
        guiFillRect(0, row, framebufferWidth, 1, rgb)
    }
    // Eleven glyphs at fourfold size: 352 pixels of name,
    // centred over the screen.
    guiDrawText((framebufferWidth - 352) / 2, 40, 4, guiDesktopName,
                guiGoldColor)
    let holder = guiRoomHolder()
    if holder != 1 && welcomeOpen { guiPaintWindow() }
    if holder != 2 && termOpen { guiPaintTerminal() }
    if holder != 3 && filesOpen { guiPaintFilesWindow() }
    if holder != 4 && readerOpen { guiPaintReaderWindow() }
    if holder == 1 && welcomeOpen { guiPaintWindow() }
    if holder == 2 && termOpen { guiPaintTerminal() }
    if holder == 3 && filesOpen { guiPaintFilesWindow() }
    if holder == 4 && readerOpen { guiPaintReaderWindow() }
    // The feather's window stands over the elders while its
    // session stands (milestone 25): a guest's face has no
    // launcher in the bar to raise it from burial, and the
    // Terminal's ground would swallow it whole — so it is
    // never buried. Its focus is told by its title bar's
    // colour, exactly as the elders' is; among themselves
    // the elders keep their holder-last law untouched.
    if featherWinOpen { guiPaintFeatherWindow() }
    guiPaintBar()
    termDirtyTop = -1
    termDirtyBottom = -1
}

// ---------------------------------------------------------------------------
// Milestone 13: the second window — the Terminal.
//
// The Terminal hosts the kernel's own shell: the same hands and
// the same commands as the text console, with the output door
// opened onto the window's own 40 x 31 grid. It is the built-in
// shell in a window, honestly labelled — not a feather. A true
// terminal feather still waits on guest drawing and keyboard
// services, a later stone. The window stands at the desktop's
// right hand; the Welcome window keeps the left. Clicking a
// window gives it the room — the keyboard speaks to the
// Terminal only while it holds the room, and its title bar
// wears the bright cardinal while it does; the other's rests
// dimmed. The Terminal's close box closes only the window, and
// a launcher on the desktop calls it back. No dragging — the
// windows stand where they are painted; moving them is a later
// growth, named as such. (That growth arrived as milestone 14:
// the arrangement above is history — the Terminal now opens
// large over a work area above a bottom bar, the Welcome
// window is a compact card that starts closed, the launchers
// live in the bar, and the windows can be carried by their
// title bars; the Terminal and its conversation are the same.)
// ---------------------------------------------------------------------------

/// The Terminal window's place and shape, reckoned at the
/// face's opening beside the Welcome window's.
var guiTermX = 0
var guiTermY = 0
var guiTermW = 0
var guiTermH = 0

/// Whether the Terminal window stands on the desktop, and
/// whether it holds the room — the keyboard's allegiance.
var termOpen = true
var guiFocusTerminal = true

// ---------------------------------------------------------------------------
// Milestone 14: room to breathe.
//
// The desktop is rearranged around the Terminal, the window
// the work is done in. The Terminal opens large — the whole
// work area between the desktop's name and a new bottom bar —
// and its grid is reckoned from its window (see the keeping's
// note at termStrideColumns). The Welcome window is demoted,
// not deleted: a compact card, closed at the opening, called
// up by its own launcher in the bar and put away by its close
// box like any window. The bottom bar carries the mouse's
// standing line in its old words, a launcher for each window,
// the session's uptime, and a Home button — the face's one
// plainly labelled road back to the text shell, standing
// beside Esc's standing rule. Windows can be dragged by their
// title bars, by an outline that follows the pointer and is
// painted whole at rest, and the Terminal carries a
// maximize/restore control beside its close box.
// ---------------------------------------------------------------------------

/// Whether the Welcome card stands on the desktop. It starts
/// closed (milestone 14): the Terminal is the room's first
/// citizen now, and the card is called up from the bar.
var welcomeOpen = false

/// The work area's top edge: below the desktop's name, the
/// first row a window may stand on, and the floor of the
/// dragging clamp. The bottom bar's top is the area's floor.
let guiWorkTop = 88

/// The Terminal's maximize bookkeeping: whether it stands
/// maximized, and the place and shape restore returns it to.
var termMaximized = false
var termSavedX = 0
var termSavedY = 0
var termSavedW = 0
var termSavedH = 0

/// The drag's bookkeeping: which window is being carried
/// (0 none, 1 the Welcome card, 2 the Terminal, 3 the Files
/// window and 4 the Reader since milestone 19), where in its
/// title bar the pointer took hold, and the outline's present
/// rect — the window's own rect until the pointer moves it.
var dragWindow = 0
var dragOffsetX = 0
var dragOffsetY = 0
var dragRectX = 0
var dragRectY = 0
var dragRectW = 0
var dragRectH = 0
var dragOutlineDrawn = false

/// The double-click's bookkeeping (milestone 16): when the
/// last plain press in the Terminal's title bar landed, and
/// whether it still stands as the first half of a pair. Two
/// presses within half a second — fifty of the heartbeat's
/// ticks — trade the window between its own place and the
/// whole work area, the convention every hand already knows;
/// the maximize box keeps its own road beside it. A press
/// anywhere else puts the pairing down.
var termTitlePressTick: UInt64 = 0
var termTitlePressArmed = false
let guiDoubleClickTicks: UInt64 = 50

/// The bar clock's bookkeeping: the second it last painted,
/// and whether the bar's layout found it ground to stand on
/// (decided by guiLayoutBar at the face's opening, milestone
/// 16).
var guiClockSecond: UInt64 = 0
var guiClockVisible = false

/// The Terminal's text field: its grid drawn at twofold size
/// from this origin, its visible shape reckoned from the
/// window's size (76 columns by 37 rows in the window as it
/// opens at 1280 x 800; 40 by 31 in milestone 13's smaller
/// window), the title bar and a margin kept around it.
func guiTermCellX(_ col: Int) -> Int { guiTermX + 16 + col * 16 }
func guiTermCellY(_ row: Int) -> Int { guiTermY + 52 + row * 16 }

func guiTermContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiTermX && x < guiTermX + guiTermW
        && y >= guiTermY && y < guiTermY + guiTermH
}

/// The Terminal's close box: the shared keeping, at this
/// window's right-hand end.
func guiTermCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiTermX, guiTermW)
        && x < guiCloseBoxX(guiTermX, guiTermW) + guiBoxW
        && y >= guiTermY + guiBoxTop
        && y < guiTermY + guiBoxTop + guiBoxH
}

func guiWinContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWinX && x < guiWinX + guiWinW
        && y >= guiWinY && y < guiWinY + guiWinH
}

/// A window's title bar: the strip across its head, where a
/// press takes hold for the drag (milestone 14) — the boxes
/// standing in it are asked first, in the press's own order.
func guiTermTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiTermX && x < guiTermX + guiTermW
        && y >= guiTermY && y < guiTermY + 36
}

func guiWinTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiWinX && x < guiWinX + guiWinW
        && y >= guiWinY && y < guiWinY + 36
}

/// The Terminal's maximize box: left of its close box, in the
/// shared keeping (milestone 14's box, widened to the keeping's
/// 40 in milestone 16, its glyphs centred in the wider box).
func guiTermMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiTermX, guiTermW)
        && x < guiMaxBoxX(guiTermX, guiTermW) + guiBoxW
        && y >= guiTermY + guiBoxTop
        && y < guiTermY + guiBoxTop + guiBoxH
}

/// Paints the Terminal's maximize box: a small square while
/// the window stands at its own size; two squares, one behind
/// the other, while it stands maximized — the face's way of
/// saying the box now restores.
func guiPaintTermMaxBox() {
    let boxX = guiMaxBoxX(guiTermX, guiTermW)
    let boxY = guiTermY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if termMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints one cell of the Terminal's grid: its ground laid
/// fresh, its letter drawn over, and — when the cell is the
/// shell's own place and the window holds the room — the
/// underline that marks where the next letter lands. The row
/// is a displayed row: under milestone 26's lift it may read
/// a kept line instead of the grid's, and the shell's place
/// rides the same lift downward — off the window entirely
/// once the lift passes it, as an honest scroll leaves it.
func guiPaintTermCell(_ row: Int, _ col: Int) {
    let x = guiTermCellX(col)
    let y = guiTermCellY(row)
    guiFillRect(x, y, 16, 16, guiTermBgColor)
    let character = termDisplayChar(row, col)
    if character != 0x20 {
        guiDrawGlyph(x, y, 2, character, guiParchmentColor)
    }
    let lift = min(termViewOffset, termHistoryCount)
    if guiFocusTerminal && row == cursorRow + lift
        && col == cursorCol {
        guiFillRect(x, y + 13, 16, 3, guiParchmentColor)
    }
}

/// Paints a span of the Terminal's rows, whole — the face's
/// answer to the writing hands' dirty marks.
func guiPaintTermRows(_ top: Int, _ bottom: Int) {
    for row in top ... bottom {
        for col in 0 ..< termColumns {
            guiPaintTermCell(row, col)
        }
    }
}

/// Paints the Terminal's close box, at its own place in the
/// shared keeping.
func guiPaintTermCloseBox() {
    guiPaintXBox(guiCloseBoxX(guiTermX, guiTermW),
                 guiTermY + guiBoxTop)
}

/// Paints the Terminal's title strip alone, in the colour of
/// its standing — bright while it holds the room, dimmed while
/// it does not, lit while it is carried (milestone 16) — with
/// its name and both its boxes. The whole-window painter lays
/// its strip through this same hand, as the Welcome card's
/// painter does.
func guiPaintTermTitleBar(_ held: Bool) {
    guiFillRect(guiTermX, guiTermY, guiTermW, 36,
                held ? guiHeldBarColor
                    : (guiFocusTerminal ? guiCardinalColor
                                        : guiDimBarColor))
    guiDrawText(guiTermX + 16, guiTermY + 10, 2, guiTermTitle,
                guiWhiteColor)
    guiPaintTermMaxBox()
    guiPaintTermCloseBox()
}

/// Paints the Terminal window whole: shadow, ink ground and
/// border, its title bar in the colour of its standing, and
/// every cell of its grid.
func guiPaintTerminal() {
    guiFillRect(guiTermX + 10, guiTermY + 12, guiTermW, guiTermH,
                guiShadowColor)
    guiFillRect(guiTermX, guiTermY, guiTermW, guiTermH,
                guiTermBgColor)
    guiFillRect(guiTermX, guiTermY, guiTermW, 2, guiBorderColor)
    guiFillRect(guiTermX, guiTermY + guiTermH - 2, guiTermW, 2,
                guiBorderColor)
    guiFillRect(guiTermX, guiTermY, 2, guiTermH, guiBorderColor)
    guiFillRect(guiTermX + guiTermW - 2, guiTermY, 2, guiTermH,
                guiBorderColor)
    guiPaintTermTitleBar(false)
    guiPaintTermRows(0, termRows - 1)
}

// ---------------------------------------------------------------------------
// Milestone 14: the bottom bar, the clock, and the windows'
// carrying.
//
// The bar stands across the screen's foot, 36 pixels tall,
// painted by the desktop last of all so no window ever covers
// it: the mouse's standing line at its left, in the words the
// desktop has always carried; a launcher for each window —
// pressing one opens its window or gives it the room, and a
// cardinal stripe under a launcher says its window stands;
// the session's uptime, counted off the timer's own ticks and
// labelled as what it is; and at the right end the Home
// button, the face's labelled road back to the text shell.
//
// Milestone 16 gave the bar a layout of its own, after Tyler's
// witness of milestone 14: on his screen the launchers stood
// at fixed offsets reckoned for one width, and at his width
// the Welcome launcher was squeezed to a sliver beside Home
// and the clock crowded off entirely. The layout is now
// reckoned at the face's opening from the screen's own width
// and the words themselves: every button is exactly as wide
// as its label needs, the same padding at both ends of the
// bar and between its pieces, and nothing is ever squeezed —
// what cannot stand at a width is not painted there (the
// clock yields first, then the gaps narrow), and the words
// themselves are shortened only in plain language. And the
// mouse's standing on the bar is plain words now — "Mouse
// ready", "Mouse not answering" — the codes having moved to
// their proper home, the Terminal's `mouse` command.
// ---------------------------------------------------------------------------

/// The bar's height: 36 pixels, as it has stood since
/// milestone 14.
let guiBarHeight = 36

/// The air at each side of a bar button's label: a button is
/// its word's width and twice this, no more and no less.
let guiBarBtnPad = 16

/// The widest ground the clock ever needs cleared: its label,
/// three digits of hours, two colons, and the minutes and
/// seconds two digits each, all at twofold size.
let guiClockPatchW = 256

func guiBarTop() -> Int { framebufferHeight - guiBarHeight }

/// A glyph count in a StaticString's keeping — the bar centres
/// its labels by it and reckons its buttons' widths from it.
func guiTextGlyphs(_ text: StaticString) -> Int {
    var count = 0
    while text.utf8Start[count] != 0 { count += 1 }
    return count
}

/// A bar button's width, reckoned from its label: the word at
/// twofold size and the pad at both ends. Terminal earns 160,
/// Welcome 144, Files 112 (milestone 19), Home 96 — each
/// exactly its own size.
func guiBarButtonWidth(_ label: StaticString) -> Int {
    guiTextGlyphs(label) * 16 + 2 * guiBarBtnPad
}

/// The bar's layout, reckoned once at the face's opening by
/// guiLayoutBar: where each piece stands. The painters and
/// the hit-tests read these numbers and no others.
var barStatusX = 0
var barStatusW = 0
var barTermBtnX = 0
var barFilesBtnX = 0
var barWelcomeBtnX = 0
var barHomeBtnX = 0
var barClockEndX = 0

/// The Files launcher's word (milestone 19): the bar names
/// the window it calls, as it names the other two.
let guiFilesTitle: StaticString = "Files"

/// Reckons the bar's layout from the screen's own width and
/// the mouse's standing (which sets the status word's length).
/// The standing order: a 16 margin; the status in its plain
/// words; a gap; the Terminal launcher; a gap; the Files
/// launcher (milestone 19 — three launchers now, reckoned by
/// the same budget as the two were); a gap; the Welcome
/// launcher; then open ground; the clock, ending one gap
/// before Home; and Home, closing one margin from the right
/// edge. If the row cannot stand at this width, the gaps —
/// never the furniture — give: first the status gap narrows
/// to 12, then the launchers' gap to 8. The clock is painted
/// only when its whole patch stands clear of the Welcome
/// launcher with a gap to spare; otherwise it is simply not
/// there, as it was crowded off before — only now by decision,
/// stated, and not by collision.
func guiLayoutBar() {
    var statusGap = 24
    var btnGap = 16
    barStatusX = 16
    barStatusW = guiTextGlyphs(guiMouseStandingWord()) * 16
    barHomeBtnX = framebufferWidth - 16
        - guiBarButtonWidth(guiHomeLabel)
    barTermBtnX = barStatusX + barStatusW + statusGap
    barFilesBtnX = barTermBtnX
        + guiBarButtonWidth(guiTermTitle) + btnGap
    barWelcomeBtnX = barFilesBtnX
        + guiBarButtonWidth(guiFilesTitle) + btnGap
    if barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
        > barHomeBtnX - 8 {
        statusGap = 12
        barTermBtnX = barStatusX + barStatusW + statusGap
        barFilesBtnX = barTermBtnX
            + guiBarButtonWidth(guiTermTitle) + btnGap
        barWelcomeBtnX = barFilesBtnX
            + guiBarButtonWidth(guiFilesTitle) + btnGap
    }
    if barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
        > barHomeBtnX - 8 {
        btnGap = 8
        barFilesBtnX = barTermBtnX
            + guiBarButtonWidth(guiTermTitle) + btnGap
        barWelcomeBtnX = barFilesBtnX
            + guiBarButtonWidth(guiFilesTitle) + btnGap
    }
    barClockEndX = barHomeBtnX - 16
    guiClockVisible = barClockEndX - guiClockPatchW
        >= barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle) + 24
}

func guiBarFilesContains(_ x: Int, _ y: Int) -> Bool {
    x >= barFilesBtnX
        && x < barFilesBtnX + guiBarButtonWidth(guiFilesTitle)
        && y >= guiBarTop() + 4 && y < guiBarTop() + 32
}

func guiBarTermContains(_ x: Int, _ y: Int) -> Bool {
    x >= barTermBtnX
        && x < barTermBtnX + guiBarButtonWidth(guiTermTitle)
        && y >= guiBarTop() + 4 && y < guiBarTop() + 32
}

func guiBarWelcomeContains(_ x: Int, _ y: Int) -> Bool {
    x >= barWelcomeBtnX
        && x < barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
        && y >= guiBarTop() + 4 && y < guiBarTop() + 32
}

func guiBarHomeContains(_ x: Int, _ y: Int) -> Bool {
    x >= barHomeBtnX
        && x < barHomeBtnX + guiBarButtonWidth(guiHomeLabel)
        && y >= guiBarTop() + 4 && y < guiBarTop() + 32
}

/// Paints one of the bar's buttons: its ground and border, its
/// label centred, and — while its window stands — a cardinal
/// stripe along its foot, so the bar says which windows are up
/// without being asked.
func guiPaintBarButton(_ bx: Int, _ w: Int, _ label: StaticString,
                       _ standing: Bool) {
    let by = guiBarTop() + 4
    guiFillRect(bx, by, w, 28, guiButtonColor)
    guiFillRect(bx, by, w, 2, guiBorderColor)
    guiFillRect(bx, by + 26, w, 2, guiBorderColor)
    guiFillRect(bx, by, 2, 28, guiBorderColor)
    guiFillRect(bx + w - 2, by, 2, 28, guiBorderColor)
    if standing {
        guiFillRect(bx + 2, by + 23, w - 4, 3, guiCardinalColor)
    }
    let labelW = guiTextGlyphs(label) * 16
    guiDrawText(bx + (w - labelW) / 2, by + 6, 2, label,
                guiInkColor)
}

/// Two digits, leading zero and all, at twofold size.
func guiDrawTwoDigits(_ x: Int, _ y: Int, _ value: UInt64,
                      _ rgb: UInt32) {
    guiDrawGlyph(x, y, 2, 0x30 + UInt8((value / 10) % 10), rgb)
    guiDrawGlyph(x + 16, y, 2, 0x30 + UInt8(value % 10), rgb)
}

/// A number in decimal at twofold size, returning the pen's
/// end — the clock lays its colons by it.
func guiDrawNumber(_ x: Int, _ y: Int, _ value: UInt64,
                   _ rgb: UInt32) -> Int {
    var divisor: UInt64 = 1
    while value / divisor >= 10 { divisor *= 10 }
    var penX = x
    var rest = value
    while true {
        guiDrawGlyph(penX, y, 2, 0x30 + UInt8(rest / divisor), rgb)
        penX += 16
        rest %= divisor
        if divisor == 1 { break }
        divisor /= 10
    }
    return penX
}

/// Paints the bar's clock: "Uptime " and the session's age in
/// hours, minutes and seconds, counted off the timer's ticks —
/// the same count the `uptime` command reads, and labelled as
/// uptime because that is what it is; the face claims no
/// wall-clock it does not keep. The line is right-anchored:
/// it ends where the layout says the clock's ground ends, and
/// its start is reckoned from its own width, so it stands in
/// its place at any width. The patch is first laid fresh in
/// the bar's ground, so a growing hour leaves no tail of its
/// shorter self behind. On a screen too narrow to hold it
/// beside the launchers the layout withholds it, and it is
/// simply not painted.
func guiPaintClock() {
    guiClockSecond = ticks / 100
    if !guiClockVisible { return }
    let totalSeconds = ticks / 100
    let hours = totalSeconds / 3600
    var hourDigits = 1
    var reckon = hours
    while reckon >= 10 { hourDigits += 1; reckon /= 10 }
    let startX = barClockEndX
        - (112 + hourDigits * 16 + 16 + 32 + 16 + 32)
    let y = guiBarTop() + 10
    guiFillRect(barClockEndX - guiClockPatchW, guiBarTop() + 4,
                guiClockPatchW, 28, guiBarColor)
    guiDrawText(startX, y, 2, guiUptimeLabel, guiHintColor)
    var penX = guiDrawNumber(startX + 112, y, hours,
                             guiHintColor)
    guiDrawGlyph(penX, y, 2, 0x3A, guiHintColor)
    penX += 16
    guiDrawTwoDigits(penX, y, (totalSeconds / 60) % 60,
                     guiHintColor)
    penX += 32
    guiDrawGlyph(penX, y, 2, 0x3A, guiHintColor)
    penX += 16
    guiDrawTwoDigits(penX, y, totalSeconds % 60, guiHintColor)
}

/// Paints the bottom bar whole: its ground, the gold rule
/// along its head, the mouse's standing in plain words, the
/// three launchers at their reckoned places (Terminal,
/// Files, Welcome — milestone 19), the clock, and the Home
/// button.
func guiPaintBar() {
    let top = guiBarTop()
    guiFillRect(0, top, framebufferWidth, guiBarHeight, guiBarColor)
    guiFillRect(0, top, framebufferWidth, 2, guiGoldColor)
    guiDrawText(barStatusX, top + 10, 2, guiMouseStandingWord(),
                guiHintColor)
    guiPaintBarButton(barTermBtnX,
                      guiBarButtonWidth(guiTermTitle),
                      guiTermTitle, termOpen)
    guiPaintBarButton(barFilesBtnX,
                      guiBarButtonWidth(guiFilesTitle),
                      guiFilesTitle, filesOpen)
    guiPaintBarButton(barWelcomeBtnX,
                      guiBarButtonWidth(guiWindowTitle),
                      guiWindowTitle, welcomeOpen)
    guiPaintClock()
    guiPaintBarButton(barHomeBtnX,
                      guiBarButtonWidth(guiHomeLabel),
                      guiHomeLabel, false)
}

/// The Terminal's maximize and restore, one control: maximize
/// keeps the window's place and shape aside and gives it the
/// whole work area — the full width under the desktop's name,
/// down to the bar; restore gives its own place back. The grid
/// is re-reckoned at each change, and the conversation stands
/// through both, its marks clamped home if the shape shrank.
func guiToggleTermMaximize() {
    if termMaximized {
        guiTermX = termSavedX
        guiTermY = termSavedY
        guiTermW = termSavedW
        guiTermH = termSavedH
        termMaximized = false
    } else {
        termSavedX = guiTermX
        termSavedY = guiTermY
        termSavedW = guiTermW
        termSavedH = guiTermH
        guiTermX = 0
        guiTermY = guiWorkTop
        guiTermW = framebufferWidth
        guiTermH = guiBarTop() - guiWorkTop
        termMaximized = true
    }
    termResizeToWindow()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

// ---------------------------------------------------------------------------
// The drag. A window is carried by an outline, not by its
// whole painted self: the press in its title bar draws a
// two-pixel frame around where the window stands — each pixel
// the opposite of the ground it covers, so the same drawing
// again erases it exactly, and nothing need be kept or
// restored. As the pointer travels, the frame is rubbed out
// and redrawn at the clamped place the window would land; on
// release the window takes that place and the desktop is
// painted whole, the window standing clean at rest. The
// outline work always happens while the pointer is hidden, so
// the pointer's cushion — which holds the ground as it truly
// is, outline and all — is never caught lying.
// ---------------------------------------------------------------------------

/// Turns one pixel into its opposite — the outline's only ink.
func guiInvertPixel(_ x: Int, _ y: Int) {
    if x < 0 || y < 0 || x >= framebufferWidth
        || y >= framebufferHeight { return }
    guiWriteRaw(x, y, guiReadRaw(x, y) ^ 0xFFFFFF)
}

/// Draws (or, called again on the same rect, erases) the
/// drag's outline: a two-pixel frame around the given rect.
func guiInvertOutline(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
    for col in x ..< (x + w) {
        guiInvertPixel(col, y)
        guiInvertPixel(col, y + 1)
        guiInvertPixel(col, y + h - 2)
        guiInvertPixel(col, y + h - 1)
    }
    if h > 4 {
        for row in (y + 2) ..< (y + h - 2) {
            guiInvertPixel(x, row)
            guiInvertPixel(x + 1, row)
            guiInvertPixel(x + w - 2, row)
            guiInvertPixel(x + w - 1, row)
        }
    }
}

/// The clamps of a carried window — the rule, stated once
/// and kept by both clamps: a window can never be carried
/// where it cannot be retrieved. Sideways, it may slide until
/// only 120 pixels of it remain on the screen — 120 pixels of
/// its title bar, at the left edge the bar's own beginning and
/// title, at the right edge the bar's end and its close box —
/// always a reachable strip to take hold of again. Up and
/// down, the title bar stays wholly inside the work area: its
/// top never above the area's top, and its foot never sinking
/// to the bottom bar's head (the clamp leaves it 4 pixels of
/// air).
func dragClampX(_ x: Int, _ w: Int) -> Int {
    min(max(x, -(w - 120)), framebufferWidth - 120)
}

func dragClampY(_ y: Int) -> Int {
    min(max(y, guiWorkTop), guiBarTop() - 40)
}

/// Takes hold of a window for the drag: the pointer's grip
/// within its title bar is remembered, the bar is painted in
/// its held look (milestone 16 — lit, for the whole carry, so
/// the hand feels the window is held), and the outline is
/// drawn around the window where it stands — pointer hidden
/// while all of it is drawn, so the cushion keeps the truth.
/// Milestone 19: the keeping names four windows now — 1 the
/// Welcome card, 2 the Terminal, 3 the Files window, 4 the
/// Reader — and the drag serves each by the same rule.
/// Milestone 25 names a fifth, the feather's window, served
/// by the same rule while its session stands.
func guiBeginDrag(_ window: Int, _ px: Int, _ py: Int) {
    dragWindow = window
    if window == 1 {
        dragOffsetX = px - guiWinX
        dragOffsetY = py - guiWinY
        dragRectX = guiWinX
        dragRectY = guiWinY
        dragRectW = guiWinW
        dragRectH = guiWinH
    } else if window == 3 {
        dragOffsetX = px - guiFilesX
        dragOffsetY = py - guiFilesY
        dragRectX = guiFilesX
        dragRectY = guiFilesY
        dragRectW = guiFilesW
        dragRectH = guiFilesH
    } else if window == 4 {
        dragOffsetX = px - guiReaderX
        dragOffsetY = py - guiReaderY
        dragRectX = guiReaderX
        dragRectY = guiReaderY
        dragRectW = guiReaderW
        dragRectH = guiReaderH
    } else if window == 5 {
        dragOffsetX = px - guiFeatherX
        dragOffsetY = py - guiFeatherY
        dragRectX = guiFeatherX
        dragRectY = guiFeatherY
        dragRectW = guiFeatherW
        dragRectH = guiFeatherH
    } else {
        dragOffsetX = px - guiTermX
        dragOffsetY = py - guiTermY
        dragRectX = guiTermX
        dragRectY = guiTermY
        dragRectW = guiTermW
        dragRectH = guiTermH
    }
    pointerHide()
    if window == 1 {
        guiPaintWindowTitleBar(true)
    } else if window == 3 {
        guiPaintFilesTitleBar(true)
    } else if window == 4 {
        guiPaintReaderTitleBar(true)
    } else if window == 5 {
        guiPaintFeatherTitleBar(true)
    } else {
        guiPaintTermTitleBar(true)
    }
    guiInvertOutline(dragRectX, dragRectY, dragRectW, dragRectH)
    dragOutlineDrawn = true
    pointerShow()
}

/// The outline's travel, called from the pointer's own moving
/// with the pointer already hidden: the old frame is rubbed
/// out, the landing place is reckoned from the pointer's new
/// standing and clamped, and the frame is drawn there. The
/// window itself has not moved — only its promise has.
func guiDragMotion() {
    if dragWindow == 0 || !dragOutlineDrawn { return }
    guiInvertOutline(dragRectX, dragRectY, dragRectW, dragRectH)
    dragRectX = dragClampX(pointerX - dragOffsetX, dragRectW)
    dragRectY = dragClampY(pointerY - dragOffsetY)
    guiInvertOutline(dragRectX, dragRectY, dragRectW, dragRectH)
}

/// Sets the carried window down: the outline is rubbed out,
/// the window takes the landing place if it differs from its
/// own, and the desktop is painted whole — the window standing
/// clean at rest, with no trail of its carrying behind it. A
/// carry that went nowhere still owes the title bar its
/// resting face back: the carried window stands on top (the
/// press that took hold gave it the room first), so its strip
/// is repainted alone, exactly as a whole paint would lay it.
func guiEndDrag() {
    if dragWindow == 0 { return }
    pointerHide()
    if dragOutlineDrawn {
        guiInvertOutline(dragRectX, dragRectY, dragRectW,
                         dragRectH)
        dragOutlineDrawn = false
    }
    let carried = dragWindow
    var moved = false
    if carried == 1 {
        moved = dragRectX != guiWinX || dragRectY != guiWinY
        guiWinX = dragRectX
        guiWinY = dragRectY
    } else if carried == 3 {
        moved = dragRectX != guiFilesX || dragRectY != guiFilesY
        guiFilesX = dragRectX
        guiFilesY = dragRectY
    } else if carried == 4 {
        moved = dragRectX != guiReaderX || dragRectY != guiReaderY
        guiReaderX = dragRectX
        guiReaderY = dragRectY
    } else if carried == 5 {
        moved = dragRectX != guiFeatherX || dragRectY != guiFeatherY
        guiFeatherX = dragRectX
        guiFeatherY = dragRectY
    } else {
        moved = dragRectX != guiTermX || dragRectY != guiTermY
        guiTermX = dragRectX
        guiTermY = dragRectY
    }
    dragWindow = 0
    if moved {
        guiPaintDesktop()
    } else if carried == 1 {
        guiPaintWindowTitleBar(false)
    } else if carried == 3 {
        guiPaintFilesTitleBar(false)
    } else if carried == 4 {
        guiPaintReaderTitleBar(false)
    } else if carried == 5 {
        guiPaintFeatherTitleBar(false)
    } else {
        guiPaintTermTitleBar(false)
    }
    pointerShow()
}

/// Gives the room to one window or the other: the whole
/// desktop is repainted in its new standing — the windows
/// change places in the painting order as well as in their
/// title bars, the one holding the room painted last, on top —
/// and the Terminal's cursor takes or loses its underline with
/// the allegiance. Milestone 19: giving the room down this
/// road also takes it from the Files window or the Reader,
/// whichever held it — the new windows have their own giving
/// hands (guiSetFocusFiles, guiSetFocusReader), and every
/// road leaves exactly one holder standing.
func guiSetFocus(_ toTerminal: Bool) {
    let filesHeld = guiFocusFiles || guiFocusReader
    if guiFocusTerminal == toTerminal && !filesHeld { return }
    guiFocusTerminal = toTerminal
    guiFocusFiles = false
    guiFocusReader = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// The Terminal grid's visible shape for the window as it
/// stands: sixteen pixels to a column and to a row, the title
/// bar and margins kept out of the reckoning, and the keeping's
/// capacity the outer bound. It is a function of the window
/// alone — the same window always earns the same shape.
func termColumnsForWindow() -> Int {
    min(max((guiTermW - 32) / 16, 8), termStrideColumns)
}

func termRowsForWindow() -> Int {
    min(max((guiTermH - 62) / 16, 4), termRowsCapacity)
}

/// Brings the grid's visible shape to the window's present
/// shape, when the two have drifted apart — the window opened,
/// maximized, or restored. The storage does not move; the
/// cells outside the new shape are scrubbed to spaces, so
/// nothing the new shape cannot see can leak into a line read
/// back across a row's end; the conversation's marks are
/// clamped home inside the new bounds; and the window's whole
/// face is marked for repaint.
func termResizeToWindow() {
    let newColumns = termColumnsForWindow()
    let newRows = termRowsForWindow()
    if newColumns == termColumns && newRows == termRows { return }
    let grid = cardnullTermGrid()
    for row in 0 ..< termRowsCapacity {
        let base = row * termStrideColumns
        for col in 0 ..< termStrideColumns {
            if row >= newRows || col >= newColumns {
                grid[base + col] = 0x20
            }
        }
    }
    termColumns = newColumns
    termRows = newRows
    if cursorRow > termRows - 1 { cursorRow = termRows - 1 }
    if cursorCol > termColumns - 1 { cursorCol = termColumns - 1 }
    if lineStartRow > termRows - 1 { lineStartRow = termRows - 1 }
    if lineStartCol > termColumns - 1 {
        lineStartCol = termColumns - 1
    }
    termMarkAllDirty()
}

/// Takes the shell's conversation into the Terminal home: the
/// console's four marks are kept aside, the Terminal's own are
/// taken up, and the output door opens onto the window's grid.
/// The first opening wipes the grid's whole keeping and lays
/// its first prompt; later openings resume the conversation
/// where it stood — resized to the window's present shape
/// first, if the window's shape has changed since.
func consoleEnterTerminal() {
    textSavedCursorRow = cursorRow
    textSavedCursorCol = cursorCol
    textSavedLineStartRow = lineStartRow
    textSavedLineStartCol = lineStartCol
    consoleInTerminal = true
    if !termStarted {
        let grid = cardnullTermGrid()
        for cell in 0 ..< (termStrideColumns * termRowsCapacity) {
            grid[cell] = 0x20
        }
        termHistoryCount = 0
        termViewOffset = 0
        termColumns = termColumnsForWindow()
        termRows = termRowsForWindow()
        cursorRow = 0
        cursorCol = 0
        startLine()
        termStarted = true
        termMarkAllDirty()
    } else {
        cursorRow = termSavedCursorRow
        cursorCol = termSavedCursorCol
        lineStartRow = termSavedLineStartRow
        lineStartCol = termSavedLineStartCol
        termResizeToWindow()
    }
}

/// Brings the shell's conversation home to the console: the
/// Terminal's marks are kept aside for its next opening, the
/// console's own are taken up again, and the output door opens
/// back onto the text grid — whose every letter still stands
/// exactly as the face found it.
func consoleLeaveTerminal() {
    termSavedCursorRow = cursorRow
    termSavedCursorCol = cursorCol
    termSavedLineStartRow = lineStartRow
    termSavedLineStartCol = lineStartCol
    consoleInTerminal = false
    cursorRow = textSavedCursorRow
    cursorCol = textSavedCursorCol
    lineStartRow = textSavedLineStartRow
    lineStartCol = textSavedLineStartCol
}

// ---------------------------------------------------------------------------
// The pointer: a twelve-by-sixteen arrow. In the art below, '#'
// is its dark edge, 'W' its white body, and '.' is no pixel at
// all — the ground shows through. Its point — the top-left
// corner, the pixel the clicks are reckoned by — is the place
// the mouse's travels are added to.
//
//     #...........
//     ##..........
//     #W#.........
//     #WW#........
//     #WWW#.......
//     #WWWW#......
//     #WWWWW#.....
//     #WWWWWW#....
//     #WWWWW#.....
//     #WW##W#.....
//     #W#.#W#.....
//     #..#WW#.....
//     ....#WW#....
//     ....#WW#....
//     .....#W#....
//     ......#.....
// ---------------------------------------------------------------------------

let pointerArtWidth = 12
let pointerArtHeight = 16
let pointerArt: StaticString =
    "#...........##..........#W#.........#WW#........#WWW#.......#WWWW#......#WWWWW#.....#WWWWWW#....#WWWWW#.....#WW##W#.....#W#.#W#.....#..#WW#.........#WW#........#WW#.........#W#..........#....."

/// Where the pointer's point stands, and whether it is drawn.
var pointerX = 0
var pointerY = 0
var pointerIsDrawn = false

/// The rect the cushion currently holds: the pointer's last
/// drawn place, clipped to the screen.
var pointerUnderX = 0
var pointerUnderY = 0
var pointerUnderW = 0
var pointerUnderH = 0

/// Lays the cushion back: the ground the pointer was standing
/// on is restored, pixel for pixel, and the pointer is nowhere.
func pointerHide() {
    if !pointerIsDrawn { return }
    let cushion = cardnullGuiCushion()
    for row in 0 ..< pointerUnderH {
        for col in 0 ..< pointerUnderW {
            guiWriteRaw(pointerUnderX + col, pointerUnderY + row,
                        cushion[row * pointerArtWidth + col])
        }
    }
    pointerIsDrawn = false
}

/// Draws the pointer where it stands: first the ground beneath
/// it is lifted into the cushion, then the arrow is laid over.
func pointerShow() {
    let width = min(pointerArtWidth, framebufferWidth - pointerX)
    let height = min(pointerArtHeight, framebufferHeight - pointerY)
    if width <= 0 || height <= 0 { return }
    pointerUnderX = pointerX
    pointerUnderY = pointerY
    pointerUnderW = width
    pointerUnderH = height
    let cushion = cardnullGuiCushion()
    for row in 0 ..< height {
        for col in 0 ..< width {
            cushion[row * pointerArtWidth + col] =
                guiReadRaw(pointerX + col, pointerY + row)
        }
    }
    for row in 0 ..< height {
        for col in 0 ..< width {
            let cell = pointerArt.utf8Start[row * pointerArtWidth + col]
            if cell == 0x23 {          // '#'
                guiFillRect(pointerX + col, pointerY + row, 1, 1,
                            guiPointerEdgeColor)
            } else if cell == 0x57 {   // 'W'
                guiFillRect(pointerX + col, pointerY + row, 1, 1,
                            guiWhiteColor)
            }
        }
    }
    pointerIsDrawn = true
}

// ---------------------------------------------------------------------------
// The mouse's conversation: packets, clicks, and the door home.
// ---------------------------------------------------------------------------

/// The packet assembly: which byte of the packet is expected
/// next, and the bytes held while its last is coming. Three
/// bytes to a plain mouse's packet; a wheel mouse (milestone
/// 26) speaks a fourth, held in mouseThirdByte's keeping
/// while it comes — mousePacketLength, settled at the
/// waking, is the measure both assemblies keep.
var mouseStage = 0
var mouseFirstByte: UInt8 = 0
var mouseSecondByte: UInt8 = 0
var mouseThirdByte: UInt8 = 0

/// The left button's last known state, so a press is the edge —
/// the change — and not the holding.
var mouseLeftWasDown = false

/// The face's books: how many times the button has been clicked,
/// whether it stands pressed, and whether the way home has been
/// asked for — by the bar's Home button or by Esc, both roads
/// land here.
var guiClickCount = 0
var guiButtonHeld = false
var guiWantsHome = false

/// The mouse's own tallies (milestone 16), kept by the packet
/// assembly below for the `mouse` command: every byte the
/// assembly has taken, every packet it has made whole, and
/// every press of the button it has answered. They count only
/// what truly passed through the face's hands — nothing is
/// estimated, and nothing the mouse did outside the face is
/// claimed.
var mouseBytesTaken: UInt64 = 0
var mousePacketsTaken: UInt64 = 0
var mousePressesTaken: UInt64 = 0

/// Calls the Terminal up: it takes the room, its conversation
/// is taken up where it stood, and the desktop is repainted
/// in the new standing. The bar's Terminal launcher and the
/// boot's own opening both come down this road.
func guiOpenTerminal() {
    termOpen = true
    guiFocusTerminal = true
    consoleEnterTerminal()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Calls the Welcome card up: it takes the room, and the
/// desktop is repainted in the new standing.
func guiOpenWelcome() {
    welcomeOpen = true
    guiFocusTerminal = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// A press inside the Welcome card, the card being asked in
/// its own seniority. Its close box closes the card alone now
/// (milestone 14) — the face's way home moved to the bar's
/// Home button and Esc's standing rule, so both windows'
/// close boxes mean the same plain thing: this window, away.
/// Its button counts the click, in its pressed face, and takes
/// the room as it is pressed. A press in its title bar takes
/// hold for the drag; any other press gives the card the room.
/// Returns false when the point is not the card's at all.
func guiPressWelcome(_ x: Int, _ y: Int) -> Bool {
    // A card that does not stand answers nothing (milestone
    // 25): its rect outlives it in the keeping, and before
    // this guard a press on the bare desktop where the card
    // had stood pressed its ghost — the button painted and
    // counted on empty ground. Its younger siblings (Files,
    // Reader) always checked that they stand; the elder
    // keeps the same law now.
    if !welcomeOpen { return false }
    if !guiWinContains(x, y) { return false }
    if guiCloseBoxContains(x, y) {
        welcomeOpen = false
        // The room falls to the Terminal — unless one of
        // milestone 19's windows already holds it, in which
        // case the closing changes nothing about the room.
        if termOpen && !guiFocusFiles && !guiFocusReader {
            guiFocusTerminal = true
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiButtonContains(x, y) {
        guiSetFocus(false)
        guiClickCount += 1
        guiButtonHeld = true
        pointerHide()
        guiPaintButton()
        guiPaintClicks()
        pointerShow()
        return true
    }
    if guiWinTitleContains(x, y) {
        guiSetFocus(false)
        guiBeginDrag(1, x, y)
        return true
    }
    guiSetFocus(false)
    return true
}

/// A press inside the Terminal, the window being asked in its
/// own seniority. Its close box closes only the window — the
/// desktop stands, and the shell's conversation is kept aside
/// for its return. Its maximize box trades the window between
/// its own place and the whole work area. A press in its
/// title bar takes hold for the drag — unless it is the
/// second press of a double-click (milestone 16), which
/// trades the window's size instead, down the maximize box's
/// own road. Any other press gives it the room. Returns false
/// when the point is not the window's at all.
func guiPressTerminal(_ x: Int, _ y: Int) -> Bool {
    if !guiTermContains(x, y) { return false }
    if guiTermCloseContains(x, y) {
        termOpen = false
        consoleLeaveTerminal()
        guiFocusTerminal = false
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiTermMaxContains(x, y) {
        guiSetFocus(true)
        guiToggleTermMaximize()
        return true
    }
    if guiTermTitleContains(x, y) {
        guiSetFocus(true)
        if termTitlePressArmed
            && ticks &- termTitlePressTick <= guiDoubleClickTicks {
            termTitlePressArmed = false
            guiToggleTermMaximize()
            return true
        }
        termTitlePressArmed = true
        termTitlePressTick = ticks
        guiBeginDrag(2, x, y)
        return true
    }
    guiSetFocus(true)
    return true
}

/// A press at the pointer's point, asked of the desktop's
/// parts in their seniority. The bottom bar is asked first —
/// no window ever covers it, so its word is final on its own
/// ground: Home asks for the way home (from any standing of
/// the room — no one is ever trapped), and each launcher
/// opens its window or gives it the room. The windows are
/// then asked in their standing order, the one on top first,
/// so a press in the country they share lands on the one the
/// eye sees there. A press on bare desktop gives the room to
/// the Welcome side — which is to say, Esc will bring the
/// face home from there. Milestone 19: the Files window and
/// the Reader stand in the same asking — the room's holder
/// first (guiRoomHolder's reckoning, the painters' own), then
/// the rest from the top of the fixed order down — and the
/// bar carries a third launcher, Files, asked between the
/// Terminal's and the Welcome card's.
func guiPressAt(_ x: Int, _ y: Int) {
    // While a windowed feather session stands (milestone
    // 25), a press is the session's affair, answered by its
    // own walk below: the desktop's furniture is tended,
    // but nothing opens, closes or counts mid-session.
    if guestWindowed {
        guiPressAtSession(x, y)
        return
    }
    // A press anywhere but a title bar's plain ground puts
    // that bar's double-click pairing down: the second half
    // of a pair must land where the first half did. The Files
    // list's own pairing is put down by any press that does
    // not land on the list itself.
    if !(termOpen && guiTermTitleContains(x, y)
        && !guiTermCloseContains(x, y)
        && !guiTermMaxContains(x, y)) {
        termTitlePressArmed = false
    }
    if !(filesOpen && guiFilesTitleContains(x, y)
        && !guiFilesCloseContains(x, y)
        && !guiFilesMaxContains(x, y)) {
        filesTitlePressArmed = false
    }
    if !(readerOpen && guiReaderTitleContains(x, y)
        && !guiReaderCloseContains(x, y)
        && !guiReaderMaxContains(x, y)) {
        readerTitlePressArmed = false
    }
    if !(filesOpen && guiFilesListContains(x, y)) {
        filesPressArmed = false
    }
    if y >= guiBarTop() {
        if guiBarHomeContains(x, y) {
            guiWantsHome = true
            return
        }
        if guiBarTermContains(x, y) {
            if termOpen {
                guiSetFocus(true)
            } else {
                guiOpenTerminal()
            }
            return
        }
        if guiBarFilesContains(x, y) {
            if filesOpen {
                guiSetFocusFiles()
            } else {
                guiOpenFiles()
            }
            return
        }
        if guiBarWelcomeContains(x, y) {
            if welcomeOpen {
                guiSetFocus(false)
            } else {
                guiOpenWelcome()
            }
            return
        }
        return
    }
    let holder = guiRoomHolder()
    if guiPressWindow(holder, x, y) { return }
    var candidate = 4
    while candidate >= 1 {
        if candidate != holder
            && guiPressWindow(candidate, x, y) { return }
        candidate -= 1
    }
    guiSetFocus(false)
}

/// Asks one window, by its number in the standing order
/// (1 the Welcome card, 2 the Terminal, 3 the Files window,
/// 4 the Reader), to answer a press — the seniority walk's
/// one step, so guiPressAt's order is a reckoning and not a
/// thicket. The two elder windows answer as they always have;
/// the two younger ones first check that they stand at all.
func guiPressWindow(_ window: Int, _ x: Int, _ y: Int) -> Bool {
    if window == 1 { return guiPressWelcome(x, y) }
    if window == 2 { return guiPressTerminal(x, y) }
    if window == 3 { return guiPressFiles(x, y) }
    return guiPressReader(x, y)
}

/// One window's rect by its number in the standing order
/// (milestone 25): the reckoning the session's press walk
/// and the guest's covered-painting both read, so a window
/// is measured the same way by every hand.
func guiWindowRect(_ window: Int) -> (Int, Int, Int, Int) {
    if window == 1 { return (guiWinX, guiWinY, guiWinW, guiWinH) }
    if window == 2 { return (guiTermX, guiTermY, guiTermW, guiTermH) }
    if window == 3 {
        return (guiFilesX, guiFilesY, guiFilesW, guiFilesH)
    }
    if window == 4 {
        return (guiReaderX, guiReaderY, guiReaderW, guiReaderH)
    }
    return (guiFeatherX, guiFeatherY, guiFeatherW, guiFeatherH)
}

/// Whether a window stands open, by its number — the
/// standing check the session's walk and the guest's
/// covered-painting ask before trusting a rect.
func guiWindowStands(_ window: Int) -> Bool {
    if window == 1 { return welcomeOpen }
    if window == 2 { return termOpen }
    if window == 3 { return filesOpen }
    if window == 4 { return readerOpen }
    return featherWinOpen
}

/// The feather window's ground, by the elder windows'
/// measures: the whole window, its title strip, its close
/// box.
func guiFeatherContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiFeatherX && x < guiFeatherX + guiFeatherW
        && y >= guiFeatherY && y < guiFeatherY + guiFeatherH
}

func guiFeatherTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiFeatherX && x < guiFeatherX + guiFeatherW
        && y >= guiFeatherY && y < guiFeatherY + 36
}

func guiFeatherCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiFeatherX, guiFeatherW)
        && x < guiCloseBoxX(guiFeatherX, guiFeatherW) + guiBoxW
        && y >= guiFeatherY + guiBoxTop
        && y < guiFeatherY + guiBoxTop + guiBoxH
}

/// Gives the room during a windowed session (milestone
/// 25): exactly one of the five standings is set — the
/// feather's window (5), the Terminal (2), the Files
/// window (3), the Reader (4), or the Welcome side, which
/// is no window holding it (1) — and the desktop is
/// repainted whole in its new standing, the holder
/// painted last and on top, exactly the face's own rule.
/// A call that changes nothing paints nothing.
func guiSessionFocus(_ window: Int) {
    let feather = window == 5
    let terminal = window == 2
    let files = window == 3
    let reader = window == 4
    if guiFocusFeather == feather && guiFocusTerminal == terminal
        && guiFocusFiles == files && guiFocusReader == reader {
        return
    }
    guiFocusFeather = feather
    guiFocusTerminal = terminal
    guiFocusFiles = files
    guiFocusReader = reader
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// A press while a windowed feather session stands
/// (milestone 25): the session's own seniority walk — the
/// bar first, then the feather's window (it stands over
/// the elders, so its ground is asked before theirs),
/// then the elders from the room's holder down — but with
/// the session's manners. The bar's Home still asks
/// for the way home (no one is ever trapped; the face
/// goes home when the session unwinds), and its launchers
/// give the room to a window that already stands — none
/// opens mid-session. The feather's window answers fully:
/// its close box asks for the session's stop (Esc's
/// request by the mouse's road — the session ends and its
/// verdict is the stopped verdict, as Esc's is), its
/// title takes the room and takes hold for the drag, its
/// body takes the room. The other windows answer with the
/// room only: their furniture — close boxes, buttons,
/// lists — is still until the feather leaves, because
/// their hands would speak into a shell that is standing
/// inside the session. A press on bare desktop gives the
/// room to the Welcome side, as the face's own walk does.
func guiPressAtSession(_ x: Int, _ y: Int) {
    if y >= guiBarTop() {
        if guiBarHomeContains(x, y) {
            guiWantsHome = true
            return
        }
        if guiBarTermContains(x, y) {
            if termOpen { guiSessionFocus(2) }
            return
        }
        if guiBarFilesContains(x, y) {
            if filesOpen { guiSessionFocus(3) }
            return
        }
        if guiBarWelcomeContains(x, y) {
            if welcomeOpen { guiSessionFocus(1) }
            return
        }
        return
    }
    // The feather's window is asked first: it stands over
    // the elders (see guiPaintDesktop), so a point the eye
    // sees as the feather's is the feather's, whoever holds
    // the room. The elders then answer in their order.
    if guiPressWindowSession(5, x, y) { return }
    let holder = guiRoomHolder()
    if holder != 5 && guiPressWindowSession(holder, x, y) {
        return
    }
    var candidate = 4
    while candidate >= 1 {
        if candidate != holder
            && guiPressWindowSession(candidate, x, y) { return }
        candidate -= 1
    }
    guiSessionFocus(1)
}

/// One window's answer to a press during a windowed
/// session, by its number: the feather's window (5)
/// answers with its close box, its title and its room;
/// the elder four answer with the room alone, and only
/// where they stand.
func guiPressWindowSession(_ window: Int, _ x: Int,
                           _ y: Int) -> Bool {
    if window == 5 {
        if !featherWinOpen || !guiFeatherContains(x, y) {
            return false
        }
        if guiFeatherCloseContains(x, y) {
            cardnullSetStopRequest(1)
            return true
        }
        if guiFeatherTitleContains(x, y) {
            guiSessionFocus(5)
            guiBeginDrag(5, x, y)
            return true
        }
        guiSessionFocus(5)
        return true
    }
    if !guiWindowStands(window) { return false }
    let rect = guiWindowRect(window)
    if x < rect.0 || x >= rect.0 + rect.2
        || y < rect.1 || y >= rect.1 + rect.3 {
        return false
    }
    guiSessionFocus(window)
    return true
}

/// A release: if the button stood pressed, it takes its resting
/// face again.
func guiRelease() {
    if guiButtonHeld {
        guiButtonHeld = false
        pointerHide()
        guiPaintButton()
        pointerShow()
    }
}

/// Takes one byte of the mouse's conversation. The first byte of
/// a packet always carries bit 3, and the stage only advances
/// on it — a byte without it is astray (a leftover, a lost
/// partner) and is let go, which is how the assembly finds its
/// feet again after any stumble. A whole packet moves the
/// pointer — restoring its old ground and drawing it new — and
/// answers the button's edges. A wheel mouse's packet carries
/// a fourth byte (milestone 26): the packet is not whole —
/// nothing moves, nothing answers — until it has come.
func guiTakeMouseByte(_ byte: UInt8) {
    mouseBytesTaken &+= 1
    if mouseStage == 0 {
        if byte & 0x08 == 0 { return }
        mouseFirstByte = byte
        mouseStage = 1
        return
    }
    if mouseStage == 1 {
        mouseSecondByte = byte
        mouseStage = 2
        return
    }
    if mouseStage == 2 {
        mouseThirdByte = byte
        if mousePacketLength == 4 {
            mouseStage = 3
            return
        }
        mouseStage = 0
        guiFinishMousePacket(0)
        return
    }
    mouseStage = 0
    // The wheel byte counts a turn away from the hand —
    // the direction a reader turns to read back — as a
    // negative step (so the bench's mouse, and UTM's with
    // it, answers a forward turn with 0xFF). The turning
    // is reckoned the reader's way as the packet is
    // finished: positive turned up, toward older lines,
    // everywhere past this hand.
    guiFinishMousePacket(-Int(Int8(bitPattern: byte)))
}

/// A whole packet is answered: the travels reckoned from its
/// bytes, the pointer moved in its hidden moment (a carried
/// window's outline travelling with it), the button's edges
/// answered, and — when the packet carried a wheel byte that
/// turned — the turning handed to the window under the
/// pointer, by guiWheelTurn. The turning is reckoned the
/// reader's way: positive turned up, away from the hand —
/// toward older lines; negative turned down, toward the
/// present. (The byte itself counts the other way; the
/// assembly turns it over as the packet is finished.)
func guiFinishMousePacket(_ wheelDelta: Int) {
    mousePacketsTaken &+= 1
    var travelX = Int(mouseSecondByte)
    if mouseFirstByte & 0x10 != 0 { travelX -= 256 }
    var travelY = Int(mouseThirdByte)
    if mouseFirstByte & 0x20 != 0 { travelY -= 256 }
    // The mouse reckons up as forward; the screen reckons down,
    // so the Y travel is turned over as it is added.
    let newX = min(max(pointerX + travelX, 0), framebufferWidth - 1)
    let newY = min(max(pointerY - travelY, 0), framebufferHeight - 1)
    if newX != pointerX || newY != pointerY {
        pointerHide()
        pointerX = newX
        pointerY = newY
        // A carried window's outline travels in the pointer's
        // own hidden moment, so the ground it crosses is never
        // torn between the frame and the arrow.
        guiDragMotion()
        pointerShow()
    }
    let leftDown = mouseFirstByte & 0x01 != 0
    if leftDown && !mouseLeftWasDown {
        mousePressesTaken &+= 1
        guiPressAt(pointerX, pointerY)
    } else if !leftDown && mouseLeftWasDown {
        // A carried window is set down before the release is
        // answered, so the button's own theatre never paints
        // over a standing outline.
        guiEndDrag()
        guiRelease()
    }
    mouseLeftWasDown = leftDown
    if wheelDelta != 0 {
        guiWheelTurn(wheelDelta)
    }
}

/// One wheel notch's step in every scrollable view on the
/// face: three lines — a notch is a nudge, not a leap; the
/// page keys make the leaps.
let guiWheelStep = 3

/// The wheel's routing (milestone 26): a turning scrolls the
/// window under the pointer — the rule Tyler's hand already
/// knew when it turned the wheel over the Terminal. The
/// window is addressed the way a press addresses it: the
/// seniority walk (a standing feather's window first, then
/// the room's holder, then the elders down), and the window
/// is given the room before it scrolls, a press's own
/// manners, so its repaint never paints over a neighbour.
/// While a window is being carried there is no routing —
/// the turning is let go, as a press mid-drag is not a
/// second press. The bar and bare desktop have nothing to
/// scroll, and a turning over them is let go too.
func guiWheelTurn(_ delta: Int) {
    if dragWindow != 0 { return }
    // A windowed feather's canvas: the turning is the
    // guest's, gathered into its keeping for its next poll
    // of the mouse (service 8's wheel word).
    if guestWindowed && pointerOverGuestCanvas() {
        guestWheelAccum = min(max(guestWheelAccum + delta,
                                  -128), 127)
        return
    }
    if pointerY >= guiBarTop() { return }
    if guestWindowed {
        // The feather's window stands over the elders: a
        // turning over its frame is swallowed — its ground
        // is the guest's or no one's, never the window
        // peeking from behind it.
        if guiFeatherContains(pointerX, pointerY) { return }
    }
    let holder = guiRoomHolder()
    if guiWheelWindow(holder, delta) { return }
    var candidate = 4
    while candidate >= 1 {
        if candidate != holder
            && guiWheelWindow(candidate, delta) { return }
        candidate -= 1
    }
}

/// One window's answer to a wheel turning, by its number in
/// the standing order: the window must stand and the pointer
/// must stand on it. The Terminal's view, the Files list and
/// the Reader's page each move by the notch's step — up
/// (a positive turning) toward older lines, down toward the
/// present — through the same scroll hands their buttons
/// and keys use, after the window has been given the room
/// (in a session, by the session's own focus hand, which
/// opens nothing). The Welcome card has nothing to scroll:
/// a turning over it is answered and spent. Window 5 is
/// answered by guiWheelTurn itself and never reaches here
/// with work to do.
func guiWheelWindow(_ window: Int, _ delta: Int) -> Bool {
    if window == 5 { return false }
    if !guiWindowStands(window) { return false }
    let rect = guiWindowRect(window)
    if pointerX < rect.0 || pointerX >= rect.0 + rect.2
        || pointerY < rect.1 || pointerY >= rect.1 + rect.3 {
        return false
    }
    if window == 1 { return true }
    if window == 2 {
        if guestWindowed {
            guiSessionFocus(2)
        } else if !guiFocusTerminal {
            guiSetFocus(true)
        }
        termScrollBy(guiWheelStep * delta)
        return true
    }
    if window == 3 {
        if guestWindowed {
            guiSessionFocus(3)
        } else {
            guiSetFocusFiles()
        }
        filesScrollBy(-guiWheelStep * delta)
        return true
    }
    if guestWindowed {
        guiSessionFocus(4)
    } else {
        guiSetFocusReader()
    }
    readerScrollBy(-guiWheelStep * delta)
    return true
}

// ---------------------------------------------------------------------------
// Milestone 13: the mouse's waking, done patiently and on the record.
//
// Milestone 12's waking was a short ceremony — enable the
// auxiliary port, amend the configuration byte, defaults, report
// — with every wait a fixed count of spins and every answer taken
// or let go in passing, and no reset of the mouse itself. On the
// bench emulator it served. On Tyler's UTM the mouse never
// answered at all: not one packet from birth, though the desktop
// drew perfectly and the keyboard spoke. The waking below is the
// full standard ceremony in the standard's order — the mouse
// itself is reset and its self-test word and name are heard
// before defaults and reporting are asked for — with the timer,
// not a spin count, bounding every wait, so a slow emulator's
// late answer is waited for in wall-clock like a fast one's.
// Every answer the device gives is written into the mouse
// report, composed once at boot into the floor's keeping, so
// the console and the desktop tell the same story and the
// screen itself says what the mouse said.
// ---------------------------------------------------------------------------

/// The waking's record: what each step heard, or -1 for silence.
var mouseConfigByte = -1
var mouseResetAck = -1
var mouseBatByte = -1
var mouseIdByte = -1
var mouseDefaultsAck = -1
var mouseEnableAck = -1
var mouseWakeAttempts = 0
var mouseAnswering = false

/// The wheel's record (milestone 26): the name the mouse
/// answers to after the knock — 3 for a wheel mouse, 0 for a
/// plain one, -1 when the knock was never heard (a mouse
/// that had not answered its defaults is never knocked on).
/// The packet length is settled from this word alone.
var mouseWheelIdByte = -1

/// The packet's length in bytes, as the waking settled it:
/// 4 for a wheel mouse — the fourth byte carries the wheel's
/// turning — 3 for a plain one. Every assembly, the face's
/// and the guests', keeps this length from the waking on, so
/// a plain mouse's conversation is byte-for-byte the one the
/// face has always spoken.
var mousePacketLength = 3

/// The configuration byte as re-read after the waking — and
/// again at the desktop's opening: proof the auxiliary port
/// still stands as the waking left it, its IRQ bit set and its
/// clock running. -1 when even that question went unanswered.
var mouseConfigAfter = -1

/// The report's second line begins at this offset in its
/// keeping; the first line is the standing, the second the
/// waking's transcript in short.
var mouseReportLine2Offset = 0

/// The waits' lengths, in ticks — a hundredth of a second
/// each. Half a second for an answer byte is an eternity to a
/// healthy controller and still nothing to a boot; the reset's
/// self-test word is allowed two full seconds, as the standard
/// itself allows it to be slow. Every wait is bounded, so a
/// mouseless machine pays a few seconds at most and boots.
let mouseByteWaitTicks: UInt64 = 50
let mouseBatWaitTicks: UInt64 = 200

/// Waits, on the timer, for the controller to be ready to be
/// spoken to — its input buffer empty — resting in `hlt`
/// between looks. The bound is wall-clock, the same on a slow
/// emulator as on a fast one, which is the whole point of it.
func mouseWaitWrite(_ ticksAllowed: UInt64) -> Bool {
    let deadline = ticks &+ ticksAllowed
    while cardnullInb(0x64) & 0x02 != 0 {
        if ticks >= deadline { return false }
        cardnullHltOnce()
    }
    return true
}

/// Pushes one byte into the keyboard ring by hand — the
/// waking's traffic sorter uses it for bytes that prove to be
/// the keyboard's, arrived while the keyboard's own IRQ stands
/// masked. The same keeping keyboardInterrupt gives them,
/// minus the EOI no unraised IRQ is owed.
func stashKeyboardByte(_ byte: UInt8) {
    let next = (keyRingHead + 1) & (keyRingSize - 1)
    if next != keyRingTail {
        cardnullKeyRing()[keyRingHead] = byte
        keyRingHead = next
    }
}

/// Pushes one byte into the mouse ring by hand — the mirror
/// keeping, for mouse bytes that arrive while the configuration
/// byte is being read back under masked IRQs.
func stashMouseByte(_ byte: UInt8) {
    let next = (mouseRingHead + 1) & (mouseRingSize - 1)
    if next != mouseRingTail {
        cardnullMouseRing()[mouseRingHead] = byte
        mouseRingHead = next
    }
}

/// Reads one byte from the mouse, on the timer: waits for the
/// controller to hold something, then sorts what it holds — a
/// byte the status marks as the mouse's own (bit 5) is the byte
/// asked for; a byte of the keyboard's is stashed in the key
/// ring and the waiting goes on. Returns the mouse's byte, or
/// -1 when the bound runs out in silence.
func mouseReadByte(_ ticksAllowed: UInt64) -> Int {
    let deadline = ticks &+ ticksAllowed
    while true {
        let status = cardnullInb(0x64)
        if status & 0x01 != 0 {
            let fromMouse = status & 0x20 != 0
            let byte = cardnullInb(0x60)
            if fromMouse { return Int(byte) }
            stashKeyboardByte(byte)
        } else {
            if ticks >= deadline { return -1 }
            cardnullHltOnce()
        }
    }
}

/// Empties whatever the controller is holding — bootloader
/// leftovers, early answers — sorting as it goes, so the
/// conversation below begins on a clean boundary.
func mouseDrain() {
    var guardCount = 0
    while cardnullInb(0x64) & 0x01 != 0 && guardCount < 64 {
        let status = cardnullInb(0x64)
        let byte = cardnullInb(0x60)
        if status & 0x20 == 0 { stashKeyboardByte(byte) }
        guardCount += 1
    }
}

/// Speaks one byte to the mouse itself, through the
/// controller's 0xD4 prefix — the next byte written to the data
/// port is for the mouse, not the keyboard — and returns its
/// answer: 0xFA, understood, or -1 for silence.
func mouseSendByte(_ byte: UInt8) -> Int {
    _ = mouseWaitWrite(mouseByteWaitTicks)
    cardnullOutb(0x64, 0xD4)
    _ = mouseWaitWrite(mouseByteWaitTicks)
    cardnullOutb(0x60, byte)
    return mouseReadByte(mouseByteWaitTicks)
}

/// Sets the mouse's sample rate (milestone 26): the 0xF3
/// word, then the rate itself — two answers, and the second
/// is the one returned. The knock below is made of these.
func mouseSetSampleRate(_ rate: UInt8) -> Int {
    if mouseSendByte(0xF3) != 0xFA { return -1 }
    return mouseSendByte(rate)
}

/// The IntelliMouse knock (milestone 26): the sample rates
/// 200, 100, 80 set in that order — the sequence a wheel
/// mouse is listening for — and then the name asked again
/// (0xF2). A plain mouse answers its name unchanged, 0; a
/// wheel mouse answers 3, and from that answer on it speaks
/// in four-byte packets, the fourth byte carrying the
/// wheel's turning. The answer is kept in mouseWheelIdByte
/// and the packet length settled from it. The rate is then
/// set back to 100, the default it was found at — the knock
/// changes the mouse's name, not its manners. Only a mouse
/// that has already answered (its defaults heard) is ever
/// knocked on: silence is not knocked on, so a mouseless
/// machine pays nothing for the asking.
func mouseAskForWheel() {
    mouseWheelIdByte = -1
    if mouseSetSampleRate(200) != 0xFA { return }
    if mouseSetSampleRate(100) != 0xFA { return }
    if mouseSetSampleRate(80) != 0xFA { return }
    if mouseSendByte(0xF2) != 0xFA { return }
    mouseWheelIdByte = mouseReadByte(mouseByteWaitTicks)
    _ = mouseSetSampleRate(100)
    if mouseWheelIdByte == 3 {
        mousePacketLength = 4
    } else {
        mousePacketLength = 3
    }
}

/// Asks the controller for its configuration byte (ask with
/// 0x20, then take it) and returns it, or -1 in silence. The
/// answer is a controller byte, arriving unmarked like the
/// keyboard's, so the read sorts the other way: marked bytes
/// are the mouse's and are stashed in its ring. Only ever made
/// while both input IRQs stand masked.
func controllerReadConfig() -> Int {
    _ = mouseWaitWrite(mouseByteWaitTicks)
    cardnullOutb(0x64, 0x20)
    let deadline = ticks &+ mouseByteWaitTicks
    while true {
        let status = cardnullInb(0x64)
        if status & 0x01 != 0 {
            let byte = cardnullInb(0x60)
            if status & 0x20 == 0 { return Int(byte) }
            stashMouseByte(byte)
        } else {
            if ticks >= deadline { return -1 }
            cardnullHltOnce()
        }
    }
}

/// Writes the controller's configuration byte: the 0x60 word
/// first, then the byte itself.
func controllerWriteConfig(_ value: UInt8) {
    _ = mouseWaitWrite(mouseByteWaitTicks)
    cardnullOutb(0x64, 0x60)
    _ = mouseWaitWrite(mouseByteWaitTicks)
    cardnullOutb(0x60, value)
}

/// Masks the two input IRQs at the PICs, so a polled
/// conversation owns the controller's data port outright — no
/// handler may reach into its middle. The timer's IRQ stays
/// open: the waits are reckoned on its count. The mask ports
/// are the PICs' data ports, 0x21 for the master (IRQ1 is its
/// bit 1) and 0xA1 for the slave (IRQ12 is its bit 4).
func mouseMaskInputs() {
    cardnullOutb(0x21, cardnullInb(0x21) | 0x02)
    cardnullOutb(0xA1, cardnullInb(0xA1) | 0x10)
}

/// Undoes the masking, bit for bit.
func mouseUnmaskInputs() {
    cardnullOutb(0x21, cardnullInb(0x21) & ~0x02)
    cardnullOutb(0xA1, cardnullInb(0xA1) & ~0x10)
}

/// One full waking of the mouse, in the standard's order:
/// whatever the controller still holds is drained away; the
/// auxiliary port — the mouse's side of the controller — is
/// enabled (0xA8); the configuration byte is read, amended
/// (the mouse's IRQ may knock; its clock runs) and written
/// back; the mouse itself is reset (0xFF) and its answer,
/// its self-test word (0xAA) and its name (the device ID) are
/// heard; its defaults are set (0xF6); the wheel knock is
/// knocked (milestone 26 — sample rates 200, 100, 80, then
/// the name asked again, settling the packet's length); and
/// it is told to begin reporting (0xF4). Returns true when the reporting answer
/// was the mouse's own 0xFA — the one word that promises a
/// stream.
func mouseWakeAttempt() -> Bool {
    mouseDrain()
    _ = mouseWaitWrite(mouseByteWaitTicks)
    cardnullOutb(0x64, 0xA8)
    var config: UInt8 = 0x47
    let heard = controllerReadConfig()
    if heard >= 0 {
        mouseConfigByte = heard
        config = UInt8(heard)
    }
    config |= 0x02        // the mouse's IRQ (IRQ12) may knock
    config &= ~0x20       // the mouse's clock runs
    controllerWriteConfig(config)
    mouseResetAck = mouseSendByte(0xFF)
    mouseBatByte = -1
    mouseIdByte = -1
    mouseWheelIdByte = -1
    mousePacketLength = 3
    if mouseResetAck == 0xFA {
        mouseBatByte = mouseReadByte(mouseBatWaitTicks)
        if mouseBatByte == 0xAA {
            mouseIdByte = mouseReadByte(mouseByteWaitTicks)
        }
    }
    mouseDefaultsAck = mouseSendByte(0xF6)
    // The knock (milestone 26), asked only of a mouse that
    // has answered its defaults — it is listening, so the
    // asking is cheap; a silent mouse is never knocked on.
    if mouseDefaultsAck == 0xFA {
        mouseAskForWheel()
    }
    mouseEnableAck = mouseSendByte(0xF4)
    return mouseEnableAck == 0xFA
}

/// Wakes the mouse, once, at boot — called from kmain after
/// the interrupts stand, because the waking's waits are
/// reckoned on the heartbeat. One full attempt; if it hears
/// silence, one more, whole — a slow emulator's first word can
/// simply be late. Then the configuration byte is read once
/// more, with the shell about to stand, so the report can say
/// the auxiliary port still stands as the waking left it. A
/// mouseless machine pays the bounded waits and boots anyway.
func initMouse() {
    mouseMaskInputs()
    mouseWakeAttempts = 1
    mouseAnswering = mouseWakeAttempt()
    if !mouseAnswering {
        mouseWakeAttempts = 2
        mouseAnswering = mouseWakeAttempt()
    }
    mouseConfigAfter = controllerReadConfig()
    mouseUnmaskInputs()
    composeMouseReport()
}

/// The desktop's opening courtesy to the mouse: the
/// configuration byte is read once more, and if the auxiliary
/// port's standing has been undone since the waking — its IRQ
/// bit cleared, its clock stopped — the waking's amendment is
/// written back. And if the mouse never answered at boot, it
/// is told once more to report; a late answer recomposes the
/// report, so the desktop's standing line stays the truth.
func mouseVerifyAtDesktop() {
    mouseMaskInputs()
    let config = controllerReadConfig()
    if config >= 0 {
        mouseConfigAfter = config
        if config & 0x02 == 0 || config & 0x20 != 0 {
            var amended = UInt8(config)
            amended |= 0x02
            amended &= ~0x20
            controllerWriteConfig(amended)
        }
    }
    if !mouseAnswering && mouseSendByte(0xF4) == 0xFA {
        mouseAnswering = true
        mouseEnableAck = 0xFA
        composeMouseReport()
    }
    mouseUnmaskInputs()
}

/// The report composer's pen: where the next byte goes in the
/// keeping. Composition is plain byte work, done once — the
/// printing and drawing hands only read what stands here.
var mouseReportPen = 0

func mouseReportPut(_ byte: UInt8) {
    if mouseReportPen < 159 {
        cardnullMouseReport()[mouseReportPen] = byte
        mouseReportPen += 1
    }
}

func mouseReportWord(_ word: StaticString) {
    var index = 0
    while word.utf8Start[index] != 0 {
        mouseReportPut(word.utf8Start[index])
        index += 1
    }
}

/// Two hex digits for a heard byte, or "--" for silence.
func mouseReportHex(_ value: Int) {
    if value < 0 {
        mouseReportPut(0x2D)   // '-'
        mouseReportPut(0x2D)
        return
    }
    let digits: StaticString = "0123456789ABCDEF"
    mouseReportPut(digits.utf8Start[(value >> 4) & 0xF])
    mouseReportPut(digits.utf8Start[value & 0xF])
}

/// Composes the mouse report's two lines into the floor's
/// keeping. The first line is the standing — "Mouse:
/// answering (id 0x00)." with the device ID the waking heard,
/// or "Mouse: not answering." — and the second is the waking's
/// transcript in short: what each step heard, "--" where the
/// answer was silence, and how the port stood when re-read.
/// The report is the boot screen's testimony and, since
/// milestone 16, the `mouse` command's answer — codes, kept
/// where codes belong; the desktop's bar speaks its plain
/// words instead ("Mouse ready"), from the same standing.
/// Milestone 26: the name the first line speaks is the
/// mouse's name after the knock when the knock was heard —
/// the name it now answers to — and the wheel's standing is
/// stated in plain words beside it, with the knock's own
/// answer kept in the transcript.
func composeMouseReport() {
    mouseReportPen = 0
    mouseReportWord("Mouse: ")
    if mouseAnswering {
        mouseReportWord("answering (id 0x")
        mouseReportHex(mouseWheelIdByte >= 0
            ? mouseWheelIdByte : mouseIdByte)
        mouseReportWord(").")
        if mouseWheelIdByte == 3 {
            mouseReportWord(" Its wheel turns.")
        } else if mouseWheelIdByte == 0 {
            mouseReportWord(" It has no wheel.")
        }
    } else {
        mouseReportWord("not answering.")
    }
    mouseReportPut(0)
    mouseReportLine2Offset = mouseReportPen
    mouseReportWord("  wake: config ")
    mouseReportHex(mouseConfigByte)
    mouseReportWord(", reset ")
    mouseReportHex(mouseResetAck)
    mouseReportWord(", self-test ")
    mouseReportHex(mouseBatByte)
    mouseReportWord(", defaults ")
    mouseReportHex(mouseDefaultsAck)
    mouseReportWord(", reporting ")
    mouseReportHex(mouseEnableAck)
    mouseReportWord(", wheel ")
    mouseReportHex(mouseWheelIdByte)
    mouseReportWord(", port now ")
    mouseReportHex(mouseConfigAfter)
    mouseReportWord(", tries ")
    mouseReportPut(0x30 + UInt8(mouseWakeAttempts))
    mouseReportPut(0)
}

/// mouse's vocabulary: the tallies' labels, spoken beneath
/// the report.
let mouseBytesLabel: StaticString =
    "  Bytes the face has taken from it: "
let mousePacketsLabel: StaticString =
    "  Packets made whole: "
let mousePressesLabel: StaticString =
    "  Presses of its button answered: "

/// The `mouse` command's answer (milestone 16): the report
/// itself — the standing and the waking's transcript, exactly
/// the words the boot screen spoke, codes and all, in the
/// Terminal where codes belong — and beneath it the face's
/// tallies: what the mouse has truly done since the face
/// first opened, counted by the packet assembly's own hand.
func printMouseStanding() {
    printMouseReport()
    writeStatic(mouseBytesLabel)
    writeNumber(mouseBytesTaken)
    writeNewline()
    writeStatic(mousePacketsLabel)
    writeNumber(mousePacketsTaken)
    writeNewline()
    writeStatic(mousePressesLabel)
    writeNumber(mousePressesTaken)
    writeNewline()
}

/// Prints the report on the console, both lines, through the
/// one output door — the same bytes the `mouse` command speaks.
func printMouseReport() {
    let report = cardnullMouseReport()
    var index = 0
    while report[index] != 0 {
        writeChar(report[index])
        index += 1
    }
    writeNewline()
    index = mouseReportLine2Offset
    while report[index] != 0 {
        writeChar(report[index])
        index += 1
    }
    writeNewline()
}

/// Takes any mouse bytes the controller is holding that the
/// IRQ road never delivered — marked as the mouse's own (bit
/// 5), read straight off the port into the packet assembly.
/// The face polls as well as listens, so an interrupt road
/// gone silent in some host cannot starve the pointer while
/// the bytes sit waiting. The keyboard's bytes are left
/// strictly alone: they are IRQ1's affair. Returns true when
/// anything was taken.
func guiPollMousePort() -> Bool {
    var took = false
    var guardCount = 0
    while guardCount < 64 {
        let status = cardnullInb(0x64)
        if status & 0x01 == 0 { break }
        if status & 0x20 == 0 { break }
        guiTakeMouseByte(cardnullInb(0x60))
        took = true
        guardCount += 1
    }
    return took
}

/// The `gui` command's work: open the face, keep it until the
/// way home is asked for, and restore the console exactly. It
/// is also the boot's front door now: kmain calls it once the
/// news is spoken, so the machine wakes into its face.
///
/// On a boot that brought no framebuffer there is no face to
/// open — the VGA text grid keeps pixels for no one — and the
/// command says so plainly, in the shell, and that is all.
///
/// The desktop (milestone 14): the Terminal stands large over
/// the work area, holding the room at the opening, its grid
/// reckoned from its window; the Welcome card — the house
/// verse and its counting button, in a compact card — starts
/// closed and is called up from the bottom bar. The bar
/// carries the mouse's standing line, a launcher for each
/// window, the session's uptime, and the Home button. Windows
/// are dragged by their title bars, and the Terminal carries
/// a maximize control. The ways home: the bar's Home button,
/// from any standing of the room; and Esc, whenever the
/// Terminal does not hold the keyboard — while it does, Esc
/// is the shell's own key and does nothing special, exactly
/// as on the text console. No standing traps anyone: closing
/// the Terminal, or pressing the card, the other window, or
/// bare desktop, arms Esc again, and Home never sleeps.
/// Milestone 19 stands two more windows on the face — the
/// Files window and the Reader, in their own section below —
/// and the loop knows them by their standing in the room:
/// while either holds it, the arrow and page keys scroll it,
/// and Esc's rule is unchanged.
func runGui() {
    // The `files` command's word, taken and cleared at the
    // door (milestone 19): typed at the text console, it asks
    // for the face with the Files window standing on it.
    let wantFiles = filesWantedAtFace
    filesWantedAtFace = false
    if !useFramebuffer {
        writeLine(guiNoScreenLine)
        return
    }
    // The face's arrangement (milestone 14): the Welcome card
    // compact at the left, for when it is called up; the
    // Terminal large over the work area — a modest inset from
    // the edges, under the desktop's name, above the bar.
    guiWinW = min(448, framebufferWidth - 32)
    guiWinH = min(320, framebufferHeight - guiBarHeight - 140)
    guiWinX = 48
    guiWinY = 120
    guiTermX = 16
    guiTermY = guiWorkTop
    guiTermW = framebufferWidth - 32
    guiTermH = guiBarTop() - guiWorkTop - 12
    // Milestone 19's two windows join the arrangement: the
    // Files window standing off-centre over the Terminal —
    // large enough to read a disc by, small enough that the
    // Terminal stands around it — and the Reader a page's
    // shape beside it. Both start closed, as the Welcome
    // card does; the bar calls them up.
    guiFilesW = min(688, framebufferWidth - 32)
    guiFilesH = min(448, guiBarTop() - guiWorkTop - 24)
    guiFilesX = min(360, framebufferWidth - guiFilesW - 16)
    guiFilesY = 136
    if guiFilesY + guiFilesH > guiBarTop() - 8 {
        guiFilesY = guiBarTop() - 8 - guiFilesH
    }
    if guiFilesY < guiWorkTop { guiFilesY = guiWorkTop }
    guiReaderW = min(640, framebufferWidth - 32)
    guiReaderH = min(480, guiBarTop() - guiWorkTop - 24)
    guiReaderX = min(420, framebufferWidth - guiReaderW - 16)
    guiReaderY = 120
    if guiReaderY + guiReaderH > guiBarTop() - 8 {
        guiReaderY = guiBarTop() - 8 - guiReaderH
    }
    if guiReaderY < guiWorkTop { guiReaderY = guiWorkTop }
    welcomeOpen = false
    termMaximized = false
    termSavedX = guiTermX
    termSavedY = guiTermY
    termSavedW = guiTermW
    termSavedH = guiTermH
    filesOpen = false
    readerOpen = false
    guiFocusFiles = false
    guiFocusReader = false
    filesMaximized = false
    filesSavedX = guiFilesX
    filesSavedY = guiFilesY
    filesSavedW = guiFilesW
    filesSavedH = guiFilesH
    readerMaximized = false
    readerSavedX = guiReaderX
    readerSavedY = guiReaderY
    readerSavedW = guiReaderW
    readerSavedH = guiReaderH
    filesScroll = 0
    filesSelected = -1
    filesPressArmed = false
    filesTitlePressArmed = false
    readerTitlePressArmed = false
    readerScroll = 0
    dragWindow = 0
    dragOutlineDrawn = false
    termTitlePressArmed = false
    guiClickCount = 0
    guiButtonHeld = false
    guiWantsHome = false
    mouseStage = 0
    mouseLeftWasDown = false
    // The mouse may have spoken while the shell held the room.
    // That is old news: the ring is drained, so the face opens
    // on a clean ring and a whole packet boundary.
    while nextMouseByte() != nil {}
    // The opening courtesy (milestone 13): the configuration
    // byte re-read and healed if anything has undone the
    // waking's amendment, and one more word spoken to a mouse
    // that never answered — before the standing line is drawn.
    mouseVerifyAtDesktop()
    // The bar's layout (milestone 16) is reckoned now, with
    // the mouse's standing settled, before the first painting
    // reads it.
    guiLayoutBar()
    termOpen = true
    guiFocusTerminal = true
    consoleEnterTerminal()
    // The pointer opens at the screen's centre — a known place,
    // so its first standing can be witnessed, not guessed.
    pointerX = framebufferWidth / 2
    pointerY = framebufferHeight / 2
    pointerIsDrawn = false
    guiPaintDesktop()
    pointerShow()
    // The `files` command's word, honoured: the face opens
    // with the Files window standing on it.
    if wantFiles {
        guiOpenFiles()
    }
    // The face's whole work: drain the mouse's ring (and poll
    // its port) into packets; give the keyboard's ring to the
    // shell when the Terminal holds the room, and watch it for
    // Esc when it does not; repaint the Terminal's touched rows
    // when the shell has written; and rest in `hlt` whenever
    // all are quiet — the timer's heartbeat wakes the resting
    // a hundred times a second, which no hand will ever notice.
    // Milestone 19: while the Files window or the Reader holds
    // the room, the arrow and page keys scroll it — they arrive
    // as extended codes behind the 0xE0 prefix, whose standing
    // the loop keeps between codes in e0Pending. Every other
    // key still does nothing there, and Esc still goes home.
    // Milestone 26: while the Terminal holds the room, the
    // page keys are the view's, not the shell's — the same
    // prefix kept in the same e0Pending — and any other
    // keypress first brings a lifted view home.
    var e0Pending = false
    while !guiWantsHome {
        var worked = false
        while let byte = nextMouseByte() {
            guiTakeMouseByte(byte)
            worked = true
            if guiWantsHome { break }
        }
        if guiWantsHome { break }
        if guiPollMousePort() { worked = true }
        if guiWantsHome { break }
        while let code = nextScancode() {
            worked = true
            if termOpen && guiFocusTerminal {
                if e0Pending {
                    e0Pending = false
                    if code == 0x49 {          // Page Up
                        termScrollBy(termRows - 1)
                    } else if code == 0x51 {   // Page Down
                        termScrollBy(-(termRows - 1))
                    } else {
                        handleScancode(0xE0)
                        handleScancode(code)
                    }
                } else if code == 0xE0 {
                    e0Pending = true
                } else {
                    // A keypress while the view stands lifted
                    // (milestone 26): the view comes home to
                    // the live end first, so the key is
                    // answered in the present it lands in.
                    if termViewOffset > 0 && code & 0x80 == 0 {
                        termScrollBy(-termViewOffset)
                    }
                    handleScancode(code)
                }
            } else if e0Pending {
                e0Pending = false
                guiScrollKey(code)
            } else if code == 0xE0 {
                e0Pending = true
            } else if code == 0x01 {          // Esc, pressed
                guiWantsHome = true
            }
            if guiWantsHome { break }
        }
        // The Terminal's touched rows are repainted only while
        // the window holds the room — which is to say, while it
        // stands on top, where its paint belongs. A span left
        // pending under the other window is answered whole by
        // the next full paint that raises it. While the view
        // stands lifted (milestone 26) the span gathers
        // unanswered: the read lines stand as they were left,
        // and the return to the live end repaints whole.
        if consoleInTerminal && guiFocusTerminal
            && termViewOffset == 0 && termDirtyTop >= 0 {
            let top = termDirtyTop
            let bottom = termDirtyBottom
            termDirtyTop = -1
            termDirtyBottom = -1
            pointerHide()
            guiPaintTermRows(top, bottom)
            pointerShow()
            worked = true
        }
        // The bar's clock, once a second: only its own patch
        // is repainted, in the pointer's hidden moment.
        if guiClockVisible && ticks / 100 != guiClockSecond {
            pointerHide()
            guiPaintClock()
            pointerShow()
            worked = true
        }
        // Milestone 29's citizenship, at the face's idle point:
        // the wire is minded on every pass before the rest, so
        // the Terminal's conversation — the shell this face
        // holds — is answered for even while the desktop stands.
        // The service's own guards keep it out of any `net`
        // conversation the Terminal is holding.
        netService()
        if !worked {
            cardnullHltOnce()
        }
    }
    pointerHide()
    // The way home. The Terminal's conversation is kept aside
    // whole for its next opening, and the console's grid was
    // never touched — the whole conversation still stands in
    // it — so blacken the whole pixel field, the desktop having
    // ranged past the grid's rows, and paint the grid back
    // through the screen. The shell's own hands then open the
    // next prompt beneath it.
    if consoleInTerminal {
        consoleLeaveTerminal()
    }
    for row in 0 ..< framebufferHeight {
        for col in 0 ..< framebufferWidth {
            putPixel(x: col, y: row, white: false)
        }
    }
    repaintScreen()
    moveHardwareCursor()
}

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
/// 3 the Files window, 4 the Reader. At most one of the three
/// younger standings ever stands; every hand that gives the
/// room clears the others as it takes it.
func guiRoomHolder() -> Int {
    if guiFocusFeather { return 5 }
    if guiFocusReader { return 4 }
    if guiFocusFiles { return 3 }
    if guiFocusTerminal { return 2 }
    return 1
}

/// Gives the room to the Files window: the whole desktop is
/// repainted in the new standing, as guiSetFocus repaints it
/// for the elder two.
func guiSetFocusFiles() {
    if guiFocusFiles && !guiFocusTerminal && !guiFocusReader {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = true
    guiFocusReader = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Gives the room to the Reader, by the same road.
func guiSetFocusReader() {
    if guiFocusReader && !guiFocusTerminal && !guiFocusFiles {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = true
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

// ---------------------------------------------------------------------------
// Opening, by kind — and the scroll keys the face's loop
// answers while one of the new windows holds the room.
// ---------------------------------------------------------------------------

/// The scroll keys, answered by runGui's loop when the
/// Terminal does not hold the keyboard: the extended codes
/// behind the 0xE0 prefix — Up and Down a line, Page Up and
/// Page Down a windowful — given to whichever of the new
/// windows holds the room. All other extended keys are let
/// go, as the face has always let them go.
func guiScrollKey(_ code: UInt8) {
    if guiFocusFiles && filesOpen {
        if code == 0x48 {              // Up
            filesScrollBy(-1)
        } else if code == 0x50 {       // Down
            filesScrollBy(1)
        } else if code == 0x49 {       // Page Up
            filesScrollBy(-filesVisibleRows())
        } else if code == 0x51 {       // Page Down
            filesScrollBy(filesVisibleRows())
        }
    } else if guiFocusReader && readerOpen {
        if code == 0x48 {
            readerScrollBy(-1)
        } else if code == 0x50 {
            readerScrollBy(1)
        } else if code == 0x49 {
            readerScrollBy(-readerVisibleRows())
        } else if code == 0x51 {
            readerScrollBy(readerVisibleRows())
        }
    }
}

/// Is the Terminal's own standing line empty? The shell's
/// live marks answer when the conversation stands in the
/// window; when the window is closed, its conversation is
/// kept aside in its saved marks and its grid, and those
/// answer — the same bytes a reopening would resume.
func guiFilesTerminalBlank() -> Bool {
    if consoleInTerminal { return lineIsBlank() }
    if !termStarted { return true }
    let grid = cardnullTermGrid()
    let start = termSavedLineStartRow * termStrideColumns
        + termSavedLineStartCol
    let end = termSavedCursorRow * termStrideColumns
        + termSavedCursorCol
    var cell = start
    while cell < end {
        if grid[cell] != 0x20 { return false }
        cell += 1
    }
    return true
}

/// Launches one entry — a feather or a bare program —
/// through the Terminal, by typing its command: the Terminal
/// is opened or given the room, and then the command's very
/// letters are written through the shell's typing hand and
/// the line is submitted to the shell's answering hand, so
/// what follows — the card, the proof, the run, the report —
/// is the commands' own work, not a likeness of it. A line
/// the user has half-typed is never typed over: the window
/// says so in its status line instead, and opens nothing.
func guiFilesLaunch(_ entry: Int) {
    if !guiFilesTerminalBlank() {
        filesSetStatus(filesTerminalBusyLine)
        pointerHide()
        guiPaintFilesWindow()
        pointerShow()
        return
    }
    if !termOpen {
        guiOpenTerminal()
    } else {
        guiSetFocus(true)
    }
    if filesEntryKind(entry) == filesKindFeather {
        writeStatic(featherCommand)
    } else {
        writeStatic(runCommand)
    }
    writeChar(0x20)                    // ' '
    writeChar(0x2F)                    // '/'
    let base = cardnullFilesKeeping()
    let nameLength = filesEntryNameLength(entry)
    var index = 0
    while index < nameLength {
        writeChar(base[entry * filesEntryStride + index])
        index += 1
    }
    submitLine()
}

/// A double-click's opening, by kind: a page to the Reader,
/// a package or a program to the Terminal's road, and the
/// kinds that do not open answered in the status line, in
/// words — the window does not guess with a double-click.
func guiFilesOpenEntry(_ entry: Int) {
    let kind = filesEntryKind(entry)
    if kind == filesKindText {
        guiOpenReader(entry)
    } else if kind == filesKindFeather
        || kind == filesKindProgram {
        guiFilesLaunch(entry)
    } else if kind == filesKindFolder {
        filesSetStatusNameSentence(entry, filesFolderSuffix)
        pointerHide()
        guiPaintFilesWindow()
        pointerShow()
    } else {
        filesSetStatusNameSentence(entry, filesSystemSuffix)
        pointerHide()
        guiPaintFilesWindow()
        pointerShow()
    }
}

/// A press inside the Files window, the window asked in its
/// own seniority, as its siblings are: its close box closes
/// it alone — the room falling to the Terminal when the
/// Terminal stands, as the Welcome card's closing lets it
/// fall; its maximize box trades its size; its title bar
/// takes hold for the drag, unless the press is the second
/// of a pair, which trades the size instead; its scroll
/// buttons step the list a line; a press on the list chooses
/// its entry — and a second press on the same entry, inside
/// the pairing's window, is the double-click that opens it.
/// Any other press gives the window the room. Returns false
/// when the point is not the window's at all.
func guiPressFiles(_ x: Int, _ y: Int) -> Bool {
    if !filesOpen { return false }
    if !guiFilesContains(x, y) { return false }
    if guiFilesCloseContains(x, y) {
        filesOpen = false
        filesPressArmed = false
        if guiFocusFiles {
            guiFocusFiles = false
            guiFocusTerminal = termOpen
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiFilesMaxContains(x, y) {
        guiSetFocusFiles()
        guiToggleFilesMaximize()
        return true
    }
    if guiFilesTitleContains(x, y) {
        guiSetFocusFiles()
        if filesTitlePressArmed
            && ticks &- filesTitlePressTick
                <= guiDoubleClickTicks {
            filesTitlePressArmed = false
            guiToggleFilesMaximize()
            return true
        }
        filesTitlePressArmed = true
        filesTitlePressTick = ticks
        guiBeginDrag(3, x, y)
        return true
    }
    if guiFilesUpContains(x, y) {
        guiSetFocusFiles()
        filesScrollBy(-1)
        return true
    }
    if guiFilesDownContains(x, y) {
        guiSetFocusFiles()
        filesScrollBy(1)
        return true
    }
    if guiFilesListContains(x, y) {
        guiSetFocusFiles()
        let row = filesRowAt(y)
        if row >= 0 {
            if filesPressArmed && row == filesPressRow
                && ticks &- filesPressTick
                    <= guiDoubleClickTicks {
                filesPressArmed = false
                filesSelected = row
                guiFilesOpenEntry(row)
                return true
            }
            filesPressArmed = true
            filesPressRow = row
            filesPressTick = ticks
            if filesSelected != row {
                filesSelected = row
                pointerHide()
                guiPaintFilesWindow()
                pointerShow()
            }
        }
        return true
    }
    guiSetFocusFiles()
    return true
}

/// A press inside the Reader, in the same seniority: its
/// close box closes it alone — the room falling back to the
/// Files window it was opened from, when that still stands —
/// its maximize box, its title bar's drag and double-click,
/// its scroll buttons, and any other press giving it the
/// room. Returns false when the point is not the Reader's.
func guiPressReader(_ x: Int, _ y: Int) -> Bool {
    if !readerOpen { return false }
    if !guiReaderContains(x, y) { return false }
    if guiReaderCloseContains(x, y) {
        readerOpen = false
        if guiFocusReader {
            guiFocusReader = false
            if filesOpen {
                guiFocusFiles = true
            } else {
                guiFocusTerminal = termOpen
            }
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiReaderMaxContains(x, y) {
        guiSetFocusReader()
        guiToggleReaderMaximize()
        return true
    }
    if guiReaderTitleContains(x, y) {
        guiSetFocusReader()
        if readerTitlePressArmed
            && ticks &- readerTitlePressTick
                <= guiDoubleClickTicks {
            readerTitlePressArmed = false
            guiToggleReaderMaximize()
            return true
        }
        readerTitlePressArmed = true
        readerTitlePressTick = ticks
        guiBeginDrag(4, x, y)
        return true
    }
    if guiReaderUpContains(x, y) {
        guiSetFocusReader()
        readerScrollBy(-1)
        return true
    }
    if guiReaderDownContains(x, y) {
        guiSetFocusReader()
        readerScrollBy(1)
        return true
    }
    guiSetFocusReader()
    return true
}

/// The `files` command's work: in the Terminal, the window
/// opens where the conversation stands; at the text console,
/// the face opens with the window standing on it — the word
/// is left for runGui at its door, and the command walks the
/// `gui` command's own road in.
func runFilesCommand() {
    if consoleInTerminal {
        guiOpenFiles()
    } else {
        filesWantedAtFace = true
        runGui()
    }
}
//
// The machine has been silent for sixteen milestones. This stone
// gives it the smallest honest voice: the PC speaker, the beeper
// every PC has carried since the first one — no sound chip, no
// driver stack, just the programmable timer's second channel and
// a gate.
//
// The timer (the PIT) has three channels dividing one clock of
// 1,193,182 Hz. Channel 0 is the heartbeat: the floor programmed
// it at the interrupts' raising (command 0x36, divisor 11932, in
// support.c) and this stone never touches it — the uptime, the
// scheduler's slices, and the bar's clock all read its count, and
// they keep their beat through every note below and after them.
// Channel 2 is the speaker's own: its output reaches the speaker
// only while the gate stands open — bits 0 and 1 of port 0x61,
// the first joining the channel's clock to its counter, the
// second joining the counter's voice to the speaker itself.
//
// The tone primitive is three moves: reckon the channel's divisor
// from the wanted frequency (the clock over the frequency, the
// same division the floor's 11932 came from), speak the divisor
// to channel 2 under the command word 0xB6 — channel 2, both
// bytes, the square-wave manner — and open the gate. Silence is
// the gate closed again, and it is the primitive's whole law:
// every road out of the playing below passes through the closing,
// so no tone is ever left standing — not at the phrase's end, and
// not if anything above it ever grows a road away mid-note. A
// note's length is reckoned on the heartbeat itself: the gate
// stands open until the tick count has advanced by the length,
// the kernel resting in `hlt` between looks, exactly as the
// mouse's waits rest — the interrupts live throughout, the
// keyboard's answers queue in their ring and are answered when
// the phrase ends, and the heartbeat never stops for the music.
//
// The command is `sound`: it plays one short phrase — the
// Doxology's opening, "Praise God, from whom all blessings
// flow," on the tune Old Hundredth (Louis Bourgeois, 1551, the
// Genevan Psalter; public domain, as everything here is) — and
// prints each note before it sounds: its name, its frequency,
// and its length, so the playing is accountable on the screen in
// exactly the places it cannot be heard. The shell waits while
// the phrase plays — some three and a half seconds; there is no
// background music machinery, and none is pretended. What this
// stone is not: a voice for guests. The door (interrupt 0x80)
// gains no service — a feather cannot yet sing; a guest sound
// service is future work, named where the door's services are
// published, beside them. And no audio chip is driven: the
// intel-hda in the test machine sits silent, as it has sat for
// every milestone; the speaker is the whole of this stone.
// ---------------------------------------------------------------------------

/// The PIT's command port — the floor writes channel 0's
/// programming through it at the raising of the interrupts; the
/// speaker's programming goes through the same door, addressed to
/// channel 2 alone.
let pitCommandPort: UInt16 = 0x43

/// Channel 2's data port: the divisor's two bytes land here, the
/// low byte first, as the command word promises.
let pitChannel2Port: UInt16 = 0x42

/// The speaker gate's port. Bit 0 is channel 2's gate — the
/// channel counts only while it stands — and bit 1 joins the
/// channel's output to the speaker. The rest of the byte is not
/// this stone's business and is preserved, read and written back,
/// every time the gate is moved.
let speakerGatePort: UInt16 = 0x61

/// The PIT's own clock, which every channel divides: a tone's
/// divisor is this number over the tone's frequency. The floor's
/// heartbeat came from the same division — this clock over 11932
/// is the 100 Hz the whole machine keeps time by.
let pitClockRate: UInt64 = 1_193_182

/// The command word for channel 2: the channel's name in its top
/// two bits, both divisor bytes to follow, the square-wave manner
/// (mode 3), counted in binary — 0xB6, written once per note.
let pitChannel2Command: UInt8 = 0xB6

/// Opens the speaker's gate on a frequency: reckons channel 2's
/// divisor from the frequency, speaks it to the channel, and sets
/// the gate's two bits, preserving the rest of the gate byte. The
/// channel sings from this moment until speakerOff is called —
/// every caller owes that call, and the playing below makes it
/// between every two notes and at the phrase's end.
func speakerOn(_ frequency: UInt64) {
    var divisor = pitClockRate / frequency
    if divisor < 1 { divisor = 1 }
    if divisor > 0xFFFF { divisor = 0xFFFF }
    cardnullOutb(pitCommandPort, pitChannel2Command)
    cardnullOutb(pitChannel2Port, UInt8(divisor & 0xFF))
    cardnullOutb(pitChannel2Port, UInt8((divisor >> 8) & 0xFF))
    let gate = cardnullInb(speakerGatePort)
    cardnullOutb(speakerGatePort, gate | 0x03)
}

/// Closes the speaker's gate: both of its bits cleared, the rest
/// of the byte preserved. The speaker is silent from this moment,
/// whatever the channel's counter still holds — the gate, not the
/// counter, is what the speaker hears.
func speakerOff() {
    let gate = cardnullInb(speakerGatePort)
    cardnullOutb(speakerGatePort, gate & 0xFC)
}

/// Rests until the heartbeat has advanced by the given count of
/// ticks — the note lengths below are spoken in ticks, a
/// hundredth of a second each, the same coin the mouse's waits
/// are paid in. The resting is `hlt`, so the machine sleeps
/// between heartbeats rather than spinning, and the interrupts —
/// the heartbeat itself, the keyboard, the mouse — live
/// throughout: time passes honestly while a note sounds.
func waitTicks(_ count: UInt64) {
    let deadline = ticks &+ count
    while ticks < deadline {
        cardnullHltOnce()
    }
}

/// The phrase's shape: eight notes — the Doxology's first line.
let soundNoteCount = 8

/// The breath between two notes, in ticks: four hundredths of a
/// second of silence, so the notes stand as notes and not as one
/// sliding tone. Between the print and the playing it is also the
/// reader's beat.
let soundGapTicks: UInt64 = 4

/// One note of the phrase, by its place in it: its name as the
/// screen speaks it, its frequency in hertz (the equal-tempered
/// reckoning, A4 at 440 — the divisor's own division of the PIT's
/// clock lands within a fraction of a percent of each), and its
/// length in ticks. The tune is Old Hundredth in G major: three
/// rising steps to the fifth, the fifth again, and the walk back
/// down — the last note held twice as long, as a first line ends.
func soundNote(_ index: Int)
    -> (name: StaticString, frequency: UInt64, length: UInt64) {
    switch index {
    case 0: return ("G4", 392, 35)
    case 1: return ("B4", 494, 35)
    case 2: return ("D5", 587, 35)
    case 3: return ("D5", 587, 35)
    case 4: return ("C5", 523, 35)
    case 5: return ("B4", 494, 35)
    case 6: return ("A4", 440, 35)
    default: return ("B4", 494, 70)
    }
}

/// sound's spoken frame: the naming of the tune before it plays,
/// the plain word that the shell waits, and the closing word that
/// the speaker rests — spoken only after the gate stands shut.
let soundTitleLine: StaticString =
    "The Doxology's opening - Old Hundredth, in G major:"
let soundWaitLine: StaticString =
    "  (the shell waits while the phrase plays)"
let soundRestLine: StaticString =
    "The speaker is silent again."
let soundHzWord: StaticString = " Hz, "
let soundDashWord: StaticString = " - "
let soundSecondWord: StaticString = " s"

/// Writes a note's length the way a person reads time: the ticks
/// are hundredths of a second exactly, so 35 is "0.35 s" and the
/// held last note is "0.70 s" — the whole, a point, and the two
/// hundredths, with the leading zero the fraction owes.
func writeSoundLength(_ length: UInt64) {
    writeNumber(length / 100)
    writeChar(0x2E)   // .
    let fraction = length % 100
    if fraction < 10 { writeChar(0x30) }   // 0
    writeNumber(fraction)
    writeStatic(soundSecondWord)
}

/// sound's work: speak the tune's name, then play the phrase note
/// by note — each note printed before it sounds (name, frequency,
/// length), the gate opened for exactly its length, closed, and a
/// breath of silence before the next. The closing word is spoken
/// only once the gate stands shut for good: the function's every
/// road ends at the final speakerOff, so the speaker is never
/// left singing by anything this function does.
func runSound() {
    // Milestone 27's door, tried first: if the high-definition
    // sound chip answered — found, woken, walked, and given the
    // phrase — it sings, and its own account below (in the
    // milestone-27 section) has already spoken for this command.
    // If it did not, one honest line says so, and the speaker
    // sings exactly as it has since milestone 17.
    if hdaEnsure() {
        hdaPlayPhrase()
        return
    }
    writeLine(hdaAbsentLine)
    writeLine(soundTitleLine)
    writeLine(soundWaitLine)
    var index = 0
    while index < soundNoteCount {
        let note = soundNote(index)
        writeChar(0x20)
        writeChar(0x20)
        writeStatic(note.name)
        writeStatic(soundDashWord)
        writeNumber(note.frequency)
        writeStatic(soundHzWord)
        writeSoundLength(note.length)
        writeNewline()
        speakerOn(note.frequency)
        waitTicks(note.length)
        speakerOff()
        if index + 1 < soundNoteCount {
            waitTicks(soundGapTicks)
        }
        index += 1
    }
    speakerOff()
    writeLine(soundRestLine)
}

// ---------------------------------------------------------------------------
//
// Milestone 27: a voice with range — the Intel HDA sound chip.
//
// Milestone 17 gave the machine the PC speaker: one square wave,
// two pitches of dignity, no more. The test machines have carried
// a real sound chip all along — an Intel High Definition Audio
// controller (QEMU's and UTM's intel-hda) with a codec behind it —
// and it has sat silent for twenty-six milestones because nobody
// spoke its language. This stone speaks it.
//
// The shape of the thing, honestly told:
//   - The controller is found on the PCI bus by its class alone —
//     multimedia (0x04), audio device (0x03) — any maker's chip,
//     the way the disc and network drivers find theirs by class
//     and kind. Its first base register names its register ground
//     (a 64-bit bar read whole, as such bars honestly are), its
//     memory and bus-master doors are opened in its command word,
//     and its register pages are mapped as the other drivers map
//     theirs. The raising is lazy — at the first `sound`, never at
//     boot — and its verdict is cached for the session, success
//     and failure alike, so a machine without the chip pays the
//     asking once and sings on the speaker thereafter.
//   - The controller is reset by its own rite (the CRST word
//     lowered until it reads lowered, raised until it reads
//     raised), and the codecs announce themselves in the wake
//     word STATESTS. No wake word, no codec: the driver says so
//     and stops — a controller with no one behind it is not a
//     voice.
//   - Two rings carry the conversation, in frames of the
//     allocator's, each proven below 4 GiB as the network rings
//     were: the CORB, our one-way street of commands (verbs) to
//     the codec, and the RIRB, the codec's answers. Interrupts
//     stay off; the kernel polls the RIRB's write pointer against
//     its own kept reading, with a deadline on the heartbeat, so
//     a codec that never answers costs fifty ticks, never the
//     shell.
//   - The codec is walked, never assumed: from its root, its
//     vendor and name; through its function groups to the audio
//     one; through that group's widgets to the first converter
//     (DAC) and to a pin that can sound — preferring the pin
//     whose own connection list names the converter, so the path
//     the kernel builds is the path the codec itself declares.
//     Node numbers are whatever the walk finds; none is written
//     down here from any other machine's testimony.
//   - The path is then configured verb by verb: power raised to
//     D0, the converter taught the phrase's format and given
//     stream 1, the pin aimed at the converter where its list
//     gives a choice, both amplifiers unmuted at an honest gain,
//     the pin's out gate opened, its EAPD let live.
//   - The phrase itself — the same Doxology opening the speaker
//     sings, the same lengths on the same heartbeat reckoning —
//     is rendered once, at the raising, into fresh frames: 48,000
//     samples a second, sixteen bits, two channels saying the
//     same thing, a sine reckoned from a quarter-wave table, each
//     note faded in and out over its first and last ninety-six
//     samples so the joins do not click. A buffer descriptor list
//     names the frames to the chip's first output stream, and the
//     stream runs: the kernel watches its position word move —
//     the proof of DMA life — for the phrase's length and a
//     margin, notes any fault the stream confesses, then stops
//     the stream and resets it clean.
//   - And the honesty of the stone: if any of it fails — no chip,
//     no codec, no converter, no pin, a stream that will not move
//     — `sound` says what happened in the Terminal and the speaker
//     sings, exactly as it always has. The desktop gains nothing;
//     diagnostics live in the Terminal, as this house keeps them.
// ---------------------------------------------------------------------------

/// The controller's register ground, by offset from its base —
/// only the registers this driver honestly speaks are named.
/// The controller-wide words first.
let hdaRegGCAP: UInt64 = 0x00       // capabilities: stream counts
let hdaRegGCTL: UInt64 = 0x08       // global control: CRST, bit 0
let hdaRegSTATESTS: UInt64 = 0x0E   // the codecs' wake word

/// The command ring (CORB) registers: the kernel's verbs go out
/// here, one 32-bit word apiece, the controller reading behind
/// the write pointer the kernel advances.
let hdaRegCORBLBASE: UInt64 = 0x40
let hdaRegCORBUBASE: UInt64 = 0x44
let hdaRegCORBWP: UInt64 = 0x48     // write pointer (ours)
let hdaRegCORBRP: UInt64 = 0x4A     // read pointer (the chip's)
let hdaRegCORBCTL: UInt64 = 0x4C    // run = bit 1
let hdaRegCORBSIZE: UInt64 = 0x4E   // size select + capability

/// The response ring (RIRB) registers: the codec's answers come
/// home here, eight bytes apiece — the answer below, its codec's
/// name above — the chip writing behind its write pointer.
let hdaRegRIRBLBASE: UInt64 = 0x50
let hdaRegRIRBUBASE: UInt64 = 0x54
let hdaRegRIRBWP: UInt64 = 0x58     // write pointer (the chip's)
let hdaRegRINTCNT: UInt64 = 0x5A
let hdaRegRIRBCTL: UInt64 = 0x5C    // run = bit 1
let hdaRegRIRBSIZE: UInt64 = 0x5E

/// One stream descriptor's shape: its fields' offsets from the
/// descriptor's own base, the base itself reckoned from the
/// controller's stream counts at the raising — the input streams
/// stand first, so the first output stream stands at
/// 0x80 + ISS * 0x20, and no number here presumes a machine.
let hdaSdCTL: UInt64 = 0x00         // byte 0: SRST + RUN; byte 2: tag
let hdaSdSTS: UInt64 = 0x03         // fault latches (write 1 clears)
let hdaSdLPIB: UInt64 = 0x04        // the stream's position word
let hdaSdCBL: UInt64 = 0x08         // the phrase's whole byte count
let hdaSdLVI: UInt64 = 0x0C         // the last valid BDL entry
let hdaSdFMT: UInt64 = 0x12         // the stream's format word
let hdaSdBDPL: UInt64 = 0x18        // the descriptor list, low
let hdaSdBDPU: UInt64 = 0x1C        // the descriptor list, high

/// The register span this driver maps of the controller's
/// ground: its full honest reach, four pages.
let hdaRegisterSpan: UInt64 = 0x4000

/// The phrase's rendered shape: the sample rate the format word
/// promises, the sample count the Doxology's lengths reckon to
/// (seven notes of 35 ticks and one of 70, with seven breaths
/// of 4 ticks between the eight notes: 343 ticks of
/// music at 480 samples a tick), and the byte count and frame
/// count those samples fill, two channels of two bytes each.
let hdaSamplesPerTick: UInt64 = 480
let hdaTotalSamples = 164_640
let hdaTotalBytes = 658_560
let hdaPcmFrameCount = 161

/// The stream the phrase rides: tag 1, the first a raised codec
/// can be given, spoken to the converter and the stream alike.
let hdaStreamTag: UInt32 = 1

/// The format word both the converter and the stream are taught:
/// 48 kHz base rate (the rate fields all zero: base 48 kHz, times
/// one, divided by one), sixteen bits (the bits field, bits 6:4,
/// at 1), two channels (the channel field, bits 3:0, at 1) —
/// 0x0011, in the codec's own spelling of those facts.
let hdaFormatWord: UInt32 = 0x0011

/// The raising's verdict, cached for the session: 0 untried,
/// 1 ready, 2 absent — a repeat `sound` never re-asks a bus that
/// has already answered, one way or the other.
var hdaState = 0

/// The found controller's ground and its own name, kept for the
/// report: the PCI vendor and device numbers, read off the bus,
/// never written down from another machine's testimony.
var hdaBase: UInt64 = 0
var hdaVendor: UInt32 = 0
var hdaDeviceId: UInt32 = 0

/// The controller's stream counts, read from its capability
/// word at the reset, and the first output stream's base
/// reckoned from them.
var hdaInputStreams = 0
var hdaOutputStreams = 0
var hdaSdBase: UInt64 = 0

/// The codec the walk found: its address on the controller's
/// link (the wake word's lowest set bit), its vendor and device
/// from its root's own mouth, and the path the walk chose — the
/// audio function group, the first converter, and the pin that
/// sounds it, with the converter's place in the pin's list where
/// the pin gave a choice.
var hdaCodecAddr: UInt32 = 0
var hdaCodecVendor: UInt32 = 0
var hdaCodecDevice: UInt32 = 0
var hdaAfgNode: UInt32 = 0
var hdaDacNode: UInt32 = 0
var hdaPinNode: UInt32 = 0
var hdaPinSelectIndex = 0
var hdaPinSelectNeeded = false
var hdaWidgetCount: UInt32 = 0

/// The rings' and the phrase's frames, taken from the allocator
/// at the raising and kept for the kernel's life — frames are
/// never freed in this kernel, and the phrase never changes, so
/// what the raising builds, every later `sound` replays. The
/// keeping frame's first words are the phrase frames' addresses,
/// one frame of rendered sound apiece.
var hdaCorbFrame: UInt64 = 0
var hdaRirbFrame: UInt64 = 0
var hdaBdlFrame: UInt64 = 0
var hdaKeepingFrame: UInt64 = 0

/// The rings' sizes as the controller's capability words chose
/// them, and the kernel's own pointers into them: the CORB's
/// next writing place is reckoned from hdaCorbWP, the RIRB's
/// last consumed answer is hdaRirbRP — both kept in software
/// because the registers' own words are the other side's to move.
var hdaCorbEntries = 0
var hdaRirbEntries = 0
var hdaCorbWP = 0
var hdaRirbRP = 0

/// The last playing's testimony: whether the stream's position
/// word ever moved (the proof the DMA engine lived), and whether
/// the stream confessed a fault while it sang.
var hdaStreamMoved = false
var hdaStreamError = false

/// One register of the controller, through the milestone-8
/// hands the chip's sizes honestly need — the driver speaks to
/// its ground at the width each register is.
@inline(__always)
func hdaRead32(_ offset: UInt64) -> UInt32 {
    mmioRead32(hdaBase + offset)
}

@inline(__always)
func hdaWrite32(_ offset: UInt64, _ value: UInt32) {
    mmioWrite32(hdaBase + offset, value)
}

@inline(__always)
func hdaRead16(_ offset: UInt64) -> UInt16 {
    mmioRead16(hdaBase + offset)
}

@inline(__always)
func hdaWrite16(_ offset: UInt64, _ value: UInt16) {
    mmioWrite16(hdaBase + offset, value)
}

@inline(__always)
func hdaRead8(_ offset: UInt64) -> UInt8 {
    mmioRead8(hdaBase + offset)
}

@inline(__always)
func hdaWrite8(_ offset: UInt64, _ value: UInt8) {
    mmioWrite8(hdaBase + offset, value)
}

/// Finds the controller: walks bus 0 as the other drivers walk
/// it — every function of every device — asking for the sound
/// class alone: multimedia (0x04) over audio device (0x03), any
/// maker's chip. The first that answers with a memory base is
/// taken: its bar read honestly (a 64-bit bar is two words, and
/// the second is read rather than presumed), its memory and
/// bus-master doors opened in its command word.
func hdaFindController() -> Bool {
    var device: UInt32 = 0
    while device < 32 {
        var function: UInt32 = 0
        while function < 8 {
            let id = pciConfigRead32(device, function, 0)
            if id & 0xFFFF != 0xFFFF {
                let classes = pciConfigRead32(device, function, 0x08)
                if classes >> 24 == 0x04
                    && (classes >> 16) & 0xFF == 0x03 {
                    let bar = pciConfigRead32(device, function, 0x10)
                    var base: UInt64 = 0
                    if (bar >> 1) & 0x3 == 2 {
                        let high = pciConfigRead32(device, function,
                                                   0x14)
                        base = UInt64(bar & 0xFFFFFFF0)
                            | (UInt64(high) << 32)
                    } else {
                        base = UInt64(bar & 0xFFFFFFF0)
                    }
                    if base != 0 {
                        hdaVendor = id & 0xFFFF
                        hdaDeviceId = id >> 16
                        hdaBase = base
                        let commandWord = pciConfigRead32(
                            device, function, 0x04)
                        pciConfigWrite32(device, function, 0x04,
                                         commandWord | 0x06)
                        return true
                    }
                }
            }
            function += 1
        }
        device += 1
    }
    return false
}

/// Maps the controller's register pages into the kernel's
/// tables, as the network driver maps its card's — and on the
/// floor's borrowed map there is nothing to map, the wide
/// identity already covering the ground.
func hdaMapRegisters() -> Bool {
    if !pagingReady { return true }
    let flags = ptePresent | pteWritable | pteNoExecute
    if !mapRange(hdaBase, hdaRegisterSpan, flags) { return false }
    var page: UInt64 = 0
    while page < hdaRegisterSpan {
        cardnullInvlpg(hdaBase + page)
        page += pageSize
    }
    return true
}

/// Resets the controller by its own rite and learns its shape:
/// the capability word's stream counts first (the first output
/// stream's home is reckoned from them, not presumed), then the
/// reset word lowered until the chip agrees it is lowered and
/// raised until it agrees it is raised — each wait bounded on
/// the heartbeat, a chip that will not answer its own reset
/// being no chip to sing through. Then the wake word: a codec
/// that lives reports itself there within a hundred ticks, and
/// silence there is spoken as what it is — a controller with no
/// one behind it.
func hdaResetController() -> Bool {
    let gcap = hdaRead32(hdaRegGCAP)
    hdaInputStreams = Int((gcap >> 8) & 0xF)
    hdaOutputStreams = Int((gcap >> 12) & 0xF)
    if hdaOutputStreams < 1 { return false }
    hdaSdBase = 0x80 + UInt64(hdaInputStreams) * 0x20
    hdaWrite16(hdaRegGCTL, hdaRead16(hdaRegGCTL) & 0xFFFE)
    var waited: UInt64 = 0
    while hdaRead16(hdaRegGCTL) & 1 != 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    hdaWrite16(hdaRegGCTL, hdaRead16(hdaRegGCTL) | 1)
    waited = 0
    while hdaRead16(hdaRegGCTL) & 1 == 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    waited = 0
    while hdaRead16(hdaRegSTATESTS) == 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    return true
}

/// A ring's size, chosen from its capability byte: 256 entries
/// where the chip allows them, else 16, else 2 — the select word
/// the size register is then taught (0b10, 0b01, 0b00 in that
/// same order).
func hdaRingEntries(_ capability: UInt8) -> Int {
    if capability & 0x40 != 0 { return 256 }
    if capability & 0x20 != 0 { return 16 }
    return 2
}

func hdaRingSelect(_ entries: Int) -> UInt8 {
    if entries == 256 { return 0x02 }
    if entries == 16 { return 0x01 }
    return 0x00
}

/// Lays the two rings in fresh frames and sets them running,
/// interrupts silenced throughout — the kernel polls. The CORB
/// first: stopped, its base spoken, its size chosen from its
/// capability, its read pointer reset by the two-stroke
/// handshake the datasheet prescribes (the reset bit raised
/// until the chip holds it raised, then lowered until it reads
/// lowered), its write pointer at the start, then run. The RIRB
/// the same, its write pointer reset by its own bit and the
/// kernel's kept reading taken from the register's own mouth
/// afterward, so the first answer is judged against the truth
/// and not against a hope. Both frames are proven below 4 GiB
/// before the chip hears of them, and the RIRB is laid with a
/// pattern no codec writes — all ones — so an entry the chip
/// has not touched can never be mistaken for an answer.
func hdaSetupRings() -> Bool {
    hdaCorbFrame = allocFrame()
    hdaRirbFrame = allocFrame()
    if hdaCorbFrame == 0 || hdaRirbFrame == 0 { return false }
    let reach: UInt64 = 0x1_0000_0000
    if hdaCorbFrame >= reach || hdaRirbFrame >= reach {
        return false
    }
    let corbWords = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(hdaCorbFrame))!
    var index = 0
    while index < 1024 {
        corbWords[index] = 0
        index += 1
    }
    let rirbWords = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(hdaRirbFrame))!
    index = 0
    while index < 512 {
        rirbWords[index] = 0xFFFF_FFFF_FFFF_FFFF
        index += 1
    }
    hdaWrite8(hdaRegCORBCTL, 0)
    hdaWrite32(hdaRegCORBLBASE,
               UInt32(hdaCorbFrame & 0xFFFFFFFF))
    hdaWrite32(hdaRegCORBUBASE, UInt32(hdaCorbFrame >> 32))
    hdaCorbEntries = hdaRingEntries(hdaRead8(hdaRegCORBSIZE))
    hdaWrite8(hdaRegCORBSIZE, hdaRingSelect(hdaCorbEntries))
    hdaWrite16(hdaRegCORBRP, 0x8000)
    var waited: UInt64 = 0
    while hdaRead16(hdaRegCORBRP) & 0x8000 == 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    hdaWrite16(hdaRegCORBRP, 0)
    waited = 0
    while hdaRead16(hdaRegCORBRP) & 0x8000 != 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    hdaWrite16(hdaRegCORBWP, 0)
    hdaCorbWP = 0
    hdaWrite8(hdaRegCORBCTL, 0x02)
    hdaWrite8(hdaRegRIRBCTL, 0)
    hdaWrite32(hdaRegRIRBLBASE,
               UInt32(hdaRirbFrame & 0xFFFFFFFF))
    hdaWrite32(hdaRegRIRBUBASE, UInt32(hdaRirbFrame >> 32))
    hdaRirbEntries = hdaRingEntries(hdaRead8(hdaRegRIRBSIZE))
    hdaWrite8(hdaRegRIRBSIZE, hdaRingSelect(hdaRirbEntries))
    hdaWrite16(hdaRegRIRBWP, 0x8000)
    hdaWrite16(hdaRegRIRBWP, 0)
    // The response threshold stands at the ring's reach, not at
    // zero: the threshold is an interrupt-coalescing number on
    // the datasheet's page — and the interrupts here stay off,
    // the kernel polling instead — but the emulator on the bench
    // also reads it as the count of answers it will carry before
    // it pauses the command ring, and at zero it would carry
    // none at all. At 255 the whole raising's conversation —
    // some dozens of verbs — passes far beneath it.
    hdaWrite16(hdaRegRINTCNT, 0xFF)
    hdaWrite8(hdaRegRIRBCTL, 0x02)
    hdaRirbRP = Int(hdaRead16(hdaRegRIRBWP))
        & (hdaRirbEntries - 1)
    return true
}

/// Sends one verb word down the CORB and waits for its answer
/// on the RIRB: the word is laid at the write pointer's next
/// place, the pointer advanced, and the RIRB's write pointer
/// watched against the kernel's kept reading for fifty ticks.
/// The answer is the newest entry's low word; which physical
/// slot is newest is judged by the entry's own heading — its
/// high word names the codec that answered — because a ring's
/// reset leaves its pointer's exact convention to the chip, and
/// the entry that names our codec is the answer either way.
/// A timeout is a plain false: the shell is never hung on a
/// codec's silence.
var hdaDbgChipPtr = 0
var hdaDbgRirb0: UInt64 = 0
var hdaDbgRirb1: UInt64 = 0
var hdaDbgCorbRP = 0
var hdaDbgCtl: UInt32 = 0

func hdaSendVerb(_ entry: UInt32) -> (ok: Bool, response: UInt32) {
    let corb = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(hdaCorbFrame))!
    let next = (hdaCorbWP + 1) & (hdaCorbEntries - 1)
    corb[next] = entry
    hdaCorbWP = next
    hdaWrite16(hdaRegCORBWP, UInt16(next))
    let rirbEarly = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(hdaRirbFrame))!
    var waited: UInt64 = 0
    var chipPointer = hdaRirbRP
    while true {
        chipPointer = Int(hdaRead16(hdaRegRIRBWP))
            & (hdaRirbEntries - 1)
        if chipPointer != hdaRirbRP { break }
        if waited >= 50 {
            hdaDbgChipPtr = chipPointer
            hdaDbgRirb0 = rirbEarly[0]
            hdaDbgRirb1 = rirbEarly[1]
            hdaDbgCorbRP = Int(hdaRead16(hdaRegCORBRP))
                & (hdaCorbEntries - 1)
            hdaDbgCtl = UInt32(hdaRead8(hdaRegCORBCTL))
                | (UInt32(hdaRead8(hdaRegRIRBCTL)) << 8)
                | (UInt32(hdaRead16(hdaRegSTATESTS)) << 16)
            return (false, 0)
        }
        waitTicks(1)
        waited += 1
    }
    let rirb = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(hdaRirbFrame))!
    hdaDbgChipPtr = chipPointer
    hdaDbgRirb0 = rirb[0]
    hdaDbgRirb1 = rirb[1]
    let firstIndex = (hdaRirbRP + 1) & (hdaRirbEntries - 1)
    var answer = rirb[firstIndex]
    if UInt32((answer >> 32) & 0xF) != hdaCodecAddr {
        let other = rirb[hdaRirbRP]
        if UInt32((other >> 32) & 0xF) == hdaCodecAddr {
            answer = other
        }
    }
    hdaRirbRP = chipPointer
    return (true, UInt32(answer & 0xFFFFFFFF))
}

/// One verb with an eight-bit payload, in the codec's spelling:
/// the codec's address, the node's name, the verb, the payload.
func hdaVerb(_ node: UInt32, _ verb: UInt32,
             _ payload: UInt32) -> (ok: Bool, response: UInt32) {
    let entry = (hdaCodecAddr << 28) | (node << 20)
        | (verb << 8) | (payload & 0xFF)
    return hdaSendVerb(entry)
}

/// One verb with a sixteen-bit payload — the converter's format
/// and the amplifiers' gain are the two such verbs, and their
/// verb numbers are four bits wide where the others are twelve.
func hdaVerb16(_ node: UInt32, _ verb: UInt32,
               _ payload: UInt32) -> (ok: Bool, response: UInt32) {
    let entry = (hdaCodecAddr << 28) | (node << 20)
        | (verb << 16) | (payload & 0xFFFF)
    return hdaSendVerb(entry)
}

/// Asks one node for one of its parameters — the walk's whole
/// vocabulary: identity, shape, kind, and capability are all
/// parameters, asked the same way.
func hdaParam(_ node: UInt32,
              _ parameter: UInt32) -> (ok: Bool, response: UInt32) {
    return hdaVerb(node, 0xF00, parameter)
}

/// Walks the codec and chooses the singing path. The codec is
/// the wake word's lowest set bit; its root names its maker;
/// its function groups are asked their kind until the audio
/// group answers; that group's widgets are asked theirs. The
/// first converter (type 0) is kept. Among the pins (type 4)
/// that can sound (pin capability bit 4), the chosen one is the
/// first whose connection list names the converter — its place
/// in the list kept for the aiming verb — with the first merely
/// capable pin kept as the honest fallback: a path one hop long,
/// declared by the codec itself, or no path at all. Nothing is
/// presumed: what the walk cannot find, the raising reports by
/// failing, and the counts it met stand in the driver's books.
func hdaWalkCodec() -> Bool {
    let wake = hdaRead16(hdaRegSTATESTS)
    var bit: UInt32 = 0
    var found = false
    while bit < 15 {
        if wake & UInt16(1 << Int(bit)) != 0 {
            hdaCodecAddr = bit
            found = true
            break
        }
        bit += 1
    }
    if !found { return false }
    let identity = hdaParam(0, 0x00)
    if !identity.ok { return false }
    hdaCodecVendor = identity.response >> 16
    hdaCodecDevice = identity.response & 0xFFFF
    let groups = hdaParam(0, 0x04)
    if !groups.ok { return false }
    let groupStart = (groups.response >> 16) & 0xFF
    let groupCount = groups.response & 0xFF
    var afgFound = false
    var group: UInt32 = 0
    while group < groupCount {
        let kind = hdaParam(groupStart + group, 0x05)
        if kind.ok && kind.response & 0xFF == 1 {
            hdaAfgNode = groupStart + group
            afgFound = true
            break
        }
        group += 1
    }
    if !afgFound { return false }
    let widgets = hdaParam(hdaAfgNode, 0x04)
    if !widgets.ok { return false }
    let widgetStart = (widgets.response >> 16) & 0xFF
    hdaWidgetCount = widgets.response & 0xFF
    var dacFound = false
    var index: UInt32 = 0
    while index < hdaWidgetCount {
        let caps = hdaParam(widgetStart + index, 0x09)
        if caps.ok && (caps.response >> 20) & 0xF == 0 {
            hdaDacNode = widgetStart + index
            dacFound = true
            break
        }
        index += 1
    }
    if !dacFound { return false }
    var fallbackPin: UInt32 = 0
    var fallbackFound = false
    var pinFound = false
    index = 0
    while index < hdaWidgetCount && !pinFound {
        let node = widgetStart + index
        let caps = hdaParam(node, 0x09)
        if caps.ok && (caps.response >> 20) & 0xF == 4 {
            let pinCaps = hdaParam(node, 0x0C)
            if pinCaps.ok && pinCaps.response & 0x10 != 0 {
                if !fallbackFound {
                    fallbackPin = node
                    fallbackFound = true
                }
                let listHead = hdaParam(node, 0x0E)
                if listHead.ok {
                    let length = Int(listHead.response & 0x7F)
                    let longForm = listHead.response & 0x80 != 0
                    let step = longForm ? 2 : 4
                    var entryIndex = 0
                    while entryIndex < length {
                        let entry = hdaVerb(node, 0xF02,
                                            UInt32(entryIndex))
                        if !entry.ok { break }
                        var slot = 0
                        while slot < step
                            && entryIndex + slot < length {
                            let member: UInt32
                            if longForm {
                                member = (entry.response
                                    >> UInt32(slot * 16)) & 0xFFFF
                            } else {
                                member = (entry.response
                                    >> UInt32(slot * 8)) & 0xFF
                            }
                            if member == hdaDacNode {
                                hdaPinNode = node
                                hdaPinSelectIndex = entryIndex + slot
                                hdaPinSelectNeeded = length > 1
                                pinFound = true
                            }
                            slot += 1
                        }
                        entryIndex += step
                    }
                }
            }
        }
        index += 1
    }
    if !pinFound {
        if !fallbackFound { return false }
        hdaPinNode = fallbackPin
        hdaPinSelectNeeded = false
    }
    return true
}

/// Configures the chosen path, verb by verb, in the order the
/// codec's own book prescribes: the function group, the
/// converter, and the pin woken to full power (D0); the
/// converter taught the phrase's format and given stream 1 at
/// its first channel; the pin aimed at the converter where its
/// list gave a choice; both amplifiers set — output, both
/// sides, unmuted, at gain 0x4A (the pin's as a matter of law,
/// the converter's too, its own capability permitting the
/// question and silence there costing nothing); the pin's out
/// gate opened; and its EAPD let live, a verb codecs without
/// one simply ignore. Any refusal along the way fails the
/// raising whole — a half-built path is not sung through.
func hdaConfigure() -> Bool {
    if !hdaVerb(hdaAfgNode, 0x705, 0).ok { return false }
    if !hdaVerb(hdaDacNode, 0x705, 0).ok { return false }
    if !hdaVerb(hdaPinNode, 0x705, 0).ok { return false }
    if !hdaVerb16(hdaDacNode, 0x2, hdaFormatWord).ok {
        return false
    }
    if !hdaVerb(hdaDacNode, 0x706, (hdaStreamTag << 4)).ok {
        return false
    }
    if hdaPinSelectNeeded {
        if !hdaVerb(hdaPinNode, 0x701,
                    UInt32(hdaPinSelectIndex)).ok { return false }
    }
    let dacAmp = hdaParam(hdaDacNode, 0x12)
    if dacAmp.ok && dacAmp.response != 0 {
        _ = hdaVerb16(hdaDacNode, 0x3, 0xB04A)
    }
    if !hdaVerb16(hdaPinNode, 0x3, 0xB04A).ok { return false }
    if !hdaVerb(hdaPinNode, 0x707, 0x40).ok { return false }
    _ = hdaVerb(hdaPinNode, 0x70C, 0x02)
    return true
}

/// One quarter of the sine the phrase is sung with, sixty-five
/// points from silence to the peak, reckoned once by hand from
/// the true sine at an amplitude of 12,000 — honest numbers in
/// the source, as the speaker's note table is, so the rendering
/// below is arithmetic and nothing else. The full wave is this
/// quarter stood four ways, as hdaSine lays it.
func hdaQuarterSine(_ point: Int) -> Int {
    switch point {
    case 0: return 0
    case 1: return 294
    case 2: return 589
    case 3: return 883
    case 4: return 1176
    case 5: return 1469
    case 6: return 1761
    case 7: return 2052
    case 8: return 2341
    case 9: return 2629
    case 10: return 2916
    case 11: return 3201
    case 12: return 3483
    case 13: return 3764
    case 14: return 4043
    case 15: return 4319
    case 16: return 4592
    case 17: return 4863
    case 18: return 5131
    case 19: return 5395
    case 20: return 5657
    case 21: return 5915
    case 22: return 6169
    case 23: return 6420
    case 24: return 6667
    case 25: return 6910
    case 26: return 7148
    case 27: return 7383
    case 28: return 7613
    case 29: return 7838
    case 30: return 8059
    case 31: return 8274
    case 32: return 8485
    case 33: return 8691
    case 34: return 8891
    case 35: return 9087
    case 36: return 9276
    case 37: return 9460
    case 38: return 9638
    case 39: return 9811
    case 40: return 9978
    case 41: return 10138
    case 42: return 10293
    case 43: return 10441
    case 44: return 10583
    case 45: return 10719
    case 46: return 10848
    case 47: return 10971
    case 48: return 11087
    case 49: return 11196
    case 50: return 11299
    case 51: return 11394
    case 52: return 11483
    case 53: return 11565
    case 54: return 11640
    case 55: return 11708
    case 56: return 11769
    case 57: return 11823
    case 58: return 11870
    case 59: return 11910
    case 60: return 11942
    case 61: return 11967
    case 62: return 11986
    case 63: return 11996
    default: return 12000
    }
}

/// The whole wave from the quarter: the second quarter falls
/// back down the same hill, the third and fourth are the first
/// two under the line. The index is the phase's top byte — a
/// 256-step circle the rendering walks by fixed-point steps.
func hdaSine(_ index: Int) -> Int {
    let quadrant = index >> 6
    let offset = index & 63
    switch quadrant {
    case 0: return hdaQuarterSine(offset)
    case 1: return hdaQuarterSine(64 - offset)
    case 2: return -hdaQuarterSine(offset)
    default: return -hdaQuarterSine(64 - offset)
    }
}

/// Lays one rendered sample — both channels, the same word —
/// at its place in the phrase's frames: its byte address
/// reckoned from the sample's number, its frame found in the
/// keeping, its four bytes written low first, as the chip
/// reads them.
func hdaPcmWrite(_ sample: Int, _ value: Int) {
    let byteOffset = sample * 4
    let keeping = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(hdaKeepingFrame))!
    let frame = keeping[byteOffset / 4096]
    let bytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(frame))!
    let within = byteOffset % 4096
    let word = UInt16(bitPattern: Int16(value))
    bytes[within] = UInt8(word & 0xFF)
    bytes[within + 1] = UInt8((word >> 8) & 0xFF)
    bytes[within + 2] = UInt8(word & 0xFF)
    bytes[within + 3] = UInt8((word >> 8) & 0xFF)
}

/// Builds the phrase, once, at the raising: the descriptor
/// list's frame and the keeping frame first, then one frame of
/// rendered sound per 4 KiB of phrase — every address proven
/// below 4 GiB as it is taken, every frame wiped to silence
/// before a note is laid in it, so the breaths between notes
/// are true silence by construction. Each note is rendered
/// with a fixed-point phase stepping the 256-point circle at
/// its own frequency, and faded over its first and last
/// ninety-six samples. The descriptor list then names every
/// frame in order — address, length, no interrupt: the stream
/// is polled, not interrupted, like everything this kernel
/// waits on.
func hdaBuildPhrase() -> Bool {
    hdaBdlFrame = allocFrame()
    hdaKeepingFrame = allocFrame()
    if hdaBdlFrame == 0 || hdaKeepingFrame == 0 { return false }
    let reach: UInt64 = 0x1_0000_0000
    if hdaBdlFrame >= reach || hdaKeepingFrame >= reach {
        return false
    }
    let keeping = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(hdaKeepingFrame))!
    var frameIndex = 0
    while frameIndex < hdaPcmFrameCount {
        let frame = allocFrame()
        if frame == 0 || frame >= reach { return false }
        keeping[frameIndex] = frame
        let bytes = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(frame))!
        var byte = 0
        while byte < 4096 {
            bytes[byte] = 0
            byte += 1
        }
        frameIndex += 1
    }
    var samplePos = 0
    var noteIndex = 0
    while noteIndex < soundNoteCount {
        let note = soundNote(noteIndex)
        let noteSamples = Int(note.length) * Int(hdaSamplesPerTick)
        let increment = UInt32((note.frequency << 32) / 48_000)
        var phase: UInt32 = 0
        var sample = 0
        while sample < noteSamples {
            let sine = hdaSine(Int(phase >> 24))
            phase &+= increment
            var fade = 96
            if sample < fade { fade = sample }
            let tail = noteSamples - 1 - sample
            if tail < fade { fade = tail }
            hdaPcmWrite(samplePos + sample, sine * fade / 96)
            sample += 1
        }
        samplePos += noteSamples
        if noteIndex + 1 < soundNoteCount {
            samplePos += Int(soundGapTicks) * Int(hdaSamplesPerTick)
        }
        noteIndex += 1
    }
    let bdl = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(hdaBdlFrame))!
    var word = 0
    while word < 1024 {
        bdl[word] = 0
        word += 1
    }
    frameIndex = 0
    while frameIndex < hdaPcmFrameCount {
        let address = keeping[frameIndex]
        var length = 4096
        let remaining = hdaTotalBytes - frameIndex * 4096
        if remaining < length { length = remaining }
        bdl[frameIndex * 4] = UInt32(address & 0xFFFFFFFF)
        bdl[frameIndex * 4 + 1] = UInt32(address >> 32)
        bdl[frameIndex * 4 + 2] = UInt32(length)
        bdl[frameIndex * 4 + 3] = 0
        frameIndex += 1
    }
    return true
}

/// The stream's reset dance, the datasheet's order: its run
/// bit lowered, its reset bit raised until the chip holds it
/// raised, then lowered until it reads lowered — each wait
/// bounded on the heartbeat. The stream stands clean afterward,
/// ready to be taught or to be left in peace.
func hdaStreamReset() -> Bool {
    hdaWrite8(hdaSdBase + hdaSdCTL,
              hdaRead8(hdaSdBase + hdaSdCTL) & 0xFD)
    hdaWrite8(hdaSdBase + hdaSdCTL,
              hdaRead8(hdaSdBase + hdaSdCTL) | 0x01)
    var waited: UInt64 = 0
    while hdaRead8(hdaSdBase + hdaSdCTL) & 1 == 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    hdaWrite8(hdaSdBase + hdaSdCTL,
              hdaRead8(hdaSdBase + hdaSdCTL) & 0xFE)
    waited = 0
    while hdaRead8(hdaSdBase + hdaSdCTL) & 1 != 0 {
        if waited >= 100 { return false }
        waitTicks(1)
        waited += 1
    }
    return true
}

/// Plays the built phrase on the first output stream: the
/// reset dance, the descriptor list spoken, the byte count,
/// the last entry, the format, stream 1 named in the control's
/// high byte, the fault latches cleared — then the run bit,
/// and the watching: the phrase's own tick count and two
/// more — a stream's descriptor list is a circle, so a longer
/// watch would let the phrase begin again before the stop;
/// two ticks of margin keep the overrun inside the first
/// note's own fade from silence — the position word checked
/// every tick for the proof that the DMA engine lives, the
/// fault latches checked for any confession. The stream is
/// stopped and reset clean whatever happened, and the
/// testimony stands in the driver's books for the report.
func hdaStreamPlay() -> Bool {
    if !hdaStreamReset() { return false }
    hdaWrite32(hdaSdBase + hdaSdBDPL,
               UInt32(hdaBdlFrame & 0xFFFFFFFF))
    hdaWrite32(hdaSdBase + hdaSdBDPU, UInt32(hdaBdlFrame >> 32))
    hdaWrite32(hdaSdBase + hdaSdCBL, UInt32(hdaTotalBytes))
    hdaWrite16(hdaSdBase + hdaSdLVI,
               UInt16(hdaPcmFrameCount - 1))
    hdaWrite16(hdaSdBase + hdaSdFMT, UInt16(hdaFormatWord))
    hdaWrite8(hdaSdBase + hdaSdCTL + 2,
              UInt8(hdaStreamTag << 4))
    hdaWrite8(hdaSdBase + hdaSdSTS, 0x1C)
    let startPosition = hdaRead32(hdaSdBase + hdaSdLPIB)
    var totalTicks: UInt64 = 0
    var noteIndex = 0
    while noteIndex < soundNoteCount {
        totalTicks += soundNote(noteIndex).length
        if noteIndex + 1 < soundNoteCount {
            totalTicks += soundGapTicks
        }
        noteIndex += 1
    }
    let startTick = ticks
    hdaStreamMoved = false
    hdaStreamError = false
    hdaWrite8(hdaSdBase + hdaSdCTL,
              hdaRead8(hdaSdBase + hdaSdCTL) | 0x02)
    while ticks < startTick + totalTicks + 2 {
        if hdaRead32(hdaSdBase + hdaSdLPIB) != startPosition {
            hdaStreamMoved = true
        }
        if hdaRead8(hdaSdBase + hdaSdSTS) & 0x1C != 0 {
            hdaStreamError = true
        }
        waitTicks(1)
    }
    if hdaRead32(hdaSdBase + hdaSdLPIB) != startPosition {
        hdaStreamMoved = true
    }
    hdaWrite8(hdaSdBase + hdaSdCTL,
              hdaRead8(hdaSdBase + hdaSdCTL) & 0xFD)
    _ = hdaStreamReset()
    return hdaStreamMoved
}

/// The raising itself, lazy and cached: find, map, reset,
/// rings, walk, configure, build — any step's failure is the
/// whole verdict, kept for the session, so the speaker's road
/// is taken at once on every later `sound` and the bus is not
/// re-asked questions it has answered.
var hdaStage = 0

func hdaEnsure() -> Bool {
    if hdaState == 1 { return true }
    if hdaState == 2 { return false }
    hdaStage = 1
    if !hdaFindController() { hdaState = 2; return false }
    hdaStage = 2
    if !hdaMapRegisters() { hdaState = 2; return false }
    hdaStage = 3
    if !hdaResetController() { hdaState = 2; return false }
    hdaStage = 4
    if !hdaSetupRings() { hdaState = 2; return false }
    hdaStage = 5
    if !hdaWalkCodec() { hdaState = 2; return false }
    hdaStage = 6
    if !hdaConfigure() { hdaState = 2; return false }
    hdaStage = 7
    if !hdaBuildPhrase() { hdaState = 2; return false }
    hdaStage = 8
    hdaState = 1
    return true
}

/// Writes a sixteen-bit number as four hexadecimal digits —
/// the controller's and codec's names are spoken so, the way
/// the world writes PCI numbers.
func hdaWriteHex16(_ value: UInt32) {
    writeHexByte(UInt8((value >> 8) & 0xFF))
    writeHexByte(UInt8(value & 0xFF))
}

/// sound's words when the chip sings: the probe's report, in
/// plain words with the numbers that belong in the Terminal.
let hdaChipLabel: StaticString = "Sound chip - controller "
let hdaCodecWord: StaticString = ", codec "
let hdaPathLabel: StaticString = "  Path: converter node "
let hdaPathMiddle: StaticString = " sings through pin node "
let hdaPeriodWord: StaticString = "."
let hdaColonWord: StaticString = ":"
let hdaRestLine: StaticString =
    "The sound chip is silent again."
let hdaStillLine: StaticString =
    "  (the chip's stream did not move; nothing was heard)"
let hdaFaultLine: StaticString =
    "  (the chip confessed a stream fault as it sang)"

/// sound's one honest line when the chip does not sing — spoken
/// by runSound itself before the speaker's road, and kept here
/// beside the rest of the stone's vocabulary.
let hdaAbsentLine: StaticString =
    "No high-definition sound chip answered; the speaker will sing."

/// The chip's half of `sound`: the probe's report spoken first
/// — the controller's and codec's names as the bus and the root
/// gave them, and the path the walk chose — then the tune's
/// name, each note printed as the speaker's road prints it,
/// the phrase played whole on the stream, the stream's own
/// testimony spoken plainly if it would not move or confessed
/// a fault, and the closing word only once the stream stands
/// stopped and reset.
func hdaPlayPhrase() {
    writeStatic(hdaChipLabel)
    hdaWriteHex16(hdaVendor)
    writeStatic(hdaColonWord)
    hdaWriteHex16(hdaDeviceId)
    writeStatic(hdaCodecWord)
    hdaWriteHex16(hdaCodecVendor)
    writeStatic(hdaColonWord)
    hdaWriteHex16(hdaCodecDevice)
    writeLine(hdaPeriodWord)
    writeStatic(hdaPathLabel)
    writeNumber(UInt64(hdaDacNode))
    writeStatic(hdaPathMiddle)
    writeNumber(UInt64(hdaPinNode))
    writeLine(hdaPeriodWord)
    writeLine(soundTitleLine)
    writeLine(soundWaitLine)
    var index = 0
    while index < soundNoteCount {
        let note = soundNote(index)
        writeChar(0x20)
        writeChar(0x20)
        writeStatic(note.name)
        writeStatic(soundDashWord)
        writeNumber(note.frequency)
        writeStatic(soundHzWord)
        writeSoundLength(note.length)
        writeNewline()
        index += 1
    }
    let moved = hdaStreamPlay()
    if !moved {
        writeLine(hdaStillLine)
    } else if hdaStreamError {
        writeLine(hdaFaultLine)
    }
    writeLine(hdaRestLine)
}



//
// Nineteen milestones the machine spoke to no one but the person at
// its own keyboard. This stone gives it a neighbour: an Intel e1000
// network card, the card the test machines carry (QEMU's and UTM's
// 82540EM), found on the PCI bus the way milestone 8 found the disc
// controller — by walking the bus and asking who is there.
//
// The driver is the smallest honest one. It finds the card, earns
// its trust the way the datasheet asks — interrupts silenced, a
// reset, the multicast table cleared, the card's own hardware
// address read out of it (never invented) and written into its
// first receive filter — and lays two descriptor rings in frames
// the allocator hands over: sixteen receive descriptors, each
// naming a buffer frame of its own, and a transmit ring of sixteen
// with one buffer. The card is a DMA engine: it reads and writes
// memory itself, so every address it is ever handed is proven
// below 4 GiB before the rings stand — the allocator's own cap is
// exactly that line, and the taking asserts it again, address by
// address, rather than trusting it silently. Nothing here takes an
// interrupt: the card's mask register silences it, and the kernel
// polls the rings on the heartbeat, the way this stone's
// conversations are short enough to allow. Interrupts are a later
// stone's refinement, stated as such.
//
// The conversation itself is one question and, when the wire is
// kind, one answer. The kernel builds a DHCP discover by hand —
// Ethernet, IPv4, UDP, BOOTP, its own address in the asking —
// lays it in the transmit ring, and listens on the receive ring
// against a five-second deadline reckoned on the heartbeat. A DHCP
// offer addressed to this card, carrying this asking's own
// transaction number, is the answer; anything else on the wire is
// counted and stepped over, and a frame too short or wrongly
// shaped to be an answer is never parsed past its proven length —
// the kernel survives its own wire. And the answer is reported,
// not taken: this stone asks and listens, and keeps no lease. The
// taking — a DHCP request, an address of our own, and everything
// an address would then allow — belongs to later stones, as do
// ARP, ping, and anything above this one exchange. Guests gain no
// network service: the wire is the kernel's own, this stone, and
// the packet fields never stand where a guest can reach them.
//
// Milestone 29 completes the errand this stone began. The offer
// is taken now — a DHCP request in the same conversation, the
// network's ack, and a lease kept in the kernel's own books —
// the card stays raised after the taking, and the kernel stands
// as a citizen of its network: it learns its gateway's hardware
// address by ARP, pings the gateway, asks the network's DNS
// server to resolve a real name, and — whenever it idles with
// the lease held — answers ARP requests and pings addressed to
// its own address. The new machinery stands below in this same
// section and voice; the guest wall is unchanged, and feathers
// gain no network service.
// ---------------------------------------------------------------------------

/// The card's registers, as offsets from its memory base — the
/// first base-address register's ground. Only the registers this
/// driver honestly speaks are named.
let netRegCTRL: UInt64 = 0x0000      // the card's control
let netRegSTATUS: UInt64 = 0x0008    // its standing: link, speed
let netRegICR: UInt64 = 0x00C0       // interrupt causes (read clears)
let netRegIMC: UInt64 = 0x00D8       // interrupt mask — set = silenced
let netRegRCTL: UInt64 = 0x0100      // receive control
let netRegTCTL: UInt64 = 0x0400      // transmit control
let netRegTIPG: UInt64 = 0x0410      // the gaps between packets
let netRegRDBAL: UInt64 = 0x2800     // receive ring base, low
let netRegRDBAH: UInt64 = 0x2804     // receive ring base, high
let netRegRDLEN: UInt64 = 0x2808     // receive ring length, bytes
let netRegRDH: UInt64 = 0x2810       // receive head (the card's)
let netRegRDT: UInt64 = 0x2818       // receive tail (ours to write)
let netRegTDBAL: UInt64 = 0x3800     // transmit ring base, low
let netRegTDBAH: UInt64 = 0x3804     // transmit ring base, high
let netRegTDLEN: UInt64 = 0x3808     // transmit ring length, bytes
let netRegTDH: UInt64 = 0x3810       // transmit head (the card's)
let netRegTDT: UInt64 = 0x3818       // transmit tail (ours to write)
let netRegMTA: UInt64 = 0x5200       // the multicast table, 128 words
let netRegRAL0: UInt64 = 0x5400      // receive address filter, low
let netRegRAH0: UInt64 = 0x5404      // receive address filter, high

/// The rings' shape: sixteen descriptors apiece, sixteen bytes to
/// a descriptor, and a 2048-byte field behind each receive
/// descriptor — the card's own standard buffer size, and room for
/// any frame an Ethernet honestly carries.
let netRingCount = 16
let netBufferBytes = 2048

/// The register pages this driver maps of the card's ground: the
/// registers it speaks live within the base's first 0x6000 bytes —
/// the multicast table and the address filters are the farthest it
/// reaches — so those are the pages it asks the tables for.
let netRegisterSpan: UInt64 = 0x6000

/// Did the walk of the bus find the card? Until it does, `net`
/// answers with the absence, plainly — the shape milestone 8's
/// disc commands have always worn.
var netCardFound = false

/// The found card's place on the bus and its own device number,
/// kept so the report names what was actually found.
var netDevice: UInt32 = 0
var netFunction: UInt32 = 0
var netDeviceID: UInt32 = 0

/// The card's register base: its first base-address register,
/// masked of its type bits. The registers stand in the PCI dark
/// the paging section leaves unmapped on purpose; the driver maps
/// its own door at the finding, as the disc driver does.
var netBase: UInt64 = 0

/// The driver's fields, taken from the frame allocator at the
/// first `net` and kept for the kernel's life: one frame for the
/// receive descriptors, one for the transmit descriptors, one
/// buffer the asking is built in, and one keeping frame whose
/// first sixteen words are the receive buffers' addresses — one
/// frame apiece behind them, twenty frames in all. Their
/// addresses are physical as well as virtual, the identity map's
/// gift, which is what a DMA engine must be told.
var netFramesReady = false
var netRxDescFrame: UInt64 = 0
var netTxDescFrame: UInt64 = 0
var netTxBufferFrame: UInt64 = 0
var netRxKeepingFrame: UInt64 = 0

/// The card's hardware address, packed: the first octet in the
/// lowest byte, the sixth in the fifth. Read out of the card's
/// own filter registers after its reset — the card loads them
/// from its permanent memory — so the address the shell speaks is
/// the card's own testimony, never a number made up here.
var netMacPacked: UInt64 = 0

/// The conversation's bookkeeping: this asking's transaction
/// number, the receive descriptor the listening has reached, and
/// — when an offer is recognised — the addresses it carried.
var netXid: UInt32 = 0
var netRxNext = 0
var netOfferAddress: UInt32 = 0
var netOfferServer: UInt32 = 0

/// Milestone 29's keeping. The card, once raised, stays raised:
/// netRaised stands from the first successful raising until the
/// kernel's life ends, and the transmit ring is walked by
/// netTxNext rather than rebuilt per sending — a ring that is
/// never reset between conversations must be honest about where
/// its next descriptor stands, the way the receive ring has
/// always been honest through netRxNext.
var netRaised = false
var netTxNext = 0

/// The conversation's guard: while a `net` conversation runs —
/// its listening, its buildings, its sendings — the citizenship
/// service below must never run, because netSend and the receive
/// ring's hands are not reentrant. runNet sets this at its door
/// and clears it on its way out; the idle loops' calls to
/// netService check it before anything else.
var netConversation = false

/// The lease's books, kept from the ack that granted them and
/// from nothing else: whether a lease is held at all, the
/// address that is ours, and the answers the ack carried — the
/// subnet mask, the gateway, the first DNS server, the server
/// that granted the lease (its option 54 when it carried one,
/// else its siaddr), the lease's length in seconds, and the
/// tick at which the lease was taken, against which its running
/// out is reckoned. A companion flag stands beside each answer
/// that may honestly be absent, so the report can say an answer
/// was not named instead of inventing one.
var netLeaseHeld = false
var netAddress: UInt32 = 0
var netMask: UInt32 = 0
var netMaskKnown = false
var netGateway: UInt32 = 0
var netGatewayKnown = false
var netDns: UInt32 = 0
var netDnsKnown = false
var netServer: UInt32 = 0
var netLeaseSeconds: UInt32 = 0
var netLeaseKnown = false
var netLeaseTakenTick: UInt64 = 0

/// The offer's server identifier, reckoned at the offer: its
/// option 54 when it carried one, else its siaddr — the name
/// the DHCP request must answer to.
var netOfferServerId: UInt32 = 0

/// The gateway's hardware address, learned by ARP and packed
/// the way the card's own address is packed, with the flag that
/// says whether the learning happened at all.
var netGatewayMacPacked: UInt64 = 0
var netGatewayMacKnown = false

/// The proof counters, standing since the lease was taken and
/// reset at each taking: the ARP requests we have answered, the
/// pings we have answered, the gateway pings of ours the network
/// answered, the DNS answers we have received, and — the ring's
/// own honesty — the frames the service counted and stepped
/// over because they were none of its business.
var netCountArpAnswers: UInt64 = 0
var netCountPingAnswers: UInt64 = 0
var netCountGatewayPings: UInt64 = 0
var netCountDnsAnswers: UInt64 = 0
var netCountSteppedOver: UInt64 = 0

/// One DHCP frame's testimony, filled by its judge below: the
/// message type it carried, the addresses standing in its fixed
/// fields, and each valued option with the flag that says
/// whether the frame carried it at all. Nothing here is read
/// until the judge has proven the frame's shape and length.
var netParsedType = 0
var netParsedYiaddr: UInt32 = 0
var netParsedSiaddr: UInt32 = 0
var netParsedMask: UInt32 = 0
var netParsedRouter: UInt32 = 0
var netParsedDns: UInt32 = 0
var netParsedServerId: UInt32 = 0
var netParsedLease: UInt32 = 0
var netParsedHasMask = false
var netParsedHasRouter = false
var netParsedHasDns = false
var netParsedHasServerId = false
var netParsedHasLease = false

/// The listening's tally of frames that were not the answer,
/// gathered across one whole `net` conversation and spoken in
/// the report the way milestone 20 spoke it.
var netAwaitOthers = 0

/// The originated exchanges' marks: the ping's identifier and
/// sequence and the tick it was sent at (its round trip is
/// reckoned against the answer's arrival), and the DNS asking's
/// identifier, the ephemeral port it was asked from, and the
/// address its answer carried.
var netPingId: UInt16 = 0
var netPingSeq: UInt16 = 0
var netPingSentTick: UInt64 = 0
var netDnsId: UInt16 = 0
var netDnsPort: UInt16 = 0
var netDnsResolved: UInt32 = 0

/// One register of the card, read or written through memory, at
/// the offset from its base: the same hands the disc driver uses,
/// which the compiler may not inline away.
@inline(__always)
func netRead32(_ offset: UInt64) -> UInt32 {
    mmioRead32(netBase + offset)
}

@inline(__always)
func netWrite32(_ offset: UInt64, _ value: UInt32) {
    mmioWrite32(netBase + offset, value)
}

/// One octet of the card's hardware address, by its place.
@inline(__always)
func netMacByte(_ index: Int) -> UInt8 {
    UInt8((netMacPacked >> UInt64(index * 8)) & 0xFF)
}

/// One word — eight bytes — of a descriptor: a descriptor is two
/// words, the first its buffer's address, the second its lengths,
/// orders, and standing, laid out by the card's own format.
@inline(__always)
func netDescWord(_ frame: UInt64, _ index: Int,
                 _ word: Int) -> UInt64 {
    let words = UnsafeMutablePointer<UInt64>(bitPattern: UInt(frame))!
    return words[index * 2 + word]
}

@inline(__always)
func netSetDescWord(_ frame: UInt64, _ index: Int, _ word: Int,
                    _ value: UInt64) {
    let words = UnsafeMutablePointer<UInt64>(bitPattern: UInt(frame))!
    words[index * 2 + word] = value
}

/// The address of the buffer behind the receive descriptor of
/// the given place: it stands in the keeping frame's word of that
/// place, where the taking laid it.
@inline(__always)
func netRxBufferAddress(_ index: Int) -> UInt64 {
    let keeping = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(netRxKeepingFrame))!
    return keeping[index]
}

/// The buffer behind the receive descriptor of the given place,
/// as the pointer the judging reads the arrived frame through.
@inline(__always)
func netRxBuffer(_ index: Int) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(netRxBufferAddress(index)))!
}

/// Finds the card: walks the bus the way milestone 8's raising
/// walks it — every function of every device on bus 0 — asking for
/// Intel's vendor mark (0x8086) wearing the network class and the
/// Ethernet subclass: the e1000 family honestly named by vendor
/// and class, with the device's own number kept for the report.
/// The first that answers with a memory base register is taken:
/// its memory door and its bus mastery are switched on in its
/// command word, and its registers' pages are mapped through the
/// kernel's tables as the disc controller's were.
func netFindCard() -> Bool {
    if netCardFound { return true }
    var device: UInt32 = 0
    while device < 32 {
        var function: UInt32 = 0
        while function < 8 {
            let id = pciConfigRead32(device, function, 0)
            if id & 0xFFFF == 0x8086 {
                let classes = pciConfigRead32(device, function, 0x08)
                if classes >> 24 == 0x02
                    && (classes >> 16) & 0xFF == 0x00 {
                    let bar = pciConfigRead32(device, function, 0x10)
                    if bar & 1 == 0 && bar & 0xFFFFFFF0 != 0 {
                        netDevice = device
                        netFunction = function
                        netDeviceID = id >> 16
                        netBase = UInt64(bar & 0xFFFFFFF0)
                        let commandWord = pciConfigRead32(
                            device, function, 0x04)
                        pciConfigWrite32(device, function, 0x04,
                                         commandWord | 0x06)
                        netCardFound = true
                        return true
                    }
                }
            }
            function += 1
        }
        device += 1
    }
    return false
}

/// Maps the card's register pages into the kernel's tables — the
/// pages the named registers stand on — as the disc driver maps
/// its controller's: present, writable, never executable, each
/// translation forgotten-and-retold so the processor looks again.
/// On the floor's borrowed map (paging not standing) there is
/// nothing to map: the floor's wide identity already covers the
/// ground, and the raising goes on, poorer but honest.
func netMapRegisters() -> Bool {
    if !pagingReady { return true }
    let flags = ptePresent | pteWritable | pteNoExecute
    if !mapRange(netBase, netRegisterSpan, flags) { return false }
    var page: UInt64 = 0
    while page < netRegisterSpan {
        cardnullInvlpg(netBase + page)
        page += pageSize
    }
    return true
}

/// Takes the driver's fields from the allocator, once, and proves
/// each one fit for the card's hands: a DMA engine of this era
/// names 32 bits of address, so every frame the card will ever be
/// told — rings and buffers alike — must stand below 4 GiB. The
/// allocator's own estate ends at that very line (its bitmap
/// speaks for exactly 4 GiB of frames), so the proof should never
/// fail; it is made anyway, address by address, because a card
/// told an address it cannot reach does not complain — it writes
/// somewhere else, and silence about that would be a lie.
func netTakeFrames() -> Bool {
    if netFramesReady { return true }
    netRxDescFrame = allocFrame()
    netTxDescFrame = allocFrame()
    netTxBufferFrame = allocFrame()
    netRxKeepingFrame = allocFrame()
    if netRxDescFrame == 0 || netTxDescFrame == 0
        || netTxBufferFrame == 0 || netRxKeepingFrame == 0 {
        return false
    }
    let keeping = UnsafeMutablePointer<UInt64>(
        bitPattern: UInt(netRxKeepingFrame))!
    var index = 0
    while index < netRingCount {
        keeping[index] = 0
        index += 1
    }
    index = 0
    while index < netRingCount {
        let frame = allocFrame()
        if frame == 0 { return false }
        keeping[index] = frame
        index += 1
    }
    let reach: UInt64 = 0x1_0000_0000
    if netRxDescFrame >= reach || netTxDescFrame >= reach
        || netTxBufferFrame >= reach || netRxKeepingFrame >= reach {
        return false
    }
    index = 0
    while index < netRingCount {
        if keeping[index] >= reach { return false }
        index += 1
    }
    netFramesReady = true
    return true
}

/// Raises the card: from silence, once. Milestone 20 raised it
/// at every `net` and let it die with the conversation; milestone
/// 29 raises it at the first `net` and keeps it raised, so the
/// lease the conversation takes has a living card under it. The
/// raising itself is milestone 20's, unchanged:
/// its interrupts masked, both engines stopped, the reset the
/// datasheet prescribes, and the wait for the card's own word
/// that the reset is done. Then the honest minimum of state: the
/// multicast table cleared word by word; the hardware address
/// read from the card — and written back into its first filter
/// with the valid mark standing, so answers addressed to us are
/// let in; the link asked up, with auto-negotiation as the card
/// presents it; and both rings built fresh in their frames — the
/// receive descriptors each naming their buffer, the tails laid
/// where a fresh ring's tails belong — before either engine is
/// switched on. Because the raising now runs only once, the
/// rings are NOT reset between conversations: the receive ring
/// is drained by whoever listens or serves, exactly once per
/// frame, and the transmit ring is walked by netTxNext — no
/// frame leaks across runs, because every filled descriptor is
/// handed back by the one hand that consumed it.
func netRaise() -> Bool {
    netWrite32(netRegIMC, 0xFFFFFFFF)
    netWrite32(netRegRCTL, 0)
    netWrite32(netRegTCTL, 0)
    netWrite32(netRegCTRL, netRead32(netRegCTRL) | 0x04000000)
    var waited = 0
    while netRead32(netRegCTRL) & 0x04000000 != 0 {
        waited += 1
        if waited >= discWaitLimit { return false }
    }
    netWrite32(netRegIMC, 0xFFFFFFFF)
    _ = netRead32(netRegICR)
    var slot = 0
    while slot < 128 {
        netWrite32(netRegMTA + UInt64(slot) * 4, 0)
        slot += 1
    }
    let ral = netRead32(netRegRAL0)
    let rah = netRead32(netRegRAH0)
    netMacPacked = UInt64(ral) | (UInt64(rah & 0xFFFF) << 32)
    if netMacPacked == 0 { return false }
    netWrite32(netRegRAL0, ral)
    netWrite32(netRegRAH0, (rah & 0xFFFF) | 0x80000000)
    netWrite32(netRegCTRL, netRead32(netRegCTRL) | 0x60)
    // The receive ring: its frame wiped, each descriptor naming
    // its buffer, the card's head at the ring's start and ours
    // one short of the end — the whole ring offered but one
    // descriptor, the ring law the card's format asks.
    let rxBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netRxDescFrame))!
    var index = 0
    while index < 4096 {
        rxBytes[index] = 0
        index += 1
    }
    index = 0
    while index < netRingCount {
        netSetDescWord(netRxDescFrame, index, 0,
                       netRxBufferAddress(index))
        netSetDescWord(netRxDescFrame, index, 1, 0)
        index += 1
    }
    netWrite32(netRegRDBAL, UInt32(netRxDescFrame & 0xFFFFFFFF))
    netWrite32(netRegRDBAH, UInt32(netRxDescFrame >> 32))
    netWrite32(netRegRDLEN, UInt32(netRingCount * 16))
    netWrite32(netRegRDH, 0)
    netWrite32(netRegRDT, UInt32(netRingCount - 1))
    netRxNext = 0
    // The transmit ring: wiped, empty, its head and tail together
    // at the start, and the gaps between packets at the values
    // the datasheet commends for this card — ten, ten, and ten
    // bit-times and their kin.
    let txBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxDescFrame))!
    index = 0
    while index < 4096 {
        txBytes[index] = 0
        index += 1
    }
    netWrite32(netRegTDBAL, UInt32(netTxDescFrame & 0xFFFFFFFF))
    netWrite32(netRegTDBAH, UInt32(netTxDescFrame >> 32))
    netWrite32(netRegTDLEN, UInt32(netRingCount * 16))
    netWrite32(netRegTDH, 0)
    netWrite32(netRegTDT, 0)
    netTxNext = 0
    netWrite32(netRegTIPG, 0x00A0280A)
    // The engines on: receive under its filter law — our own
    // address let in, the broadcast let in, the frame's checksum
    // tail stripped so a received length is the frame's own —
    // and transmit, padding short frames as the standard asks.
    netWrite32(netRegRCTL, 0x0400800A)
    netWrite32(netRegTCTL, 0x0000000A)
    return true
}

/// The link's truth, waited for a little: the card takes a breath
/// after its reset to agree the wire's terms, so the asking rests
/// on the heartbeat for up to three seconds before it believes
/// either answer. What the status register says then is spoken
/// as found — up, or not up — and no longer a wait than that is
/// pretended.
func netLinkUp() -> Bool {
    var waited: UInt64 = 0
    while waited < 300 {
        if netRead32(netRegSTATUS) & 0x2 != 0 { return true }
        waitTicks(1)
        waited += 1
    }
    return netRead32(netRegSTATUS) & 0x2 != 0
}

/// The packet builders' small hands: wide values written into the
/// frame big-end first, as the wire's formats lay them — the
/// mirror of the disc reader's little-endian hands, and for the
/// same reason: the format, not the machine, chooses the order.
@inline(__always)
func netPut16(_ buffer: UnsafeMutablePointer<UInt8>, _ offset: Int,
              _ value: UInt16) {
    buffer[offset] = UInt8(value >> 8)
    buffer[offset + 1] = UInt8(value & 0xFF)
}

@inline(__always)
func netPut32(_ buffer: UnsafeMutablePointer<UInt8>, _ offset: Int,
              _ value: UInt32) {
    netPut16(buffer, offset, UInt16(value >> 16))
    netPut16(buffer, offset + 2, UInt16(value & 0xFFFF))
}

@inline(__always)
func netGet16(_ buffer: UnsafeMutablePointer<UInt8>,
              _ offset: Int) -> UInt16 {
    UInt16(buffer[offset]) << 8 | UInt16(buffer[offset + 1])
}

@inline(__always)
func netGet32(_ buffer: UnsafeMutablePointer<UInt8>,
              _ offset: Int) -> UInt32 {
    UInt32(netGet16(buffer, offset)) << 16
        | UInt32(netGet16(buffer, offset + 2))
}

/// The IPv4 header checksum: the one's-complement sum of the
/// header's sixteen-bit words, folded until the carries come
/// home. The header's own checksum field stands zero while it is
/// reckoned, as the standard prescribes.
func netIPChecksum(_ buffer: UnsafeMutablePointer<UInt8>,
                   _ offset: Int, _ length: Int) -> UInt16 {
    var sum: UInt32 = 0
    var index = 0
    while index + 1 < length {
        sum += UInt32(netGet16(buffer, offset + index))
        index += 2
    }
    while sum >> 16 != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16)
    }
    return UInt16(~sum & 0xFFFF)
}

/// Builds the asking in the transmit buffer and returns its true
/// length: one DHCP discover, laid down format by format.
/// Ethernet: the broadcast's address, ours, and IPv4's number.
/// IPv4: no options, the broadcast again, a time to live of 64,
/// UDP's number, the header's checksum honestly reckoned — and
/// no address of our own, because having none is the whole point
/// of the asking. UDP: the DHCP ports, client to server, and no
/// checksum, which IPv4 expressly allows. BOOTP: a request, our
/// transaction number fresh from the heartbeat's count, the
/// broadcast flag standing (we hold no address a unicast answer
/// could reach), our hardware address in the asking's own field,
/// and the DHCP options behind the format's magic word: message
/// type discover, and the short list of answers we would value.
/// Nothing is padded but the option list's own end mark; the
/// card appends the frame's checksum tail itself, and the count
/// returned is the frame as built, tail aside — the card's four
/// bytes are the card's, and the report counts ours.
func netBuildDiscover() -> Int {
    let buffer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < netBufferBytes {
        buffer[index] = 0
        index += 1
    }
    netXid = 0x43415244 ^ UInt32(truncatingIfNeeded: ticks)
    // Ethernet.
    index = 0
    while index < 6 {
        buffer[index] = 0xFF
        buffer[6 + index] = netMacByte(index)
        index += 1
    }
    netPut16(buffer, 12, 0x0800)
    // IPv4. The lengths are laid once the whole is known; the
    // checksum closes the header, reckoned last over the rest.
    let ip = 14
    buffer[ip] = 0x45
    netPut16(buffer, ip + 4, UInt16(truncatingIfNeeded: ticks))
    buffer[ip + 8] = 64
    buffer[ip + 9] = 17
    netPut32(buffer, ip + 16, 0xFFFFFFFF)
    // UDP.
    let udp = ip + 20
    netPut16(buffer, udp, 68)
    netPut16(buffer, udp + 2, 67)
    // BOOTP, behind the UDP header.
    let bootp = udp + 8
    buffer[bootp] = 1
    buffer[bootp + 1] = 1
    buffer[bootp + 2] = 6
    netPut32(buffer, bootp + 4, netXid)
    netPut16(buffer, bootp + 10, 0x8000)
    index = 0
    while index < 6 {
        buffer[bootp + 28 + index] = netMacByte(index)
        index += 1
    }
    netPut32(buffer, bootp + 236, 0x63825363)
    // The options: discover, the valued answers' list, the end.
    var at = bootp + 240
    buffer[at] = 53
    buffer[at + 1] = 1
    buffer[at + 2] = 1
    buffer[at + 3] = 55
    buffer[at + 4] = 3
    buffer[at + 5] = 1
    buffer[at + 6] = 3
    buffer[at + 7] = 6
    buffer[at + 8] = 255
    at += 9
    // The lengths, now that the whole stands.
    let total = at
    netPut16(buffer, ip + 2, UInt16(total - ip))
    netPut16(buffer, udp + 4, UInt16(total - udp))
    netPut16(buffer, ip + 10, netIPChecksum(buffer, ip, 20))
    return total
}

/// Sends the built frame: one descriptor under the transmit
/// ring's walking hand — its buffer, its true length, the orders
/// to end the
/// packet, append its checksum tail, and report back — the tail
/// moved past it, and the wait, on the heartbeat, for the card's
/// own word in the descriptor that the sending is done. Two
/// seconds is the patience; a card that has not answered by then
/// is reported as not having sent, and the shell is never left
/// waiting on the wire's machinery.
func netSend(length: Int) -> Bool {
    // The descriptor is the walking hand's: milestone 20 could
    // always use descriptor 0 because it rebuilt the ring per
    // conversation; a card that stays raised sends many frames
    // on one ring, and a tail written to a place it already
    // stands would send nothing at all. So the hand walks, the
    // descriptor's word is written whole (its done bit cleared
    // by the writing), and the tail is moved one past it.
    let slot = netTxNext
    netTxNext = (netTxNext + 1) % netRingCount
    netSetDescWord(netTxDescFrame, slot, 0, netTxBufferFrame)
    netSetDescWord(netTxDescFrame, slot, 1,
                   UInt64(length) | (0x0B << 24))
    netWrite32(netRegTDT, UInt32(netTxNext))
    var waited: UInt64 = 0
    while waited < 200 {
        if netDescWord(netTxDescFrame, slot, 1) >> 32 & 1 != 0 {
            return true
        }
        waitTicks(1)
        waited += 1
    }
    return false
}

/// The one's-complement checksum over any span: the ICMP
/// reckoning, where a span may run to an odd length. The words
/// are summed big-end first, a lone last byte counts as the
/// high half of a word, and the carries fold home — the same
/// reckoning the IPv4 header's helper above performs over its
/// even twenty bytes, generalized to the spans ICMP carries.
func netChecksumWords(_ buffer: UnsafeMutablePointer<UInt8>,
                      _ offset: Int, _ length: Int) -> UInt16 {
    var sum: UInt32 = 0
    var index = 0
    while index + 1 < length {
        sum += UInt32(netGet16(buffer, offset + index))
        index += 2
    }
    if index < length {
        sum += UInt32(buffer[offset + index]) << 8
    }
    while sum >> 16 != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16)
    }
    return UInt16(~sum & 0xFFFF)
}

/// One octet of the gateway's hardware address, by its place —
/// the twin of netMacByte, for the address ARP teaches us.
@inline(__always)
func netGwMacByte(_ index: Int) -> UInt8 {
    UInt8((netGatewayMacPacked >> UInt64(index * 8)) & 0xFF)
}

/// Builds the taking in the transmit buffer and returns its
/// true length: one DHCP request, the discover's mirror in
/// every field but its options. The transaction number is the
/// conversation's own, struck at the discover and never
/// restruck; the broadcast flag stands for the discover's
/// reason (we still hold no address a unicast answer could
/// reach); our hardware address stands in the same field. The
/// options say the taking plainly: message type request, the
/// requested address named in full (the offer's yiaddr, kept
/// from its frame), the server identifier (reckoned by the
/// caller into netOfferServerId: the offer's option 54 when it
/// carried one, else its siaddr), and the same short list of
/// valued answers the discover asked for.
func netBuildRequest() -> Int {
    let buffer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < netBufferBytes {
        buffer[index] = 0
        index += 1
    }
    // Ethernet.
    index = 0
    while index < 6 {
        buffer[index] = 0xFF
        buffer[6 + index] = netMacByte(index)
        index += 1
    }
    netPut16(buffer, 12, 0x0800)
    // IPv4, as the discover's: no address of our own yet, the
    // broadcast again, the header's checksum reckoned last.
    let ip = 14
    buffer[ip] = 0x45
    netPut16(buffer, ip + 4, UInt16(truncatingIfNeeded: ticks))
    buffer[ip + 8] = 64
    buffer[ip + 9] = 17
    netPut32(buffer, ip + 16, 0xFFFFFFFF)
    // UDP.
    let udp = ip + 20
    netPut16(buffer, udp, 68)
    netPut16(buffer, udp + 2, 67)
    // BOOTP, behind the UDP header.
    let bootp = udp + 8
    buffer[bootp] = 1
    buffer[bootp + 1] = 1
    buffer[bootp + 2] = 6
    netPut32(buffer, bootp + 4, netXid)
    netPut16(buffer, bootp + 10, 0x8000)
    index = 0
    while index < 6 {
        buffer[bootp + 28 + index] = netMacByte(index)
        index += 1
    }
    netPut32(buffer, bootp + 236, 0x63825363)
    // The options: request, the address asked for by name, the
    // server named, the valued answers' list, the end.
    var at = bootp + 240
    buffer[at] = 53
    buffer[at + 1] = 1
    buffer[at + 2] = 3
    buffer[at + 3] = 50
    buffer[at + 4] = 4
    netPut32(buffer, at + 5, netOfferAddress)
    buffer[at + 9] = 54
    buffer[at + 10] = 4
    netPut32(buffer, at + 11, netOfferServerId)
    buffer[at + 15] = 55
    buffer[at + 16] = 3
    buffer[at + 17] = 1
    buffer[at + 18] = 3
    buffer[at + 19] = 6
    buffer[at + 20] = 255
    at += 21
    // The lengths, now that the whole stands.
    let total = at
    netPut16(buffer, ip + 2, UInt16(total - ip))
    netPut16(buffer, udp + 4, UInt16(total - udp))
    netPut16(buffer, ip + 10, netIPChecksum(buffer, ip, 20))
    return total
}

/// Judges one received frame as a DHCP answer to this
/// conversation, and returns its message type — or zero, when
/// the frame is not a DHCP answer of ours at all. Every test is
/// milestone 20's, made in the frame's own terms, and no field
/// is read until the frame's proven length covers it: Ethernet
/// carrying IPv4, an address that is the broadcast's or our
/// own; IPv4 carrying UDP, the client's port at the destination;
/// BOOTP's shape — a reply, this conversation's transaction
/// number, our own hardware address named in the reply's field,
/// the format's magic word. A frame that passes is testimony:
/// its fixed fields and its options are walked — pad marks
/// stepped over, the end mark honoured, nothing read past the
/// frame, no option believed past its stated length — into the
/// parsed keeping above, and its type comes home with the call.
func netParseDhcp(_ buffer: UnsafeMutablePointer<UInt8>,
                  _ length: Int) -> Int {
    let fixed = 14 + 20 + 8 + 240
    if length < fixed { return 0 }
    if netGet16(buffer, 12) != 0x0800 { return 0 }
    var broadcast = true
    var ours = true
    var index = 0
    while index < 6 {
        if buffer[index] != 0xFF { broadcast = false }
        if buffer[index] != netMacByte(index) { ours = false }
        index += 1
    }
    if !broadcast && !ours { return 0 }
    let ip = 14
    if buffer[ip] >> 4 != 4 { return 0 }
    let ipLength = Int(buffer[ip] & 0x0F) * 4
    if ipLength < 20 || length < ip + ipLength + 8 + 240 {
        return 0
    }
    if buffer[ip + 9] != 17 { return 0 }
    let udp = ip + ipLength
    if netGet16(buffer, udp + 2) != 68 { return 0 }
    let bootp = udp + 8
    if buffer[bootp] != 2 { return 0 }
    if netGet32(buffer, bootp + 4) != netXid { return 0 }
    index = 0
    while index < 6 {
        if buffer[bootp + 28 + index] != netMacByte(index) {
            return 0
        }
        index += 1
    }
    if netGet32(buffer, bootp + 236) != 0x63825363 { return 0 }
    netParsedType = 0
    netParsedYiaddr = netGet32(buffer, bootp + 16)
    netParsedSiaddr = netGet32(buffer, bootp + 20)
    netParsedMask = 0
    netParsedRouter = 0
    netParsedDns = 0
    netParsedServerId = 0
    netParsedLease = 0
    netParsedHasMask = false
    netParsedHasRouter = false
    netParsedHasDns = false
    netParsedHasServerId = false
    netParsedHasLease = false
    var at = bootp + 240
    while at < length {
        let code = buffer[at]
        if code == 255 { break }
        if code == 0 {
            at += 1
            continue
        }
        if at + 1 >= length { break }
        let optionLength = Int(buffer[at + 1])
        if at + 2 + optionLength > length { break }
        if code == 53 && optionLength >= 1 {
            netParsedType = Int(buffer[at + 2])
        } else if code == 1 && optionLength >= 4 {
            netParsedMask = netGet32(buffer, at + 2)
            netParsedHasMask = true
        } else if code == 3 && optionLength >= 4 {
            netParsedRouter = netGet32(buffer, at + 2)
            netParsedHasRouter = true
        } else if code == 6 && optionLength >= 4 {
            netParsedDns = netGet32(buffer, at + 2)
            netParsedHasDns = true
        } else if code == 51 && optionLength >= 4 {
            netParsedLease = netGet32(buffer, at + 2)
            netParsedHasLease = true
        } else if code == 54 && optionLength >= 4 {
            netParsedServerId = netGet32(buffer, at + 2)
            netParsedHasServerId = true
        }
        at += 2 + optionLength
    }
    return netParsedType
}

/// Judges one received frame as the gateway's ARP reply: an
/// ARP answer in the standard shape, its sender the gateway we
/// asked for, its target ourselves. A frame that passes teaches
/// us the gateway's hardware address, kept packed beside our
/// own; the learning is the verdict.
func netParseArpReply(_ buffer: UnsafeMutablePointer<UInt8>,
                      _ length: Int) -> Bool {
    if length < 42 { return false }
    if netGet16(buffer, 12) != 0x0806 { return false }
    if netGet16(buffer, 14) != 1 { return false }
    if netGet16(buffer, 16) != 0x0800 { return false }
    if buffer[18] != 6 || buffer[19] != 4 { return false }
    if netGet16(buffer, 20) != 2 { return false }
    if netGet32(buffer, 28) != netGateway { return false }
    if netGet32(buffer, 38) != netAddress { return false }
    var packed: UInt64 = 0
    var index = 0
    while index < 6 {
        packed |= UInt64(buffer[22 + index]) << UInt64(index * 8)
        index += 1
    }
    if packed == 0 { return false }
    netGatewayMacPacked = packed
    return true
}

/// Judges one received frame as the gateway's answer to our
/// ping: IPv4 carrying ICMP, from the gateway, addressed to
/// us, an echo reply whose identifier and sequence are the
/// ones we sent. Nothing else is believed on its word.
func netParsePingReply(_ buffer: UnsafeMutablePointer<UInt8>,
                       _ length: Int) -> Bool {
    if length < 14 + 20 + 8 { return false }
    if netGet16(buffer, 12) != 0x0800 { return false }
    var broadcast = true
    var ours = true
    var index = 0
    while index < 6 {
        if buffer[index] != 0xFF { broadcast = false }
        if buffer[index] != netMacByte(index) { ours = false }
        index += 1
    }
    if !broadcast && !ours { return false }
    let ip = 14
    if buffer[ip] >> 4 != 4 { return false }
    let ipLength = Int(buffer[ip] & 0x0F) * 4
    if ipLength < 20 || length < ip + ipLength + 8 { return false }
    if buffer[ip + 9] != 1 { return false }
    if netGet32(buffer, ip + 12) != netGateway { return false }
    if netGet32(buffer, ip + 16) != netAddress { return false }
    let icmp = ip + ipLength
    if buffer[icmp] != 0 || buffer[icmp + 1] != 0 { return false }
    if netGet16(buffer, icmp + 4) != netPingId { return false }
    if netGet16(buffer, icmp + 6) != netPingSeq { return false }
    return true
}

/// Steps over one DNS name in a received answer, from its
/// first label to just past its end: labels walked by their
/// lengths, a zero closing the walk, a compression pointer —
/// the standard's two high bits standing — ending it in two
/// bytes wherever it points. Returns the place just past the
/// name, or -1 when the walk would leave the proven span.
func netDnsSkipName(_ buffer: UnsafeMutablePointer<UInt8>,
                    _ start: Int, _ end: Int) -> Int {
    var at = start
    while at < end {
        let label = buffer[at]
        if label == 0 { return at + 1 }
        if label & 0xC0 == 0xC0 { return at + 2 }
        at += 1 + Int(label)
    }
    return -1
}

/// Judges one received frame as the DNS server's answer to our
/// asking: IPv4 carrying UDP, from the server we asked, from
/// its port 53 to the ephemeral port we asked from, a DNS
/// answer carrying our identifier and at least one answer.
/// The answers are walked the way the questions were — names
/// stepped over, no field read past the frame — and the first
/// A record's address is kept for the report.
func netParseDnsResponse(_ buffer: UnsafeMutablePointer<UInt8>,
                         _ length: Int) -> Bool {
    if length < 14 + 20 + 8 + 12 { return false }
    if netGet16(buffer, 12) != 0x0800 { return false }
    let ip = 14
    if buffer[ip] >> 4 != 4 { return false }
    let ipLength = Int(buffer[ip] & 0x0F) * 4
    if ipLength < 20 || length < ip + ipLength + 8 + 12 {
        return false
    }
    if buffer[ip + 9] != 17 { return false }
    if netGet32(buffer, ip + 12) != netDns { return false }
    let udp = ip + ipLength
    if netGet16(buffer, udp) != 53 { return false }
    if netGet16(buffer, udp + 2) != netDnsPort { return false }
    let dns = udp + 8
    let udpLength = Int(netGet16(buffer, udp + 4))
    var end = udp + udpLength
    if end > length { end = length }
    if end < dns + 12 { return false }
    if netGet16(buffer, dns) != netDnsId { return false }
    if buffer[dns + 2] & 0x80 == 0 { return false }
    let questions = Int(netGet16(buffer, dns + 4))
    let answers = Int(netGet16(buffer, dns + 6))
    if answers < 1 { return false }
    var at = dns + 12
    var q = 0
    while q < questions {
        at = netDnsSkipName(buffer, at, end)
        if at < 0 || at + 4 > end { return false }
        at += 4
        q += 1
    }
    var a = 0
    while a < answers {
        at = netDnsSkipName(buffer, at, end)
        if at < 0 || at + 10 > end { return false }
        let type = netGet16(buffer, at)
        let dataLength = Int(netGet16(buffer, at + 8))
        if at + 10 + dataLength > end { return false }
        if type == 1 && dataLength == 4 {
            netDnsResolved = netGet32(buffer, at + 10)
            return true
        }
        at += 10 + dataLength
        a += 1
    }
    return false
}

/// What one listening waits for, named once: the conversation
/// waits in turn for an offer, for an ack (a nak ends it too),
/// and — the lease standing — for the gateway's ARP reply, the
/// gateway's ping answer, and the DNS server's answer.
let netAwaitOffer = 1
let netAwaitAck = 2
let netAwaitArp = 3
let netAwaitPing = 4
let netAwaitDns = 5

/// Judges one frame against one waiting: 0 when the frame is
/// not the awaited one and the listening goes on, 1 when it is,
/// and — for the ack's waiting alone — 2 when the network has
/// refused us with a nak, which ends the conversation as surely
/// as an ack ends it in our favour.
func netJudgeAwait(_ kind: Int,
                   _ buffer: UnsafeMutablePointer<UInt8>,
                   _ length: Int) -> Int {
    if kind == netAwaitOffer {
        return netParseDhcp(buffer, length) == 2 ? 1 : 0
    }
    if kind == netAwaitAck {
        let type = netParseDhcp(buffer, length)
        if type == 5 { return 1 }
        if type == 6 { return 2 }
        return 0
    }
    if kind == netAwaitArp {
        return netParseArpReply(buffer, length) ? 1 : 0
    }
    if kind == netAwaitPing {
        return netParsePingReply(buffer, length) ? 1 : 0
    }
    return netParseDnsResponse(buffer, length) ? 1 : 0
}

/// Listens on the receive ring until the deadline — a count of
/// heartbeat ticks the caller names — for the awaited answer.
/// Milestone 20's listening, generalized: each descriptor the
/// card has filled is judged by the waiting's own tests; judged
/// or not, its frame is stepped over and the descriptor handed
/// back to the card exactly as the first listening handed it
/// back (its standing cleared, the tail written to its place),
/// so the ring never fills behind a frame nobody wanted, and
/// no frame survives from one waiting into the next. Frames
/// that are not the answer are counted into netAwaitOthers.
/// Between looks the kernel rests in `hlt`: the heartbeat wakes
/// it a hundred times a second, and no wire is ever waited on
/// by spinning. When the deadline passes with no answer, the
/// listening simply ends — nothing hangs. The verdict comes
/// home: 1 answered, 2 refused (the ack's waiting alone), 0
/// for silence.
func netAwait(_ kind: Int, _ limitTicks: UInt64) -> Int {
    let start = ticks
    while ticks - start < limitTicks {
        let standing = netDescWord(netRxDescFrame, netRxNext, 1)
        if standing >> 32 & 1 == 0 {
            cardnullHltOnce()
            continue
        }
        let length = Int(standing & 0xFFFF)
        var verdict = 0
        if length <= netBufferBytes {
            verdict = netJudgeAwait(kind, netRxBuffer(netRxNext),
                                    length)
        }
        netSetDescWord(netRxDescFrame, netRxNext, 1, 0)
        netWrite32(netRegRDT, UInt32(netRxNext))
        netRxNext = (netRxNext + 1) % netRingCount
        if verdict != 0 { return verdict }
        netAwaitOthers += 1
    }
    return 0
}

/// Builds the gateway's ARP asking in the transmit buffer: an
/// Ethernet broadcast in ARP's own format — who has the
/// gateway's address? — naming ourselves, by hardware and by
/// the address the lease made ours, as the one asking. Forty-
/// two bytes, no more than the format holds.
func netBuildArpRequest() -> Int {
    let buffer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < netBufferBytes {
        buffer[index] = 0
        index += 1
    }
    index = 0
    while index < 6 {
        buffer[index] = 0xFF
        buffer[6 + index] = netMacByte(index)
        index += 1
    }
    netPut16(buffer, 12, 0x0806)
    let arp = 14
    netPut16(buffer, arp, 1)
    netPut16(buffer, arp + 2, 0x0800)
    buffer[arp + 4] = 6
    buffer[arp + 5] = 4
    netPut16(buffer, arp + 6, 1)
    index = 0
    while index < 6 {
        buffer[arp + 8 + index] = netMacByte(index)
        index += 1
    }
    netPut32(buffer, arp + 14, netAddress)
    netPut32(buffer, arp + 24, netGateway)
    return 42
}

/// Builds the gateway's ping in the transmit buffer: an ICMP
/// echo request addressed to the gateway's hardware address —
/// the ARP learning is what lets this frame be addressed at
/// all — carrying an identifier and sequence of our choosing
/// and eight bytes of payload that spell our name, with the
/// IPv4 and ICMP checksums both honestly reckoned over the
/// fields as they stand.
func netBuildPing() -> Int {
    let buffer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < netBufferBytes {
        buffer[index] = 0
        index += 1
    }
    netPingId = 0x4341
    netPingSeq = 1
    index = 0
    while index < 6 {
        buffer[index] = netGwMacByte(index)
        buffer[6 + index] = netMacByte(index)
        index += 1
    }
    netPut16(buffer, 12, 0x0800)
    let ip = 14
    buffer[ip] = 0x45
    netPut16(buffer, ip + 2, 36)
    netPut16(buffer, ip + 4, UInt16(truncatingIfNeeded: ticks))
    buffer[ip + 8] = 64
    buffer[ip + 9] = 1
    netPut32(buffer, ip + 12, netAddress)
    netPut32(buffer, ip + 16, netGateway)
    let icmp = ip + 20
    buffer[icmp] = 8
    netPut16(buffer, icmp + 4, netPingId)
    netPut16(buffer, icmp + 6, netPingSeq)
    buffer[icmp + 8] = 0x43    // C
    buffer[icmp + 9] = 0x41    // A
    buffer[icmp + 10] = 0x52   // R
    buffer[icmp + 11] = 0x44   // D
    buffer[icmp + 12] = 0x4E   // N
    buffer[icmp + 13] = 0x55   // U
    buffer[icmp + 14] = 0x4C   // L
    buffer[icmp + 15] = 0x4C   // L
    netPut16(buffer, icmp + 2, netChecksumWords(buffer, icmp, 16))
    netPut16(buffer, ip + 10, netIPChecksum(buffer, ip, 20))
    return 14 + 36
}

/// Builds the DNS asking in the transmit buffer: a well-formed
/// query for the name cardnull.com, an A record asked for in
/// the internet class, recursion desired, from an ephemeral
/// port of the heartbeat's choosing to the DNS server's port
/// 53 — addressed, like the ping, to the gateway's hardware
/// address, the road every off-wire frame travels. The UDP
/// checksum is left at zero, which IPv4 expressly allows; the
/// IPv4 header's checksum is reckoned honestly, as always.
func netBuildDnsQuery() -> Int {
    let buffer = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < netBufferBytes {
        buffer[index] = 0
        index += 1
    }
    netDnsId = UInt16(truncatingIfNeeded: ticks &+ 0x4341)
    netDnsPort = UInt16(truncatingIfNeeded: (ticks & 0x3FF) | 0xC000)
    index = 0
    while index < 6 {
        buffer[index] = netGwMacByte(index)
        buffer[6 + index] = netMacByte(index)
        index += 1
    }
    netPut16(buffer, 12, 0x0800)
    let ip = 14
    buffer[ip] = 0x45
    netPut16(buffer, ip + 2, 58)
    netPut16(buffer, ip + 4, UInt16(truncatingIfNeeded: ticks))
    buffer[ip + 8] = 64
    buffer[ip + 9] = 17
    netPut32(buffer, ip + 12, netAddress)
    netPut32(buffer, ip + 16, netDns)
    let udp = ip + 20
    netPut16(buffer, udp, netDnsPort)
    netPut16(buffer, udp + 2, 53)
    netPut16(buffer, udp + 4, 38)
    let dns = udp + 8
    netPut16(buffer, dns, netDnsId)
    netPut16(buffer, dns + 2, 0x0100)
    netPut16(buffer, dns + 4, 1)
    var at = dns + 12
    buffer[at] = 8
    buffer[at + 1] = 0x63      // c
    buffer[at + 2] = 0x61      // a
    buffer[at + 3] = 0x72      // r
    buffer[at + 4] = 0x64      // d
    buffer[at + 5] = 0x6E      // n
    buffer[at + 6] = 0x75      // u
    buffer[at + 7] = 0x6C      // l
    buffer[at + 8] = 0x6C      // l
    buffer[at + 9] = 3
    buffer[at + 10] = 0x63     // c
    buffer[at + 11] = 0x6F     // o
    buffer[at + 12] = 0x6D     // m
    buffer[at + 13] = 0
    netPut16(buffer, at + 14, 1)
    netPut16(buffer, at + 16, 1)
    netPut16(buffer, ip + 10, netIPChecksum(buffer, ip, 20))
    return 14 + 58
}

/// Is the held lease's time spent? A lease whose length was
/// never named cannot be reckoned spent — the kernel holds it
/// until the network says otherwise, and says in its report
/// that the length was not named. A named lease is spent when
/// the heartbeat has counted its seconds since the taking.
func netLeaseExpiredNow() -> Bool {
    if !netLeaseHeld || !netLeaseKnown { return false }
    return ticks - netLeaseTakenTick
        >= UInt64(netLeaseSeconds) * 100
}

/// Lets the lease go, wholly: the held word cleared, every
/// answer it carried cleared with it, and the gateway's learned
/// address forgotten — a lease that is not held must not be
/// answered for, and state from a dead lease must not colour
/// the next asking. The proof counters stand: they are the
/// history of the lease that was, until the next taking resets
/// them as its own first act.
func netDropLease() {
    netLeaseHeld = false
    netAddress = 0
    netMask = 0
    netMaskKnown = false
    netGateway = 0
    netGatewayKnown = false
    netDns = 0
    netDnsKnown = false
    netServer = 0
    netLeaseSeconds = 0
    netLeaseKnown = false
    netGatewayMacPacked = 0
    netGatewayMacKnown = false
}

/// Is this frame an ARP request asking for OUR address? The
/// standard shape, the asking operation, ourselves as the
/// target — nothing looser is answered, because an answer is
/// a claim about who we are.
func netServiceArpTarget(_ buffer: UnsafeMutablePointer<UInt8>,
                         _ length: Int) -> Bool {
    if length < 42 { return false }
    if netGet16(buffer, 12) != 0x0806 { return false }
    if netGet16(buffer, 14) != 1 { return false }
    if netGet16(buffer, 16) != 0x0800 { return false }
    if buffer[18] != 6 || buffer[19] != 4 { return false }
    if netGet16(buffer, 20) != 1 { return false }
    return netGet32(buffer, 38) == netAddress
}

/// Is this frame an ICMP echo request addressed to OUR
/// address? IPv4 carrying ICMP, ourselves at the destination,
/// the asking type standing — the payload's shape is the
/// asker's own, and is echoed whole whatever it holds.
func netServiceEchoTarget(_ buffer: UnsafeMutablePointer<UInt8>,
                          _ length: Int) -> Bool {
    if length < 14 + 20 + 8 { return false }
    if netGet16(buffer, 12) != 0x0800 { return false }
    let ip = 14
    if buffer[ip] >> 4 != 4 { return false }
    let ipLength = Int(buffer[ip] & 0x0F) * 4
    if ipLength < 20 || length < ip + ipLength + 8 { return false }
    if buffer[ip + 9] != 1 { return false }
    if netGet32(buffer, ip + 16) != netAddress { return false }
    let icmp = ip + ipLength
    return buffer[icmp] == 8
}

/// Answers an ARP request for our address: the reply is built
/// fresh in the transmit buffer — the asker's hardware and
/// protocol addresses read out of their own frame first —
/// naming ourselves as the address's holder, and sent by the
/// one sending hand. The verdict is the sending's own.
func netServiceSendArpReply(_ buffer: UnsafeMutablePointer<UInt8>,
                            _ length: Int) -> Bool {
    var askerMac0: UInt8 = 0
    var askerMac1: UInt8 = 0
    var askerMac2: UInt8 = 0
    var askerMac3: UInt8 = 0
    var askerMac4: UInt8 = 0
    var askerMac5: UInt8 = 0
    askerMac0 = buffer[22]
    askerMac1 = buffer[23]
    askerMac2 = buffer[24]
    askerMac3 = buffer[25]
    askerMac4 = buffer[26]
    askerMac5 = buffer[27]
    let askerAddress = netGet32(buffer, 28)
    let tx = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < netBufferBytes {
        tx[index] = 0
        index += 1
    }
    tx[0] = askerMac0
    tx[1] = askerMac1
    tx[2] = askerMac2
    tx[3] = askerMac3
    tx[4] = askerMac4
    tx[5] = askerMac5
    index = 0
    while index < 6 {
        tx[6 + index] = netMacByte(index)
        index += 1
    }
    netPut16(tx, 12, 0x0806)
    let arp = 14
    netPut16(tx, arp, 1)
    netPut16(tx, arp + 2, 0x0800)
    tx[arp + 4] = 6
    tx[arp + 5] = 4
    netPut16(tx, arp + 6, 2)
    index = 0
    while index < 6 {
        tx[arp + 8 + index] = netMacByte(index)
        index += 1
    }
    netPut32(tx, arp + 14, netAddress)
    tx[arp + 18] = askerMac0
    tx[arp + 19] = askerMac1
    tx[arp + 20] = askerMac2
    tx[arp + 21] = askerMac3
    tx[arp + 22] = askerMac4
    tx[arp + 23] = askerMac5
    netPut32(tx, arp + 24, askerAddress)
    return netSend(length: 42)
}

/// Answers a ping addressed to us: the asking frame is copied
/// whole into the transmit buffer — payload and all, within
/// the buffer law the ring itself enforces — and turned
/// around there: the Ethernet addresses exchanged, the IPv4
/// addresses exchanged, the ICMP type made a reply, and both
/// checksums reckoned afresh over the turned fields. Nothing
/// of the asking is edited in its own buffer, and nothing of
/// the reply is invented: what was asked is what is answered.
func netServiceSendEchoReply(_ buffer: UnsafeMutablePointer<UInt8>,
                             _ length: Int) -> Bool {
    let ip = 14
    let ipLength = Int(buffer[ip] & 0x0F) * 4
    let ipTotal = Int(netGet16(buffer, ip + 2))
    let frameLength = ip + ipTotal
    if ipTotal < ipLength + 8 || frameLength > length
        || frameLength > netBufferBytes {
        return false
    }
    let tx = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(netTxBufferFrame))!
    var index = 0
    while index < frameLength {
        tx[index] = buffer[index]
        index += 1
    }
    index = 0
    while index < 6 {
        let asker = tx[6 + index]
        tx[index] = asker
        tx[6 + index] = netMacByte(index)
        index += 1
    }
    let askerAddress = netGet32(tx, ip + 12)
    netPut32(tx, ip + 12, netAddress)
    netPut32(tx, ip + 16, askerAddress)
    let icmp = ip + ipLength
    tx[icmp] = 0
    netPut16(tx, ip + 10, 0)
    netPut16(tx, ip + 10, netIPChecksum(tx, ip, ipLength))
    netPut16(tx, icmp + 2, 0)
    netPut16(tx, icmp + 2,
             netChecksumWords(tx, icmp, ipTotal - ipLength))
    return netSend(length: frameLength)
}

/// The citizenship service: whenever the kernel idles with a
/// lease held, the wire is minded. The receive ring is drained
/// a frame at a time — an ARP request for our address answered
/// and counted, a ping addressed to us answered and counted,
/// anything else counted and stepped over — and every
/// descriptor is handed back exactly as the listening hands it
/// back, so the ring never fills behind the service. The pass
/// is bounded at sixty-four frames: a flooded wire must not
/// starve the keyboard, and the next idle pass takes up where
/// this one left off. The guards stand first, and they are
/// absolute: never inside a `net` conversation (the sending and
/// listening hands are not reentrant), never without a lease,
/// never on a card that was never raised — and a lease whose
/// time is spent is let go here, honestly, before any answering
/// is done in its name.
func netService() {
    if netConversation || !netRaised || !netLeaseHeld { return }
    if netLeaseExpiredNow() {
        netDropLease()
        return
    }
    var handled = 0
    while handled < 64 {
        let standing = netDescWord(netRxDescFrame, netRxNext, 1)
        if standing >> 32 & 1 == 0 { return }
        let length = Int(standing & 0xFFFF)
        let buffer = netRxBuffer(netRxNext)
        var answered = false
        if length <= netBufferBytes
            && netServiceArpTarget(buffer, length) {
            answered = netServiceSendArpReply(buffer, length)
            if answered { netCountArpAnswers += 1 }
        } else if length <= netBufferBytes
            && netServiceEchoTarget(buffer, length) {
            answered = netServiceSendEchoReply(buffer, length)
            if answered { netCountPingAnswers += 1 }
        }
        if !answered { netCountSteppedOver += 1 }
        netSetDescWord(netRxDescFrame, netRxNext, 1, 0)
        netWrite32(netRegRDT, UInt32(netRxNext))
        netRxNext = (netRxNext + 1) % netRingCount
        handled += 1
    }
}


/// net's vocabulary: the account's lines, in the plain words the
/// spec of the stone prescribes — what was found, the address the
/// card itself reported, the link's truth, the asking and its
/// count, the answer or its absence — with the numbers spoken
/// between them by the small hands below.
let netNoneLine: StaticString =
    "No network card was found on the PCI bus."
let netSilentLine: StaticString =
    "The network card was found, but it did not come up."
let netCardLabel: StaticString = "Network card: "
let netCard82540Line: StaticString =
    "Intel e1000 (82540EM), on the PCI bus."
let netCardFamilyLine: StaticString =
    "Intel e1000 family card, on the PCI bus."
let netMacLabel: StaticString = "Hardware address: "
let netLinkUpLine: StaticString = "Link: up."
let netLinkDownLine: StaticString = "Link: not up."
let netSentLabel: StaticString =
    "Sent: one packet asking the network for an address (DHCP discover, "
let netSentClose: StaticString = " bytes)."
let netSendFailedLine: StaticString =
    "The packet could not be sent."
let netPeriod: StaticString = "."
let netOfferLabel: StaticString = "Offer: the network offers us "
let netOfferMiddle: StaticString = "; the offer comes from "
let netRequestLabel: StaticString =
    "Sent: one packet taking the offered address (DHCP request, "
let netAckLabel: StaticString =
    "Answer: the network confirmed our lease (DHCP ack) from "
let netNakLabel: StaticString =
    "Answer: the network refused the lease (DHCP nak) from "
let netNoConfirmLine: StaticString =
    "No confirmation came back on the wire."
let netHoldNoneLine: StaticString = "We hold no address."
let netStandingLine: StaticString =
    "The lease stands; no new asking was made."
let netExpiredLine: StaticString =
    "The lease had run out, so the asking began again."
let netHoldLabel: StaticString = "Address: we hold "
let netMaskLabel: StaticString = "Subnet mask: "
let netMaskNoneLine: StaticString =
    "No subnet mask was named in the answer."
let netServerLabel: StaticString = "Lease server: "
let netGatewayLabel: StaticString = "Gateway: "
let netGatewayNoneLine: StaticString =
    "No gateway was named in the answer."
let netDnsServerLabel: StaticString = "DNS server: "
let netDnsServerNoneLine: StaticString =
    "No DNS server was named in the answer."
let netLeaseLabel: StaticString = "Lease length: "
let netLeaseSecondsClose: StaticString = " seconds."
let netLeaseNoneLine: StaticString =
    "The lease's length was not named in the answer."
let netArpLearnedLabel: StaticString =
    "Gateway ARP: learned the gateway's hardware address "
let netArpFailedLine: StaticString =
    "Gateway ARP: no reply came; the gateway's hardware address is not known."
let netArpNoneLine: StaticString =
    "Gateway ARP: no gateway was named, so no request was sent."
let netPingLabel: StaticString = "Gateway ping: answered in "
let netPingTicksClose: StaticString = " ticks."
let netPingFailedLine: StaticString = "Gateway ping: no answer came."
let netPingNoMacLine: StaticString =
    "Gateway ping: not sent - the gateway's hardware address is not known."
let netPingNoneLine: StaticString =
    "Gateway ping: no gateway was named, so no ping was sent."
let netDnsLabel: StaticString = "DNS: cardnull.com resolves to "
let netDnsFailedLine: StaticString =
    "DNS: no answer came for cardnull.com."
let netDnsNoneLine: StaticString =
    "DNS: no DNS server was named, so no name was asked."
let netDnsNoMacLine: StaticString =
    "DNS: not sent - the gateway's hardware address is not known."
let netProofLabel: StaticString = "Since the lease was taken: "
let netProofArpMiddle: StaticString = " ARP answers given, "
let netProofPingMiddle: StaticString = " ping answers given, "
let netProofGwMiddle: StaticString = " gateway pings answered, "
let netProofDnsClose: StaticString = " DNS answers received."
let netNoAnswerLine: StaticString =
    "No answer came back on the wire."
let netOneOtherLine: StaticString =
    "One other packet passed by; it was not the answer."
let netOthersLabel: StaticString = " other packets passed by; "
let netOthersClose: StaticString = "none was the answer."
let netHexDigits: StaticString = "0123456789ABCDEF"

/// Writes one byte as two hexadecimal digits, through the one
/// output door — the hardware address's own spelling.
func writeHexByte(_ value: UInt8) {
    writeChar(netHexDigits.utf8Start[Int(value >> 4)])
    writeChar(netHexDigits.utf8Start[Int(value & 0x0F)])
}

/// Writes the card's hardware address the way the world writes
/// it: six hex bytes, colon between.
func writeMacAddress() {
    var index = 0
    while index < 6 {
        if index > 0 { writeChar(0x3A) }   // :
        writeHexByte(netMacByte(index))
        index += 1
    }
}

/// Writes the gateway's hardware address the way the world
/// writes it: six hex bytes, colon between — the card's own
/// spelling, for the address ARP taught us.
func writeGatewayMacAddress() {
    var index = 0
    while index < 6 {
        if index > 0 { writeChar(0x3A) }   // :
        writeHexByte(netGwMacByte(index))
        index += 1
    }
}

/// Writes a packed IPv4 address — the highest byte first, as the
/// wire carries it — in the dotted words people read.
func writeIPAddress(_ value: UInt32) {
    writeNumber(UInt64((value >> 24) & 0xFF))
    writeChar(0x2E)   // .
    writeNumber(UInt64((value >> 16) & 0xFF))
    writeChar(0x2E)
    writeNumber(UInt64((value >> 8) & 0xFF))
    writeChar(0x2E)
    writeNumber(UInt64(value & 0xFF))
}

/// Spoken when a conversation's listening stepped over other
/// traffic: milestone 20's own words for it, kept — one frame
/// in its singular line, many in their counted one, none when
/// the wire carried nothing but the conversation itself.
func printNetOthers() {
    if netAwaitOthers == 1 {
        writeLine(netOneOtherLine)
    } else if netAwaitOthers > 1 {
        writeNumber(UInt64(netAwaitOthers))
        writeStatic(netOthersLabel)
        writeLine(netOthersClose)
    }
}

/// The standing truth of the lease, spoken the same way by a
/// fresh taking and by a later `net` that finds the lease
/// standing: the address we hold, the mask, the server the
/// lease came from, the gateway and the DNS server, and the
/// lease's length — each in its line when the ack named it,
/// and a plain word in its place when it did not. Nothing here
/// is invented: what stands in the books is what is spoken.
func printNetLease() {
    writeStatic(netHoldLabel)
    writeIPAddress(netAddress)
    writeLine(netPeriod)
    if netMaskKnown {
        writeStatic(netMaskLabel)
        writeIPAddress(netMask)
        writeLine(netPeriod)
    } else {
        writeLine(netMaskNoneLine)
    }
    writeStatic(netServerLabel)
    writeIPAddress(netServer)
    writeLine(netPeriod)
    if netGatewayKnown {
        writeStatic(netGatewayLabel)
        writeIPAddress(netGateway)
        writeLine(netPeriod)
    } else {
        writeLine(netGatewayNoneLine)
    }
    if netDnsKnown {
        writeStatic(netDnsServerLabel)
        writeIPAddress(netDns)
        writeLine(netPeriod)
    } else {
        writeLine(netDnsServerNoneLine)
    }
    if netLeaseKnown {
        writeStatic(netLeaseLabel)
        writeNumber(UInt64(netLeaseSeconds))
        writeLine(netLeaseSecondsClose)
    } else {
        writeLine(netLeaseNoneLine)
    }
}

/// The citizenship's tally since the lease was taken, in one
/// line: the answers we have given the network, and the answers
/// it has given our own askings — the proof the Terminal can
/// show for work the wire did while the shell stood idle.
func printNetProof() {
    writeStatic(netProofLabel)
    writeNumber(netCountArpAnswers)
    writeStatic(netProofArpMiddle)
    writeNumber(netCountPingAnswers)
    writeStatic(netProofPingMiddle)
    writeNumber(netCountGatewayPings)
    writeStatic(netProofGwMiddle)
    writeNumber(netCountDnsAnswers)
    writeLine(netProofDnsClose)
}

/// The originated exchanges of a taking (or a renewing): three
/// real conversations on the lease's new standing, each spoken
/// honestly, success or failure. The gateway is resolved by
/// ARP — nothing addressed to it can travel until its hardware
/// address is known. The gateway is then pinged, and the round
/// trip reckoned in heartbeat ticks from the sending to the
/// answer. And a real name is asked of the DNS server the ack
/// named, and its first A answer reported. An exchange that
/// cannot be begun says why it was not begun; one that is begun
/// and not answered says that.
func runNetExchanges() {
    if !netGatewayKnown {
        writeLine(netArpNoneLine)
        writeLine(netPingNoneLine)
    } else {
        var arpAnswered = false
        if netSend(length: netBuildArpRequest()) {
            arpAnswered = netAwait(netAwaitArp, 300) == 1
        }
        if arpAnswered {
            netGatewayMacKnown = true
            writeStatic(netArpLearnedLabel)
            writeGatewayMacAddress()
            writeLine(netPeriod)
        } else {
            writeLine(netArpFailedLine)
        }
        if netGatewayMacKnown {
            let pingLength = netBuildPing()
            netPingSentTick = ticks
            var pingAnswered = false
            if netSend(length: pingLength) {
                pingAnswered = netAwait(netAwaitPing, 300) == 1
            }
            if pingAnswered {
                netCountGatewayPings += 1
                writeStatic(netPingLabel)
                writeNumber(ticks - netPingSentTick)
                writeLine(netPingTicksClose)
            } else {
                writeLine(netPingFailedLine)
            }
        } else {
            writeLine(netPingNoMacLine)
        }
    }
    if !netDnsKnown {
        writeLine(netDnsNoneLine)
    } else if !netGatewayMacKnown {
        writeLine(netDnsNoMacLine)
    } else {
        var dnsAnswered = false
        if netSend(length: netBuildDnsQuery()) {
            dnsAnswered = netAwait(netAwaitDns, 300) == 1
        }
        if dnsAnswered {
            netCountDnsAnswers += 1
            writeStatic(netDnsLabel)
            writeIPAddress(netDnsResolved)
            writeLine(netPeriod)
        } else {
            writeLine(netDnsFailedLine)
        }
    }
}

/// net's work: the whole account, in order — under the
/// conversation's guard from its first step to its last, so
/// the citizenship service can never reach into its middle.
/// The finding first, and if the bus holds no card, the
/// absence is the whole answer. Then the raising — once, at
/// the first `net`; the card stays raised from then on — whose
/// failure is likewise spoken plainly and ends the command.
/// Then the account proper: the card's name as found (the
/// 82540EM named outright; another of the family named as
/// family), the hardware address out of the card's own mouth,
/// and the standing truth. A lease whose time is spent is let
/// go and the asking begins again, said plainly. A lease that
/// stands is reported as it stands — no new asking is made —
/// with its proof counters beside it. No lease standing, the
/// full handshake runs: the link waited for and spoken, the
/// discover sent and counted, the offer reported with its
/// addresses, the request sent and counted, and the ack — or
/// the nak, or the silence — answered with the truth: the
/// lease taken into the books with everything the ack named,
/// the originated exchanges run behind it, and the counters
/// spoken; or no address held, and why, in plain words.
func runNet() {
    netConversation = true
    runNetConversation()
    netConversation = false
}

func runNetConversation() {
    if !netFindCard() {
        writeLine(netNoneLine)
        return
    }
    if !netMapRegisters() || !netTakeFrames() {
        writeLine(netSilentLine)
        return
    }
    if !netRaised {
        if !netRaise() {
            writeLine(netSilentLine)
            return
        }
        netRaised = true
    }
    writeStatic(netCardLabel)
    writeLine(netDeviceID == 0x100E ? netCard82540Line
                                    : netCardFamilyLine)
    writeStatic(netMacLabel)
    writeMacAddress()
    writeLine(netPeriod)
    if netLeaseExpiredNow() {
        netDropLease()
        writeLine(netExpiredLine)
    }
    if netLeaseHeld {
        writeLine((netRead32(netRegSTATUS) & 0x2) != 0
                      ? netLinkUpLine : netLinkDownLine)
        writeLine(netStandingLine)
        printNetLease()
        printNetProof()
        return
    }
    if !netLinkUp() {
        writeLine(netLinkDownLine)
        writeLine(netNoAnswerLine)
        writeLine(netHoldNoneLine)
        return
    }
    writeLine(netLinkUpLine)
    netAwaitOthers = 0
    let discoverLength = netBuildDiscover()
    if !netSend(length: discoverLength) {
        writeLine(netSendFailedLine)
        writeLine(netHoldNoneLine)
        return
    }
    writeStatic(netSentLabel)
    writeNumber(UInt64(discoverLength))
    writeLine(netSentClose)
    if netAwait(netAwaitOffer, 500) != 1 {
        printNetOthers()
        writeLine(netNoAnswerLine)
        writeLine(netHoldNoneLine)
        return
    }
    netOfferAddress = netParsedYiaddr
    netOfferServer = netParsedSiaddr
    netOfferServerId = netParsedHasServerId ? netParsedServerId
                                            : netParsedSiaddr
    writeStatic(netOfferLabel)
    writeIPAddress(netOfferAddress)
    writeStatic(netOfferMiddle)
    writeIPAddress(netOfferServer)
    writeLine(netPeriod)
    let requestLength = netBuildRequest()
    if !netSend(length: requestLength) {
        writeLine(netSendFailedLine)
        writeLine(netHoldNoneLine)
        return
    }
    writeStatic(netRequestLabel)
    writeNumber(UInt64(requestLength))
    writeLine(netSentClose)
    let ackVerdict = netAwait(netAwaitAck, 500)
    printNetOthers()
    if ackVerdict == 2 {
        writeStatic(netNakLabel)
        writeIPAddress(netOfferServer)
        writeLine(netPeriod)
        writeLine(netHoldNoneLine)
        return
    }
    if ackVerdict != 1 {
        writeLine(netNoConfirmLine)
        writeLine(netHoldNoneLine)
        return
    }
    // The taking: the ack's own testimony into the books, each
    // answer with its presence, nothing invented. The address
    // is the ack's yiaddr — the offer's when, against the
    // standard, the ack leaves the field empty. The server is
    // its option 54 when it carried one, else its siaddr, else
    // the server that offered. A gateway or DNS address of
    // zero is no gateway and no server, and is kept as none.
    netAddress = netParsedYiaddr != 0 ? netParsedYiaddr
                                      : netOfferAddress
    netServer = netParsedHasServerId ? netParsedServerId
        : (netParsedSiaddr != 0 ? netParsedSiaddr : netOfferServer)
    netMask = netParsedMask
    netMaskKnown = netParsedHasMask
    netGateway = netParsedRouter
    netGatewayKnown = netParsedHasRouter && netParsedRouter != 0
    netDns = netParsedDns
    netDnsKnown = netParsedHasDns && netParsedDns != 0
    netLeaseSeconds = netParsedLease
    netLeaseKnown = netParsedHasLease
    netLeaseTakenTick = ticks
    netLeaseHeld = true
    netGatewayMacPacked = 0
    netGatewayMacKnown = false
    netCountArpAnswers = 0
    netCountPingAnswers = 0
    netCountGatewayPings = 0
    netCountDnsAnswers = 0
    netCountSteppedOver = 0
    writeStatic(netAckLabel)
    writeIPAddress(netServer)
    writeLine(netPeriod)
    printNetLease()
    runNetExchanges()
    printNetProof()
}

// ---------------------------------------------------------------------------
// The hard disk (milestone 21).
//
// The OS gains a place to keep things. Until now everything the
// kernel touched was read-only — the CD it boots from is a
// pressed disc, read sector by sector and never written — and
// everything a session made died with the power. This milestone
// adds the second drive: the hard disk, and with it writing,
// a filesystem of Cardnull's own, and an installer.
//
//   - The bus is the CD's own. The machines this kernel boots
//     on — the test rig and Tyler's alike — declare both drives
//     on the IDE interface of the chipset, and on this chipset
//     (the ICH9 in QEMU's q35) that interface is the AHCI
//     controller wearing its six ports: the CD answers on one
//     of them as an ATAPI device, signing 0xEB140101, and a
//     hard disk answers on another as an ATA device, signing
//     0x00000101. (The bench proved the shape: its scratch disk,
//     attached the same way, stands on the controller's port 0
//     while the CD stands on port 2.) So the driver is AHCI
//     again — a second port of the same controller, raised with
//     its own command fields, spoken to with the ATA commands
//     a disk answers: IDENTIFY DEVICE to know it, READ DMA and
//     WRITE DMA to move its sectors, FLUSH CACHE to make a
//     writing stand. The CD's port, its fields, and its packet
//     road are not touched by any of it. Legacy PIO ports are
//     not probed: there is no legacy port hardware on these
//     machines, and a driver for a bus that is not there would
//     be a fiction. Tyler's UTM configuration says it in as
//     many words — both of his drives wear Interface: IDE —
//     and the CD's AHCI raising has been the proof since
//     milestone 8 of what that interface means here.
//   - The raising is lazy: nothing at boot changes (the boot
//     report remains the CD's and the mouse's), and the first
//     hard-disk command raises the disk then, and keeps it.
//     Ports are tried in two passes — first a port that signs
//     itself an ATA disk with its link standing, then any
//     standing link that is not the CD's, with IDENTIFY itself
//     as the judge — and a packet device is refused wherever
//     it is met: the wall between the read-only CD and the
//     writable disk is not a convention, it is the signature
//     check and the command set. No code path in this section
//     can address the CD's port at all: every register address
//     is reckoned from hdPort, which the scan never sets to
//     the CD's port, and the CD's own driver is never called.
//   - The filesystem is Cardnull's own, small and documented
//     in docs/DISK.md: a superblock on sector 0 carrying the
//     mark "CARDNULL DISK 1", the disk's measure, and the
//     data's next free sector, proven by an FNV-1a checksum
//     over its own bytes — the feather's reckoning, come home;
//     a flat directory of 128 fixed entries on the sixteen
//     sectors after it (a name of up to 31 letters, a starting
//     sector, a length); and the files' data in unbroken runs
//     from sector 17, allotted in the order they arrive and
//     never moved. There is no deleting in this first shape:
//     space once given is given for the disk's life, and the
//     directory is the truth the commands read; the
//     superblock's file count is a mirror the writers keep.
//     A disk whose first sector is all zeros is blank; one
//     whose mark is absent is not a Cardnull disk yet; one
//     whose mark stands but whose checksum or measures do
//     not prove out is damaged — and is answered in that
//     word, never misread into confidence.
//
// The commands are seven: `disk` reports both drives and the
// hard disk's state; `format` makes a blank or foreign disk a
// Cardnull disk, behind a typed confirmation; `dsave` saves a
// line of words as a file; `dls` lists the disk's files;
// `dcat` reads one back; `install` — behind the same
// confirmation — formats the disk and copies the CD's own
// files onto it, the welcome and every program and feather,
// the kernel and the file bundle themselves among them, and
// writes INSTALLED.TXT to say what was done; and `bootable`
// — behind the same typed gate — prepares the disk to start
// the computer by itself (milestone 28): the filesystem moves
// behind a partition at sector 2048, our own boot image takes
// its place at sector 4 behind an MBR that points at the
// partition, and the BIOS-door bootloader learned to read the
// kernel and the bundle back off the disk they stand on. From
// that day the filesystem's sector numbers are reckoned from
// its home — sector 0 of the filesystem stands wherever the
// home stands, and on a plain disk the home is 0, so every
// disk made before this stone reads exactly as it always did.
// ---------------------------------------------------------------------------

/// A hard-disk sector's size: the ATA world's measure, four to
/// a CD sector.
let hdSectorBytes = 512

/// The disk's buses and geometry in the format's own words:
/// the directory's first sector, its length in sectors, the
/// data's first sector, one entry's size, the directory's
/// whole capacity, and a name's longest reach.
let hdDirStart: UInt64 = 1
let hdDirSectors: UInt64 = 16
let hdDataStart: UInt64 = 17
let hdEntryBytes = 64
let hdMaxFiles = 128
let hdNameCap = 31

/// The format's mark: fifteen letters standing at the head of
/// sector 0 of every Cardnull disk, the way CD001 stands at
/// the head of every CD this kernel reads.
let hdMagic: StaticString = "CARDNULL DISK 1"
let hdMagicLength = 15

/// Did the raising already run? The disk is raised once, at
/// the first hard-disk command, and kept for the session: a
/// drive does not arrive mid-sitting, and re-asking would
/// only disturb a port already standing.
var hdRaised = false

/// Did an ATA hard disk answer? Until one does, every
/// hard-disk command answers with the absence, plainly.
var hdFound = false

/// The disk's place: its port on the disc's own controller.
/// The CD's port is ahciPort, and the scan below never sets
/// hdPort to it — the two drivers share a controller and
/// nothing else.
var hdPort = 0

/// The disk port's own DMA fields, taken from the frame
/// allocator at the raising and kept for the kernel's life:
/// a command list (with the received-FIS field at its 0x400,
/// as the CD's port keeps), a command table, and one data
/// field — a whole frame of which one sector's worth is ever
/// in flight. Their addresses are physical as well as virtual,
/// the identity map's gift, which is what a DMA engine must
/// be told. They are the disk's, not the CD's: the ATAPI
/// driver's fields stand untouched beside them.
var hdListFrame: UInt64 = 0
var hdTableFrame: UInt64 = 0
var hdDataFrame: UInt64 = 0

/// The disk's own name for itself, from its IDENTIFY answer:
/// up to forty characters in a heap scratch, with its reckoned
/// length beside it — the disc model's own arrangement, kept a
/// second time because the two drives are two drives.
var hdModelAddress: UInt64 = 0
var hdModelLength = 0

/// The disk's measure, from the same answer: its whole count
/// of 512-byte sectors, and whether its reach needs the
/// 48-bit commands (a disk wider than 2^28 sectors — 128 GiB)
/// or the classic 28-bit pair serves.
var hdSectors: UInt64 = 0
var hdWide = false

/// The sector field, as the pointer every disk hand shares.
@inline(__always)
func hdData() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(hdDataFrame))!
}

/// One port's register address, any port: the reckoning
/// ahciReg makes for the CD's chosen port, spoken generally.
/// The CD's own helper stands untouched; this one exists so
/// the scan can ask after ports it has not chosen.
@inline(__always)
func ahciPortReg(_ port: Int, _ offset: UInt64) -> UInt64 {
    ahciBase + 0x100 + UInt64(port) * 0x80 + offset
}

/// The disk port's register addresses, reckoned from hdPort
/// alone — the shape of the safety this section promises:
/// no address in this section is ever reckoned from the
/// CD's port.
@inline(__always)
func hdReg(_ offset: UInt64) -> UInt64 {
    ahciPortReg(hdPort, offset)
}

/// Finds the controller and maps its registers, when the
/// CD's raising did not already leave them standing (the
/// machine may carry a disk and no CD at all). The scan is
/// the disc section's own — the controller by its class,
/// mass storage, SATA, the AHCI interface, its fifth
/// register the door — spoken a second time because the
/// raising that owns it chooses its port as it goes and
/// cannot be half-run for another's benefit.
func hdEnsureController() -> Bool {
    if ahciBase != 0 { return true }
    var device: UInt32 = 0
    var foundDevice: UInt32 = 0
    var foundFunction: UInt32 = 0
    var abar: UInt32 = 0
    while device < 32 && abar == 0 {
        var function: UInt32 = 0
        while function < 8 {
            let id = pciConfigRead32(device, function, 0)
            if id & 0xFFFF != 0xFFFF {
                let classes = pciConfigRead32(device, function,
                                              0x08)
                if classes >> 24 == 0x01
                    && (classes >> 16) & 0xFF == 0x06
                    && (classes >> 8) & 0xFF == 0x01 {
                    let bar = pciConfigRead32(device, function,
                                              0x24) & 0xFFFFFFF0
                    if bar != 0 {
                        abar = bar
                        foundDevice = device
                        foundFunction = function
                        break
                    }
                }
            }
            function += 1
        }
        device += 1
    }
    if abar == 0 { return false }
    let commandWord = pciConfigRead32(foundDevice, foundFunction,
                                      0x04)
    pciConfigWrite32(foundDevice, foundFunction, 0x04,
                     commandWord | 0x06)
    ahciBase = UInt64(abar)
    if pagingReady {
        let regFlags = ptePresent | pteWritable | pteNoExecute
        if !mapPage(ahciBase, regFlags) { return false }
        if !mapPage(ahciBase + 0x1000, regFlags) { return false }
        cardnullInvlpg(ahciBase)
        cardnullInvlpg(ahciBase + 0x1000)
    }
    mmioWrite32(ahciBase + 0x04,
                mmioRead32(ahciBase + 0x04) | 0x80000000)
    return true
}

/// Stills one port: its engine stopped and its busy lamp out,
/// the courtesy the CD's raising performs on its own port —
/// spoken for any port, because the scan may raise a port it
/// then declines, and a declined port is put back to rest.
func hdStillPort(_ port: Int) {
    let cmd = mmioRead32(ahciPortReg(port, 0x18))
    mmioWrite32(ahciPortReg(port, 0x18), cmd & ~0x11)
    var waited = 0
    while mmioRead32(ahciPortReg(port, 0x18)) & 0x8000 != 0 {
        waited += 1
        if waited >= discWaitLimit { return }
    }
}

/// Gives the disk's port its fields and starts it: the same
/// ceremony the CD's port was raised with — stilled first,
/// its command list and received-FIS field and command table
/// laid in frames of its own, its error and interrupt words
/// cleared, its engine started — and the last wait on the
/// link standing and the drive neither busy nor asking.
func hdRaisePort() -> Bool {
    hdStillPort(hdPort)
    if hdListFrame == 0 {
        hdListFrame = allocFrame()
        hdTableFrame = allocFrame()
        hdDataFrame = allocFrame()
    }
    if hdListFrame == 0 || hdTableFrame == 0 || hdDataFrame == 0 {
        return false
    }
    let listBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdListFrame))!
    var index = 0
    while index < 4096 {
        listBytes[index] = 0
        index += 1
    }
    let tableBytes = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdTableFrame))!
    index = 0
    while index < 4096 {
        tableBytes[index] = 0
        index += 1
    }
    mmioWrite32(hdReg(0x00),
                UInt32(hdListFrame & 0xFFFFFFFF))
    mmioWrite32(hdReg(0x04), UInt32(hdListFrame >> 32))
    let fisField = hdListFrame + 0x400
    mmioWrite32(hdReg(0x08), UInt32(fisField & 0xFFFFFFFF))
    mmioWrite32(hdReg(0x0C), UInt32(fisField >> 32))
    mmioWrite32(hdReg(0x30), 0xFFFFFFFF)
    mmioWrite32(hdReg(0x10), 0xFFFFFFFF)
    var cmd = mmioRead32(hdReg(0x18))
    cmd |= 0x10 | 0x02 | 1 << 24
    mmioWrite32(hdReg(0x18), cmd)
    mmioWrite32(hdReg(0x18), cmd | 0x1)
    var waited = 0
    while true {
        if mmioRead32(hdReg(0x28)) & 0x0F == 3
            && mmioRead32(hdReg(0x20)) & 0x88 == 0 {
            return true
        }
        waited += 1
        if waited >= discWaitLimit { return false }
    }
}

/// Prepares the disk port's one slot for an ATA command: the
/// command table is emptied, the register frame is laid at its
/// head — the type that says "this writes the command
/// register", the command, the address spread across the
/// frame's LBA fields in the 48-bit order (the low three bytes
/// in their places, the high three in the frame's second
/// reach, the device byte carrying the LBA mark), and the
/// count — one data descriptor is laid at the table's 0x80
/// naming the sector field, and the slot's header is written
/// with the write mark when the command carries data to the
/// disk. A command with no data at all — the flush — is
/// prepared with no descriptor, and says so in its header.
func hdPrepare(_ command: UInt8, _ write: Bool, _ lba: UInt64,
               _ sectors: Int) -> Bool {
    if hdTableFrame == 0 { return false }
    let table = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdTableFrame))!
    var index = 0
    while index < 0x100 {
        table[index] = 0
        index += 1
    }
    table[0] = 0x27
    table[1] = 0x80
    table[2] = command
    table[3] = 0
    table[4] = UInt8(lba & 0xFF)
    table[5] = UInt8((lba >> 8) & 0xFF)
    table[6] = UInt8((lba >> 16) & 0xFF)
    table[7] = 0x40
    table[8] = UInt8((lba >> 24) & 0xFF)
    table[9] = UInt8((lba >> 32) & 0xFF)
    table[10] = UInt8((lba >> 40) & 0xFF)
    table[11] = 0
    table[12] = UInt8(sectors & 0xFF)
    table[13] = UInt8((sectors >> 8) & 0xFF)
    var flags: UInt32 = 5
    if sectors > 0 {
        let words = UnsafeMutablePointer<UInt32>(
            bitPattern: UInt(hdTableFrame))!
        words[0x80 / 4] = UInt32(hdDataFrame & 0xFFFFFFFF)
        words[0x80 / 4 + 1] = UInt32(hdDataFrame >> 32)
        words[0x80 / 4 + 3] = UInt32(sectors * hdSectorBytes - 1)
            | 0x80000000
        flags |= 1 << 16
    }
    if write { flags |= 1 << 6 }
    let header = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(hdListFrame))!
    header[0] = flags
    header[1] = 0
    header[2] = UInt32(hdTableFrame & 0xFFFFFFFF)
    header[3] = UInt32(hdTableFrame >> 32)
    return true
}

/// Fires the prepared slot and waits for the controller to
/// hand it back: the disk port's own firing, mirroring the
/// CD's — completion is the slot's bit clearing, a task-file
/// error refuses the wait, and the count the controller
/// reports must be the count that was asked for, in full.
func hdFire(_ byteCount: Int) -> Bool {
    mmioWrite32(hdReg(0x10), 0xFFFFFFFF)
    mmioWrite32(hdReg(0x38), 1)
    var waited = 0
    while mmioRead32(hdReg(0x38)) & 1 != 0 {
        if mmioRead32(hdReg(0x10)) & 0x40000000 != 0 {
            return false
        }
        waited += 1
        if waited >= discWaitLimit { return false }
    }
    if mmioRead32(hdReg(0x10)) & 0x40000000 != 0 { return false }
    if mmioRead32(hdReg(0x20)) & 0x01 != 0 { return false }
    let header = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(hdListFrame))!
    return header[1] == UInt32(byteCount)
}

/// Asks the raised device its name and measure: IDENTIFY
/// DEVICE, the command an ATA disk answers directly. The
/// answer must not call itself a packet device (the
/// configuration word's top two bits, 10 binary, are an
/// ATAPI signature — such a device is refused, here as
/// everywhere in this section), it must speak LBA, and it
/// must own at least one sector. The name is words 27 to 46
/// of the answer, swapped back pair by pair as the CD's
/// name was; the measure is the 28-bit count, widened by
/// the 48-bit count when the disk keeps one.
func hdIdentify() -> Bool {
    if !hdPrepare(0xEC, false, 0, 1) { return false }
    if !hdFire(hdSectorBytes) { return false }
    let buffer = hdData()
    if discU16(buffer, 0) >> 14 == 2 { return false }
    if discU16(buffer, 98) & 0x0200 == 0 { return false }
    if hdModelAddress != 0 {
        let model = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(hdModelAddress))!
        var length = 0
        var index = 0
        while index < 40 {
            let byte = buffer[54 + (index & ~1) + (1 - (index & 1))]
            model[index] = byte
            if byte != 0x20 && byte != 0 { length = index + 1 }
            index += 1
        }
        hdModelLength = length
    }
    var total = UInt64(discU32(buffer, 120))
    if discU16(buffer, 166) & 0x0400 != 0 {
        let wide = UInt64(discU16(buffer, 200))
            | UInt64(discU16(buffer, 202)) << 16
            | UInt64(discU16(buffer, 204)) << 32
            | UInt64(discU16(buffer, 206)) << 48
        if wide != 0 { total = wide }
    }
    if total == 0 { return false }
    hdSectors = total
    hdWide = total > 0x0FFFFFFF
    return true
}

/// Tries one port for the disk: raises it, asks its name,
/// and keeps it if the answer is a disk's. A port that fails
/// is stilled again and left as it was found.
func hdTryPort(_ port: Int) -> Bool {
    hdPort = port
    if hdRaisePort() && hdIdentify() {
        hdFound = true
        return true
    }
    hdStillPort(port)
    return false
}

/// Raises the hard disk, once, at the first asking: takes
/// the scratches, stands the controller if the CD's raising
/// did not, and walks the ports. The CD's port is passed
/// over by number — it is not the disk, and this section
/// never addresses it. A first pass takes a port that signs
/// itself an ATA disk with its link standing; a second pass
/// offers any other standing link to IDENTIFY's judgment,
/// in case a device is slow to sign its name.
func hdRaise() {
    if hdRaised { return }
    hdRaised = true
    if hdModelAddress == 0 {
        hdModelAddress = heapAlloc(48)
        hdConfirmAddress = heapAlloc(hdConfirmCapacity)
        if hdModelAddress == 0 || hdConfirmAddress == 0 {
            return
        }
    }
    if !hdEnsureController() { return }
    let present = mmioRead32(ahciBase + 0x0C)
    let cdPort = discDriveFound ? ahciPort : -1
    var port = 0
    while port < 32 {
        if port != cdPort
            && present & (UInt32(1) << UInt32(port)) != 0
            && mmioRead32(ahciPortReg(port, 0x24)) == 0x00000101
            && mmioRead32(ahciPortReg(port, 0x28)) & 0x0F == 3 {
            if hdTryPort(port) { return }
        }
        port += 1
    }
    port = 0
    while port < 32 {
        if port != cdPort
            && present & (UInt32(1) << UInt32(port)) != 0
            && mmioRead32(ahciPortReg(port, 0x28)) & 0x0F == 3 {
            if hdTryPort(port) { return }
        }
        port += 1
    }
}

/// Moves one sector between the disk and the sector field,
/// with the patience the CD's reader taught: three attempts,
/// a breath between them. The command is the DMA pair the
/// disk's width calls for — the 48-bit road on a wide disk,
/// the classic one on a narrow — because over AHCI the
/// controller's engine is the only road data travels; there
/// is no handing sectors through a port, as the old IDE
/// world allowed, on a controller that speaks in frames.
func hdTransfer(_ write: Bool, _ lba: UInt64) -> Bool {
    let command: UInt8
    if write {
        command = hdWide ? 0x35 : 0xCA
    } else {
        command = hdWide ? 0x25 : 0xC8
    }
    var attempt = 0
    while attempt < 3 {
        if hdPrepare(command, write, lba, 1)
            && hdFire(hdSectorBytes) {
            return true
        }
        atapiBreath(200000)
        attempt += 1
    }
    return false
}

/// The filesystem's home: the disk sector its own sector 0
/// stands on (milestone 28). On a plain disk the home is 0
/// and nothing changes; on a bootable disk the filesystem
/// stands behind a partition and the home is that partition's
/// first sector. Every sector number the filesystem speaks —
/// the superblock, the directory, a file's run — is reckoned
/// from the home, and the two hands below add it on the way
/// to the drive. hdReadState finds the home fresh at every
/// judging; the raw road (hdTransfer itself) is how the
/// judging reads, and how `bootable` writes the MBR and the
/// boot image at the disk's true head before any home
/// exists there.
var hdHome: UInt64 = 0

/// True when the standing disk is a prepared one — an MBR and
/// a Cardnull partition at its head, the boot image beside
/// them — so the disk can start the computer by itself.
/// Judged fresh by hdReadState with the home.
var hdBootable = false

/// Reads the sector at the home-relative address into the
/// sector field.
func hdReadSector(_ lba: UInt64) -> Bool {
    hdTransfer(false, lba + hdHome)
}

/// Writes the sector field to the home-relative address.
func hdWriteSector(_ lba: UInt64) -> Bool {
    hdTransfer(true, lba + hdHome)
}

/// Makes the disk's writings stand: FLUSH CACHE, the command
/// by which the disk itself promises its platters (or its
/// memory of them) hold what was written. It carries no
/// data, so its preparation names no descriptor and its
/// completion is counted in zero bytes.
func hdFlush() -> Bool {
    if !hdPrepare(hdWide ? 0xEA : 0xE7, false, 0, 0) {
        return false
    }
    return hdFire(0)
}

/// Little-endian words laid in, and read back from, the
/// sector field: the disc section's readers serve any field,
/// and these writers are their companions — the format's
/// numbers stand on the disk in the order the CD's format
/// taught this kernel to expect.
func hdPut32(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int, _ value: UInt32) {
    buffer[offset] = UInt8(value & 0xFF)
    buffer[offset + 1] = UInt8((value >> 8) & 0xFF)
    buffer[offset + 2] = UInt8((value >> 16) & 0xFF)
    buffer[offset + 3] = UInt8((value >> 24) & 0xFF)
}

func hdPut64(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int, _ value: UInt64) {
    hdPut32(buffer, offset, UInt32(value & 0xFFFFFFFF))
    hdPut32(buffer, offset + 4, UInt32(value >> 32))
}

func hdGet64(_ buffer: UnsafeMutablePointer<UInt8>,
             _ offset: Int) -> UInt64 {
    UInt64(discU32(buffer, offset))
        | UInt64(discU32(buffer, offset + 4)) << 32
}

/// The superblock's checksum: FNV-1a over the sector's first
/// 504 bytes, the feather's reckoning exactly — the offset
/// basis, each byte folded in and the whole multiplied by
/// the prime — with the checksum itself standing in the
/// sector's last eight bytes, outside its own reckoning.
func hdChecksum(_ buffer: UnsafeMutablePointer<UInt8>) -> UInt64 {
    var hash: UInt64 = 0xCBF29CE484222325
    var index = 0
    while index < 504 {
        hash ^= UInt64(buffer[index])
        hash = hash &* 0x00000100000001B3
        index += 1
    }
    return hash
}

/// The disk's states, as the commands answer them: no disk
/// at all; a disk that will not answer; a blank disk, whose
/// first sector is all zeros; a foreign disk, written but
/// not with Cardnull's mark; a damaged disk, whose mark
/// stands but does not prove out; and a Cardnull disk,
/// ready. The numbers are only the section's own shorthand.
let hdStateAbsent = 0
let hdStateSilent = 1
let hdStateBlank = 2
let hdStateForeign = 3
let hdStateDamaged = 4
let hdStateReady = 5

/// The superblock's testimony, when the state is ready: the
/// disk's whole measure as the format recorded it, and the
/// data's next free sector — the two numbers every writer
/// needs, refreshed by every reading of the state, because
/// the sector is re-read each time and never trusted from
/// memory.
var hdSbTotal: UInt64 = 0
var hdSbNextFree: UInt64 = 0

/// Proves the superblock standing in the sector field: the
/// checksum, the version, and the geometry — the measure it
/// claims checked against the measure IDENTIFY gave. A disk
/// claiming more sectors than it owns, a data field beginning
/// anywhere but the format's place, or a next-free sector
/// outside the disk's reach is damage, whatever its checksum
/// says. On a proof, the superblock's testimony is kept and
/// the state is ready; the field's bytes are the caller's to
/// have read in.
func hdProveSuperblock() -> Int {
    let buffer = hdData()
    if hdChecksum(buffer) != hdGet64(buffer, 504) {
        return hdStateDamaged
    }
    if discU32(buffer, 16) != 1 { return hdStateDamaged }
    let total = hdGet64(buffer, 24)
    let nextFree = UInt64(discU32(buffer, 48))
    if total == 0 || total > hdSectors
        || UInt64(discU32(buffer, 40)) != hdDataStart
        || nextFree < hdDataStart || nextFree > total {
        return hdStateDamaged
    }
    hdSbTotal = total
    hdSbNextFree = nextFree
    return hdStateReady
}

/// True when the sector field's head carries the format's
/// mark, letter for letter.
func hdFieldHasMagic() -> Bool {
    let buffer = hdData()
    var index = 0
    while index < hdMagicLength {
        if buffer[index] != hdMagic.utf8Start[index] {
            return false
        }
        index += 1
    }
    return true
}

/// Reads the disk's state fresh, and finds its home first
/// (milestone 28). The judging reads the disk's true first
/// sector by the raw road, with the home forgotten until it
/// is found: all zeros is a blank disk, the mark standing at
/// the head is a plain disk judged exactly as it always was,
/// and anything else is asked one more question — is it an
/// MBR, signed 55 AA at its tail, carrying a partition of
/// Cardnull's own type (0xCA)? If it is, the sector that
/// partition names is read raw and judged by the same proof:
/// the mark and the proof standing there make the disk a
/// prepared one, its home that sector, and its next-free
/// reckoning must fit inside both the partition and the
/// disk. A named sector without the mark is foreign ground;
/// a named sector whose mark does not prove out is damaged,
/// in the same words as ever. No MBR match is foreign, as
/// ever. Every command judges before it touches a sector,
/// so the home is always the standing one when the
/// home-relative hands are used.
func hdReadState() -> Int {
    if !hdFound { return hdStateAbsent }
    hdHome = 0
    hdBootable = false
    if !hdTransfer(false, 0) { return hdStateSilent }
    let buffer = hdData()
    var any = false
    var index = 0
    while index < hdSectorBytes {
        if buffer[index] != 0 { any = true; break }
        index += 1
    }
    if !any { return hdStateBlank }
    if hdFieldHasMagic() {
        return hdProveSuperblock()
    }
    if buffer[510] != 0x55 || buffer[511] != 0xAA {
        return hdStateForeign
    }
    var candidate: UInt64 = 0
    var partitionLength: UInt64 = 0
    var entry = 0
    while entry < 4 {
        let base = 446 + entry * 16
        if buffer[base + 4] == 0xCA {
            candidate = UInt64(discU32(buffer, base + 8))
            partitionLength = UInt64(discU32(buffer, base + 12))
            break
        }
        entry += 1
    }
    if entry >= 4 || candidate == 0 { return hdStateForeign }
    if !hdTransfer(false, candidate) { return hdStateSilent }
    if !hdFieldHasMagic() { return hdStateForeign }
    if hdProveSuperblock() != hdStateReady {
        return hdStateDamaged
    }
    if candidate + hdSbNextFree > hdSectors
        || partitionLength < hdSbNextFree {
        return hdStateDamaged
    }
    hdHome = candidate
    hdBootable = true
    return hdStateReady
}

/// The directory scan's findings, kept in globals as the
/// house keeps such books: how many entries stand used, the
/// first free slot (or -1 when the directory is full), and —
/// when a name is being sought in the name scratch — the
/// slot that holds it, with its start and length beside.
var hdEntryCount = 0
var hdFreeSlot = -1
var hdFoundSlot = -1
var hdFoundStart: UInt32 = 0
var hdFoundLength: UInt32 = 0

/// Walks the whole directory, sector by sector, and reckons
/// the scan's findings. When `seekLength` is not zero, the
/// name it names — standing in the path scratch from
/// `seekStart`, capitals folded — is sought among the
/// entries, whose own names are folded for the meeting, the
/// way every name in this house is matched. A read the disk
/// refuses ends the walk in failure, and the findings are
/// not trusted.
func hdScanDirectory(_ seekStart: Int, _ seekLength: Int) -> Bool {
    hdEntryCount = 0
    hdFreeSlot = -1
    hdFoundSlot = -1
    hdFoundStart = 0
    hdFoundLength = 0
    let seek = discPath()
    var slot = 0
    var dirSector: UInt64 = 0
    while dirSector < hdDirSectors {
        if !hdReadSector(hdDirStart + dirSector) { return false }
        let buffer = hdData()
        var inSector = 0
        while inSector < Int(hdSectorBytes) / hdEntryBytes {
            let base = inSector * hdEntryBytes
            if buffer[base] == 0 {
                if hdFreeSlot < 0 { hdFreeSlot = slot }
            } else {
                hdEntryCount += 1
                if seekLength > 0 && hdFoundSlot < 0 {
                    var length = 0
                    while length < 32
                        && buffer[base + 1 + length] != 0 {
                        length += 1
                    }
                    if length == seekLength {
                        var matched = true
                        var index = 0
                        while index < length {
                            if featherFold(buffer[base + 1 + index])
                                != featherFold(
                                    seek[seekStart + index]) {
                                matched = false
                                break
                            }
                            index += 1
                        }
                        if matched {
                            hdFoundSlot = slot
                            hdFoundStart = discU32(buffer,
                                                   base + 32)
                            hdFoundLength = discU32(buffer,
                                                    base + 36)
                        }
                    }
                }
            }
            inSector += 1
            slot += 1
        }
        dirSector += 1
    }
    return true
}

/// Writes one directory entry: the directory's own sector is
/// read, the entry laid in its place — the used mark, the
/// name in its field with zeros after it, the start and the
/// length — and the sector written back. The name's source
/// is any field the caller names: the path scratch for a
/// save, the CD's sector buffer for the installer's copies,
/// a standing string for the installer's own note.
func hdWriteEntry(_ slot: Int,
                  _ nameFrom: UnsafePointer<UInt8>,
                  _ nameStart: Int, _ nameLength: Int,
                  _ start: UInt32, _ length: UInt32) -> Bool {
    let dirSector = hdDirStart + UInt64(slot)
        / UInt64(Int(hdSectorBytes) / hdEntryBytes)
    if !hdReadSector(dirSector) { return false }
    let buffer = hdData()
    let base = (slot % (Int(hdSectorBytes) / hdEntryBytes))
        * hdEntryBytes
    var index = 0
    while index < hdEntryBytes {
        buffer[base + index] = 0
        index += 1
    }
    buffer[base] = 1
    index = 0
    while index < nameLength && index < 32 {
        buffer[base + 1 + index] = nameFrom[nameStart + index]
        index += 1
    }
    hdPut32(buffer, base + 32, start)
    hdPut32(buffer, base + 36, length)
    return hdWriteSector(dirSector)
}

/// Writes the superblock: the mark, the version, the
/// sector's measure, the disk's measure, the directory's
/// place and length, the data's place, the file count the
/// caller swears to, and the next free sector — then the
/// checksum over all of it, and the sector written. The
/// superblock is written last in every making, after the
/// data and the directory stand, so the disk's head never
/// promises what its body has not yet performed.
func hdWriteSuperblock(_ count: UInt32,
                       _ nextFree: UInt64) -> Bool {
    let buffer = hdData()
    var index = 0
    while index < hdSectorBytes {
        buffer[index] = 0
        index += 1
    }
    index = 0
    while index < hdMagicLength {
        buffer[index] = hdMagic.utf8Start[index]
        index += 1
    }
    hdPut32(buffer, 16, 1)
    hdPut32(buffer, 20, UInt32(hdSectorBytes))
    hdPut64(buffer, 24, hdSectors)
    hdPut32(buffer, 32, UInt32(hdDirStart))
    hdPut32(buffer, 36, UInt32(hdDirSectors))
    hdPut32(buffer, 40, UInt32(hdDataStart))
    hdPut32(buffer, 44, count)
    hdPut32(buffer, 48, UInt32(nextFree))
    hdPut64(buffer, 504, hdChecksum(buffer))
    return hdWriteSector(0)
}

/// Formats the disk: the directory's sixteen sectors zeroed
/// (a stale name must never survive into a new making), the
/// superblock written over an empty field, the writings made
/// to stand, and the state read back as the proof — a format
/// is claimed only when the disk itself answers "ready" to
/// the asking.
func hdFormat() -> Bool {
    // Judge first, and let the judging find the home: on a
    // prepared disk the format is made inside the partition,
    // and the MBR, the boot image, and the partition's word
    // stand untouched at the disk's head (milestone 28).
    _ = hdReadState()
    let buffer = hdData()
    var index = 0
    while index < hdSectorBytes {
        buffer[index] = 0
        index += 1
    }
    var sector: UInt64 = 0
    while sector < hdDirSectors {
        if !hdWriteSector(hdDirStart + sector) { return false }
        sector += 1
    }
    if !hdWriteSuperblock(0, hdDataStart) { return false }
    if !hdFlush() { return false }
    return hdReadState() == hdStateReady
}

/// The confirmation's scratch: a heap field of 64 bytes, taken
/// at the disk's raising, holding the one typed word a
/// dangerous command waits for. Sixty-four is room and to
/// spare for a word like FORMAT; a longer typing is simply
/// not taken in, and cannot match.
var hdConfirmAddress: UInt64 = 0
let hdConfirmCapacity = 64

/// The confirmation scratch, as a pointer.
@inline(__always)
func hdConfirmBuffer() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(hdConfirmAddress))!
}

/// Reads one typed line at a dangerous command's asking,
/// with the shell's own hands: shift and caps kept as the
/// shell keeps them, each taken character echoed through the
/// one output door, Backspace stepping back over the typing
/// (and never past it — the command's own words above are
/// not the typist's to erase), Enter closing the line, and
/// Esc giving the whole asking up. Between keys the kernel
/// rests in `hlt` as the shell rests. Returns the line's
/// length, or -1 when Esc gave it up.
func hdReadConfirmation() -> Int {
    let buffer = hdConfirmBuffer()
    var length = 0
    var extended = false
    while true {
        if let code = nextScancode() {
            if extended {
                extended = false
                continue
            }
            if code == 0xE0 {
                extended = true
                continue
            }
            switch code {
            case 0x2A, 0x36:            // Shift pressed
                shiftHeld = true
            case 0xAA, 0xB6:            // Shift released
                shiftHeld = false
            case 0x3A:                  // Caps Lock
                capsLock = !capsLock
            case 0x1C:                  // Enter: the word stands
                writeNewline()
                return length
            case 0x01:                  // Esc: given up
                writeNewline()
                return -1
            case 0x0E:                  // Backspace
                if length > 0 {
                    length -= 1
                    backspace()
                }
            case 0x80 ... 0xFF:         // releases: not our affair
                break
            default:
                let character = ascii(forScancode: code)
                if character != 0 && length < hdConfirmCapacity {
                    buffer[length] = character
                    length += 1
                    writeChar(character)
                }
            }
        } else {
            cardnullHltOnce()
        }
    }
}

/// True when the confirmation's typing is exactly the word
/// the command demanded — capitals folded on the typing's
/// side, as the shell folds its commands, and no forgiveness
/// of extra letters: the word is the gate, and the gate is
/// the whole word.
func hdConfirmationMatches(_ word: StaticString) -> Bool {
    let buffer = hdConfirmBuffer()
    var length = 0
    while word.utf8Start[length] != 0 { length += 1 }
    let typed = hdReadConfirmation()
    if typed != length { return false }
    var index = 0
    while index < length {
        if featherFold(buffer[index]) != word.utf8Start[index] {
            return false
        }
        index += 1
    }
    return true
}

/// The words a dangerous command may demand.
let hdFormatWord: StaticString = "format"
let hdInstallWord: StaticString = "install"
let hdBootableWord: StaticString = "bootable"

/// Prints the disk's own name for itself — or, when it gave
/// none worth repeating, the plain standing word — through
/// the output door.
func hdWriteModel() {
    if hdModelLength > 0 && hdModelAddress != 0 {
        let model = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(hdModelAddress))!
        var index = 0
        while index < hdModelLength {
            writeChar(model[index])
            index += 1
        }
    } else {
        writeStatic(hdGenericName)
    }
}

/// The disk commands' shared vocabulary: the absence, the
/// states, the gates' words, and the refusals — in the plain
/// words the stone prescribes, with the numbers spoken
/// between them by writeNumber.
let hdGenericName: StaticString = "ATA hard disk"
let hdNoDiskLine: StaticString = "No hard disk is attached."
let hdCdLabel: StaticString = "The disc drive: "
let hdCdSuffix: StaticString = " - it is read-only, as ever."
let hdCdAbsentLine: StaticString =
    "The disc drive: no CD-ROM drive answered."
let hdDiskLabel: StaticString = "Hard disk: "
let hdMiBWord: StaticString = " MiB ("
let hdBytesClose: StaticString = " bytes)."
let hdStateBlankLine: StaticString =
    "  It is blank: nothing on it is Cardnull's yet."
let hdStateForeignLine: StaticString =
    "  It is not a Cardnull disk yet."
let hdStateDamagedLine: StaticString =
    "  Its Cardnull mark stands, but the mark does not prove out - the disk is damaged."
let hdStateSilentLine: StaticString =
    "  It did not answer when it was asked."
let hdReadyLabel: StaticString = "  A Cardnull disk: "
let hdReadyFilesWord: StaticString = " files stand on it, and "
let hdReadyFileWord: StaticString = " file stands on it, and "
let hdReadyRoomClose: StaticString = " bytes of room are left."
let hdNotReadyLine: StaticString =
    "The hard disk is not a Cardnull disk yet. format makes it one."
let hdSilentAnswerLine: StaticString =
    "The hard disk did not answer."
let hdWriteFailedLine: StaticString =
    "The disk refused a writing. What stands on it now is not promised; format can make it whole again."
let hdAbortedLine: StaticString =
    "Nothing was written. The disk stands exactly as it was."
let hdYourWordLabel: StaticString = "Your word: "
let hdFormatWarnLabel: StaticString =
    "format will erase everything on the hard disk ("
let hdFormatWarnClose: StaticString = ")."
let hdCdUntouchedLine: StaticString =
    "The CD is never touched: it cannot be written at all."
let hdFormatAskLine: StaticString =
    "Type FORMAT and press Enter to erase it and make it a Cardnull disk. Anything else gives up, and nothing is written."
let hdFormattedLabel: StaticString =
    "The disk is formatted: an empty Cardnull disk, with room for "
let hdFormattedClose: StaticString = " files."
let hdInstallWarnLabel: StaticString =
    "install will erase everything on the hard disk ("
let hdInstallAskLine: StaticString =
    "Type INSTALL and press Enter to erase it and install. Anything else gives up, and nothing is written."
let hdInstallFromLine: StaticString =
    "Then the disc's own files - the welcome, every program, every feather, and Cardnull itself: the kernel and the bundle - are copied onto it."
let hdInstallFromBundleLine: StaticString =
    "Then the files carried in memory - the welcome, every program, every feather - are copied onto it, and the kernel and the bundle themselves from the disc's BOOT folder."
let hdInstalledMiddleBundle: StaticString =
    " files copied from memory and the disc, and INSTALLED.TXT written."
let hdNoSourceLine: StaticString =
    "There is no disc to install from."
let hdInstalledLabel: StaticString = "Installed: "
let hdInstalledMiddle: StaticString =
    " files copied from the disc, and INSTALLED.TXT written."
let hdHoldsLabel: StaticString = "The disk now holds "
let hdHoldsFilesClose: StaticString = " files."
let hdHoldsFileClose: StaticString = " file."
let hdInstallStoppedLine: StaticString =
    "The install stopped part-way. The files copied so far stand on the disk; no more were promised."
let hdBootBoundaryLine: StaticString =
    "This disk carries Cardnull itself. Type bootable to make it start the computer by itself behind the BIOS door; the UEFI door from an installed disk is not yet."
let hdBootableReadyLine: StaticString =
    "  It can start the computer by itself."
let hdNoBootFilesLine: StaticString =
    "The disc does not carry Cardnull's boot files - the kernel and the bundle in its BOOT folder. Nothing was written."
let hdDsaveUsageLine: StaticString =
    "dsave wants a name and words: dsave GREETING Hello from Cardnull"
let hdBadNameLine: StaticString =
    "A name is one word of letters, digits, dots and dashes."
let hdTakenLabel: StaticString = "A file named "
let hdTakenClose: StaticString =
    " already stands on the disk. Names are not reused."
let hdDirFullLine: StaticString =
    "The disk's directory is full: 128 files stand on it."
let hdDiskFullLine: StaticString =
    "There is no room left on the disk."
let hdSavedLabel: StaticString = "Saved "
let hdSavedMiddle: StaticString = ": "
let hdSavedClose: StaticString = " bytes on the disk."
let hdDlsTitle: StaticString = "The hard disk:"
let hdEmptyLine: StaticString = "  (nothing here)"
let hdCountFilesClose: StaticString = " files on the disk."
let hdCountFileClose: StaticString = " file on the disk."
let hdDcatUsageLine: StaticString =
    "dcat wants a name: dcat GREETING"
let hdNotOnDiskLabel: StaticString = "Not on the disk: "

/// `disk`: the two drives' account. The CD first, in the
/// disc's own words — read-only, as ever — and then the hard
/// disk: its own name for itself, its measure in mebibytes
/// with the true bytes beside them, and its state in the
/// plain word the state is. When the disk is a Cardnull
/// disk, the directory is walked and the file count and the
/// room left are reckoned from the disk's own testimony,
/// not remembered from any earlier asking.
func runDisk() {
    if discDriveFound {
        writeStatic(hdCdLabel)
        if discModelLength > 0 && discModelAddress != 0 {
            let model = UnsafeMutablePointer<UInt8>(
                bitPattern: UInt(discModelAddress))!
            var index = 0
            while index < discModelLength {
                writeChar(model[index])
                index += 1
            }
        } else {
            writeStatic(discGenericName)
        }
        writeLine(hdCdSuffix)
    } else {
        writeLine(hdCdAbsentLine)
    }
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    writeStatic(hdDiskLabel)
    hdWriteModel()
    writeStatic(" - ")
    writeNumber(hdSectors * UInt64(hdSectorBytes) / 1048576)
    writeStatic(hdMiBWord)
    writeNumber(hdSectors * UInt64(hdSectorBytes))
    writeLine(hdBytesClose)
    let state = hdReadState()
    if state == hdStateBlank {
        writeLine(hdStateBlankLine)
    } else if state == hdStateForeign {
        writeLine(hdStateForeignLine)
    } else if state == hdStateDamaged {
        writeLine(hdStateDamagedLine)
    } else if state == hdStateSilent {
        writeLine(hdStateSilentLine)
    } else if state == hdStateReady {
        if hdScanDirectory(0, 0) {
            writeStatic(hdReadyLabel)
            writeNumber(UInt64(hdEntryCount))
            writeStatic(hdEntryCount == 1 ? hdReadyFileWord
                                          : hdReadyFilesWord)
            writeNumber((hdSbTotal - hdSbNextFree)
                        * UInt64(hdSectorBytes))
            writeLine(hdReadyRoomClose)
            if hdBootable {
                writeLine(hdBootableReadyLine)
            }
        } else {
            writeLine(hdStateSilentLine)
        }
    }
}

/// `format`: the making of a Cardnull disk, behind the typed
/// word. The warning names the disk and the erasing in full
/// before the asking; the asking is a fresh line the typist
/// fills with the word FORMAT, and anything else — a bare
/// Enter, another word, Esc — gives up with nothing written,
/// and says so. Only the matching word opens the gate, and
/// the gate opens onto the hard disk alone.
func runFormat() {
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    writeStatic(hdFormatWarnLabel)
    hdWriteModel()
    writeStatic(", ")
    writeNumber(hdSectors * UInt64(hdSectorBytes) / 1048576)
    writeStatic(" MiB")
    writeLine(hdFormatWarnClose)
    writeLine(hdCdUntouchedLine)
    writeLine(hdFormatAskLine)
    writeStatic(hdYourWordLabel)
    if !hdConfirmationMatches(hdFormatWord) {
        writeLine(hdAbortedLine)
        return
    }
    if !hdFormat() {
        writeLine(hdWriteFailedLine)
        return
    }
    writeStatic(hdFormattedLabel)
    writeNumber(UInt64(hdMaxFiles))
    writeLine(hdFormattedClose)
}

/// `dsave`: a line of words, saved as a file. The name is
/// the argument's first word and the words are the rest of
/// the argument, with one closing line feed for the file's
/// own ending. The refusals are each spoken plainly: no
/// disk, no Cardnull format, a name this house cannot keep,
/// a name already standing, a full directory, no room. The
/// writing's order is the format's promise: the data's
/// sector first, then the directory's entry, then the
/// superblock — so the disk's head never promises what its
/// body has not performed. The words a save can hold are
/// bounded by the shell's own argument field, one sector
/// and far less; the bound is the line the typist typed.
func runDsave() {
    let argLength = copyArgumentToScratch()
    let argument = discPath()
    var start = 0
    if start < argLength && argument[start] == 0x2F { start += 1 }
    var nameEnd = start
    while nameEnd < argLength && argument[nameEnd] != 0x20 {
        nameEnd += 1
    }
    let nameLength = nameEnd - start
    var contentStart = nameEnd
    while contentStart < argLength && argument[contentStart] == 0x20 {
        contentStart += 1
    }
    if nameLength == 0 || contentStart >= argLength {
        writeLine(hdDsaveUsageLine)
        return
    }
    if nameLength > hdNameCap {
        writeLine(hdBadNameLine)
        return
    }
    var index = start
    var nameOK = true
    while index < nameEnd {
        let byte = argument[index]
        let letter = byte >= 0x41 && byte <= 0x5A
            || byte >= 0x61 && byte <= 0x7A
        let digit = byte >= 0x30 && byte <= 0x39
        if !letter && !digit && byte != 0x2E && byte != 0x2D
            && byte != 0x5F {
            nameOK = false
            break
        }
        index += 1
    }
    if !nameOK || (nameLength == 1 && argument[start] == 0x2E)
        || (nameLength == 2 && argument[start] == 0x2E
            && argument[start + 1] == 0x2E) {
        writeLine(hdBadNameLine)
        return
    }
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    let state = hdReadState()
    if state == hdStateSilent {
        writeLine(hdSilentAnswerLine)
        return
    }
    if state != hdStateReady {
        writeLine(hdNotReadyLine)
        return
    }
    if !hdScanDirectory(start, nameLength) {
        writeLine(hdSilentAnswerLine)
        return
    }
    if hdFoundSlot >= 0 {
        writeStatic(hdTakenLabel)
        index = start
        while index < nameEnd {
            writeChar(argument[index])
            index += 1
        }
        writeLine(hdTakenClose)
        return
    }
    if hdFreeSlot < 0 {
        writeLine(hdDirFullLine)
        return
    }
    if hdSbNextFree >= hdSbTotal {
        writeLine(hdDiskFullLine)
        return
    }
    let contentLength = argLength - contentStart
    let fileLength = contentLength + 1
    let buffer = hdData()
    index = 0
    while index < hdSectorBytes {
        buffer[index] = 0
        index += 1
    }
    index = 0
    while index < contentLength {
        buffer[index] = argument[contentStart + index]
        index += 1
    }
    buffer[contentLength] = 0x0A
    if !hdWriteSector(hdSbNextFree) {
        writeLine(hdWriteFailedLine)
        return
    }
    if !hdWriteEntry(hdFreeSlot,
                     UnsafePointer(argument), start, nameLength,
                     UInt32(hdSbNextFree), UInt32(fileLength)) {
        writeLine(hdWriteFailedLine)
        return
    }
    if !hdWriteSuperblock(UInt32(hdEntryCount + 1),
                          hdSbNextFree + 1) {
        writeLine(hdWriteFailedLine)
        return
    }
    _ = hdFlush()
    writeStatic(hdSavedLabel)
    index = start
    while index < nameEnd {
        writeChar(argument[index])
        index += 1
    }
    writeStatic(hdSavedMiddle)
    writeNumber(UInt64(fileLength))
    writeLine(hdSavedClose)
}

/// `dls`: the disk's files, in the directory's own order —
/// two spaces, the name, room to a modest column, and the
/// size — with the count beneath, and the empty word when
/// the directory holds nothing, as `ls` speaks it of the CD.
func runDls() {
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    let state = hdReadState()
    if state == hdStateSilent {
        writeLine(hdSilentAnswerLine)
        return
    }
    if state != hdStateReady {
        writeLine(hdNotReadyLine)
        return
    }
    writeLine(hdDlsTitle)
    var count = 0
    var dirSector: UInt64 = 0
    while dirSector < hdDirSectors {
        if !hdReadSector(hdDirStart + dirSector) {
            writeLine(hdSilentAnswerLine)
            return
        }
        let buffer = hdData()
        var inSector = 0
        while inSector < Int(hdSectorBytes) / hdEntryBytes {
            let base = inSector * hdEntryBytes
            if buffer[base] != 0 {
                count += 1
                writeChar(0x20)
                writeChar(0x20)
                var length = 0
                while length < 32 && buffer[base + 1 + length] != 0 {
                    length += 1
                }
                var index = 0
                while index < length {
                    writeChar(buffer[base + 1 + index])
                    index += 1
                }
                var padding = 14 - length
                if padding < 1 { padding = 1 }
                while padding > 0 {
                    writeChar(0x20)
                    padding -= 1
                }
                writeNumber(UInt64(discU32(buffer, base + 36)))
                writeNewline()
            }
            inSector += 1
        }
        dirSector += 1
    }
    if count == 0 {
        writeLine(hdEmptyLine)
    }
    writeNumber(UInt64(count))
    writeLine(count == 1 ? hdCountFileClose : hdCountFilesClose)
}

/// `dcat`: one file off the disk, printed through the one
/// output door with the CD reader's own forgiveness — line
/// feeds end lines, carriage returns are let go, a tab steps
/// to a plain space, and any other character the screen
/// cannot honestly draw is passed over. A name the disk does
/// not hold is answered as missing; a name may wear one
/// leading slash or none, as the CD's paths forgive.
func runDcat() {
    let argLength = copyArgumentToScratch()
    let argument = discPath()
    var start = 0
    if start < argLength && argument[start] == 0x2F { start += 1 }
    let nameLength = argLength - start
    if nameLength <= 0 {
        writeLine(hdDcatUsageLine)
        return
    }
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    let state = hdReadState()
    if state == hdStateSilent {
        writeLine(hdSilentAnswerLine)
        return
    }
    if state != hdStateReady {
        writeLine(hdNotReadyLine)
        return
    }
    if !hdScanDirectory(start, nameLength) {
        writeLine(hdSilentAnswerLine)
        return
    }
    if hdFoundSlot < 0 {
        writeStatic(hdNotOnDiskLabel)
        var index = start
        while index < argLength {
            writeChar(argument[index])
            index += 1
        }
        writeNewline()
        return
    }
    var remaining = Int(hdFoundLength)
    var sector = UInt64(hdFoundStart)
    let buffer = hdData()
    while remaining > 0 {
        if !hdReadSector(sector) {
            writeNewline()
            writeLine(hdSilentAnswerLine)
            return
        }
        var take = remaining
        if take > hdSectorBytes { take = hdSectorBytes }
        var index = 0
        while index < take {
            let byte = buffer[index]
            if byte == 0x0A {
                writeNewline()
            } else if byte == 0x09 {
                writeChar(0x20)
            } else if byte >= 0x20 && byte != 0x7F {
                writeChar(byte)
            }
            index += 1
        }
        remaining -= take
        sector += 1
    }
    writeNewline()
}

/// The installer's carrying: a heap table of the files it
/// will copy, collected off the CD before anything is erased
/// — a name's 32 bytes, then the extent and the size. The
/// cap is 24 files in one making; the disc this installer
/// serves carries 13 today, and a disc that outgrows the
/// table is refused before it is touched, not truncated
/// mid-copy.
var hdStageAddress: UInt64 = 0
let hdStageCap = 24
let hdStageStride = 44
var hdPickCount = 0

/// The names the installer carries: the welcome, and every
/// name ending in a program's or a feather's suffix — the
/// system's own files, as the milestone names them. The boot
/// machinery and the folders are the disc's furniture, not
/// its cargo, and are not copied.
let hdWelcomeName: StaticString = "welcome.txt"
let hdBinSuffix: StaticString = ".bin"
let hdFeatherSuffix: StaticString = ".feather"
let hdInstalledName: StaticString = "INSTALLED.TXT"

/// The boot folder's names, as the installer and `bootable`
/// seek them on the disc (milestone 28): the kernel and the
/// bundle an install now plants on the disk beside the
/// thirteen, and the boot image `bootable` lays at the
/// disk's head. The paths are walked through the disc's own
/// ISO reader, BOOT folder first, exactly as the BIOS stage
/// walks them in its own tongue.
let hdKernelName: StaticString = "KERNEL.BIN"
let hdBundleName: StaticString = "FILES.BUNDLE"
let hdKernelPath: StaticString = "BOOT/KERNEL.BIN"
let hdBundlePath: StaticString = "BOOT/FILES.BUNDLE"
let hdBiosBootPath: StaticString = "BOOT/BIOSBOOT.IMG"

/// Resolves one standing path on the disc — the words laid
/// in the path scratch and walked from the root by the disc
/// reader's own resolver. True when the path stands and is a
/// file; its extent and size are the resolver's globals.
func hdResolveDiscFile(_ pathText: StaticString) -> Bool {
    let path = discPath()
    var index = 0
    while pathText.utf8Start[index] != 0 {
        path[index] = pathText.utf8Start[index]
        index += 1
    }
    if isoResolvePath(index) != pathFoundCode { return false }
    return !resolvedIsDirectory
}

/// Appends one disc-sourced pick to the installer's staging:
/// the name in its field, the disc extent and the size in
/// theirs, and the source byte zeroed — the disc, not memory.
/// The staging must already stand (a gathering ran first).
func hdAppendDiscPick(_ name: StaticString,
                      _ extent: UInt32, _ size: UInt32) -> Bool {
    if hdStageAddress == 0 { return false }
    if hdPickCount >= hdStageCap { return false }
    let stage = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdStageAddress))!
    let pick = hdPickCount * hdStageStride
    var index = 0
    while index < hdStageStride {
        stage[pick + index] = 0
        index += 1
    }
    index = 0
    while index < 32 && name.utf8Start[index] != 0 {
        stage[pick + index] = name.utf8Start[index]
        index += 1
    }
    hdPut32(stage, pick + 32, extent)
    hdPut32(stage, pick + 36, size)
    hdPickCount += 1
    return true
}

/// Gathers the two boot files after the thirteen (milestone
/// 28): KERNEL.BIN and FILES.BUNDLE out of the disc's BOOT
/// folder, appended to the staging the first gathering made.
/// An install plants Cardnull itself on the disk — without
/// these two there is nothing for `bootable` to start the
/// computer with — so a disc that does not carry them refuses
/// the whole making, before anything is erased.
func hdCollectBootPicks() -> Bool {
    if !discIsoFound { return false }
    if !hdResolveDiscFile(hdKernelPath) { return false }
    let kernelExtent = resolvedExtent
    let kernelSize = resolvedSize
    if !hdAppendDiscPick(hdKernelName, kernelExtent, kernelSize) {
        return false
    }
    if !hdResolveDiscFile(hdBundlePath) { return false }
    return hdAppendDiscPick(hdBundleName, resolvedExtent,
                            resolvedSize)
}

/// True when the record name standing in the CD's buffer —
/// its effective reach, the version suffix already forgiven
/// by the caller — folds to the given word exactly.
func hdNameFoldsTo(_ buffer: UnsafeMutablePointer<UInt8>,
                   _ start: Int, _ length: Int,
                   _ word: StaticString) -> Bool {
    var wordLength = 0
    while word.utf8Start[wordLength] != 0 { wordLength += 1 }
    if length != wordLength { return false }
    var index = 0
    while index < length {
        if featherFold(buffer[start + index])
            != word.utf8Start[index] {
            return false
        }
        index += 1
    }
    return true
}

/// True when the record name ends with the given suffix,
/// folded — the test that gathers every program and every
/// feather without naming them one by one.
func hdNameEndsWith(_ buffer: UnsafeMutablePointer<UInt8>,
                    _ start: Int, _ length: Int,
                    _ suffix: StaticString) -> Bool {
    var suffixLength = 0
    while suffix.utf8Start[suffixLength] != 0 { suffixLength += 1 }
    if length < suffixLength { return false }
    var index = 0
    while index < suffixLength {
        if featherFold(buffer[start + length - suffixLength + index])
            != suffix.utf8Start[index] {
            return false
        }
        index += 1
    }
    return true
}

/// Walks the CD's root directory and gathers the installer's
/// picks into the staging table, record by record, in the
/// disc reader's own stepping — the walk finishes before any
/// copying begins, because the copying reads the CD's sectors
/// through the same buffer the walk reads its directory
/// from, and a directory held in the hand must not be
/// overwritten mid-walk. Returns the count gathered, or -1
/// when the disc refused a reading.
func hdCollectPicks() -> Int {
    if hdStageAddress == 0 {
        hdStageAddress = heapAlloc(hdStageCap * hdStageStride)
        if hdStageAddress == 0 { return -1 }
    }
    let stage = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdStageAddress))!
    hdPickCount = 0
    let buffer = discBuffer()
    var sectorIndex: UInt32 = 0
    let sectorCount = (isoRootSize + UInt32(discSectorBytes) - 1)
        / UInt32(discSectorBytes)
    while sectorIndex < sectorCount {
        if !discReadSector(isoRootExtent + sectorIndex) {
            return -1
        }
        var inSector = discSectorBytes
        let remaining = isoRootSize
            - sectorIndex * UInt32(discSectorBytes)
        if remaining < UInt32(discSectorBytes) {
            inSector = Int(remaining)
        }
        var offset = 0
        while offset < inSector {
            let recordLength = Int(buffer[offset])
            if recordLength == 0 { break }
            if recordLength >= 34
                && buffer[offset + 25] & 0x02 == 0 {
                let nameLength = Int(buffer[offset + 32])
                let nameless = nameLength == 1
                    && buffer[offset + 33] <= 1
                if !nameless && nameLength > 0 {
                    var effective = nameLength
                    var index = 0
                    while index < nameLength {
                        if buffer[offset + 33 + index] == 0x3B {
                            effective = index
                            break
                        }
                        index += 1
                    }
                    let nameStart = offset + 33
                    if hdNameFoldsTo(buffer, nameStart, effective,
                                     hdWelcomeName)
                        || hdNameEndsWith(buffer, nameStart,
                                          effective, hdBinSuffix)
                        || hdNameEndsWith(buffer, nameStart,
                                          effective,
                                          hdFeatherSuffix) {
                        if hdPickCount >= hdStageCap {
                            return hdStageCap + 1
                        }
                        let pick = hdPickCount * hdStageStride
                        index = 0
                        while index < hdStageStride {
                            stage[pick + index] = 0
                            index += 1
                        }
                        index = 0
                        while index < effective && index < 32 {
                            stage[pick + index] =
                                buffer[nameStart + index]
                            index += 1
                        }
                        hdPut32(stage, pick + 32,
                                discU32(buffer, offset + 2))
                        hdPut32(stage, pick + 36,
                                discU32(buffer, offset + 10))
                        hdPickCount += 1
                    }
                }
            }
            offset += recordLength
        }
        sectorIndex += 1
    }
    return hdPickCount
}

/// The bundle's twin of the gathering above (milestone 23):
/// the same picks — the welcome, every program, every
/// feather — read out of the bundle's table in memory rather
/// than the disc's directory, in the table's own order. The
/// staging's byte at offset 40, spare in the disc's gathering,
/// carries the source's mark here: 1, for memory — the copying
/// below reads that file's bytes out of the bundle's span
/// instead of the CD's sectors. The disc's gathering leaves
/// the byte zeroed, for the disc.
func hdCollectBundlePicks() -> Int {
    if hdStageAddress == 0 {
        hdStageAddress = heapAlloc(hdStageCap * hdStageStride)
        if hdStageAddress == 0 { return -1 }
    }
    let stage = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdStageAddress))!
    let bundle = bundleBase()
    hdPickCount = 0
    var index = 0
    while index < bundleFileCount {
        if !bundleEntryAt(index) { return -1 }
        if hdNameFoldsTo(bundle, bundleEntryNameOffset,
                         bundleEntryNameLength, hdWelcomeName)
            || hdNameEndsWith(bundle, bundleEntryNameOffset,
                              bundleEntryNameLength, hdBinSuffix)
            || hdNameEndsWith(bundle, bundleEntryNameOffset,
                              bundleEntryNameLength,
                              hdFeatherSuffix) {
            if hdPickCount >= hdStageCap { return hdStageCap + 1 }
            let pick = hdPickCount * hdStageStride
            var step = 0
            while step < hdStageStride {
                stage[pick + step] = 0
                step += 1
            }
            step = 0
            while step < bundleEntryNameLength && step < 32 {
                stage[pick + step] =
                    bundle[bundleEntryNameOffset + step]
                step += 1
            }
            hdPut32(stage, pick + 32, bundleEntryOffset)
            hdPut32(stage, pick + 36, bundleEntryLength)
            stage[pick + 40] = 1
            hdPickCount += 1
        }
        index += 1
    }
    return hdPickCount
}

/// The installer's note, composed a byte at a time in the
/// sector field: INSTALLED.TXT's words, laid in the field
/// before the field is written to the disk as the file's one
/// sector. hdTextPos is the composer's cursor.
var hdTextPos = 0

func hdTextByte(_ byte: UInt8) {
    hdData()[hdTextPos] = byte
    hdTextPos += 1
}

func hdTextStatic(_ text: StaticString) {
    var index = 0
    while text.utf8Start[index] != 0 {
        hdTextByte(text.utf8Start[index])
        index += 1
    }
}

func hdTextNumber(_ value: UInt64) {
    if value >= 10 { hdTextNumber(value / 10) }
    hdTextByte(0x30 + UInt8(value % 10))
}

let hdInstalledText1: StaticString =
    "Cardnull OS was installed on this disk by its own installer."
let hdInstalledText2: StaticString = "Files copied from the disc: "
let hdInstalledText2Bundle: StaticString =
    "Files copied from the bundle in memory and the disc: "
let hdInstalledText3: StaticString =
    "The disk carries Cardnull itself: its kernel and its file bundle stand among its files."
let hdInstalledText4: StaticString =
    "Type bootable in the Terminal to make this disk start the computer by itself, behind the BIOS door."
let hdInstalledText5: StaticString =
    "The UEFI door from an installed disk is not yet."
let hdTooManyLine: StaticString =
    "The disc holds more files than the installer can carry in one making. Nothing was written."

/// Copies the gathered picks from the CD onto the formatted
/// disk, one file at a time: the file's bytes are pumped a
/// disk sector at a time — each disk sector gathered out of
/// whichever CD sector holds it, the two drives' measures
/// being four apart — and its directory entry written after
/// its data stands, the format's order. Then the installer's
/// note is composed and written the same way, and the
/// superblock is written last over the whole making. If any
/// reading or writing refuses along the way, the superblock
/// is first mended to the standing the disk truly has — the
/// entries written and the ground they hold — and the
/// failure is the caller's to speak.
func hdInstallCopy() -> Bool {
    let stage = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(hdStageAddress))!
    let cdBuffer = discBuffer()
    var nextFree = hdDataStart
    var slot = 0
    var cdCached: UInt32 = 0xFFFFFFFF
    var pick = 0
    while pick < hdPickCount {
        let base = pick * hdStageStride
        let extent = discU32(stage, base + 32)
        let size = discU32(stage, base + 36)
        let sectors = (UInt64(size) + UInt64(hdSectorBytes) - 1)
            / UInt64(hdSectorBytes)
        if nextFree + sectors > hdSbTotal {
            _ = hdWriteSuperblock(UInt32(slot), nextFree)
            return false
        }
        var chunk: UInt64 = 0
        var copiedOK = true
        while chunk < sectors {
            let frame = hdData()
            var index = 0
            while index < hdSectorBytes {
                frame[index] = 0
                index += 1
            }
            var take = Int(size) - Int(chunk)
                * hdSectorBytes
            if take > hdSectorBytes { take = hdSectorBytes }
            index = 0
            while index < take {
                let source = Int(chunk) * hdSectorBytes + index
                if stage[base + 40] == 1 {
                    // A pick the bundle gathered (milestone
                    // 23): its bytes stand in memory, at the
                    // offset the staging keeps — no sector is
                    // read, and the CD's cache is untouched.
                    frame[index] =
                        bundleBase()[Int(extent) + source]
                } else {
                    let lba = extent
                        + UInt32(source / discSectorBytes)
                    if lba != cdCached {
                        if !discReadSector(lba) {
                            copiedOK = false
                            break
                        }
                        cdCached = lba
                    }
                    frame[index] =
                        cdBuffer[source % discSectorBytes]
                }
                index += 1
            }
            if !copiedOK { break }
            if !hdWriteSector(nextFree + chunk) {
                copiedOK = false
                break
            }
            chunk += 1
        }
        if !copiedOK {
            _ = hdWriteSuperblock(UInt32(slot), nextFree)
            return false
        }
        var nameLength = 0
        while nameLength < 32 && stage[base + nameLength] != 0 {
            nameLength += 1
        }
        if !hdWriteEntry(slot, UnsafePointer(stage), base,
                         nameLength, UInt32(nextFree), size) {
            _ = hdWriteSuperblock(UInt32(slot), nextFree)
            return false
        }
        nextFree += sectors
        slot += 1
        pick += 1
    }
    // The installer's own note, composed in the field and
    // written as one file among the rest.
    let frame = hdData()
    var index = 0
    while index < hdSectorBytes {
        frame[index] = 0
        index += 1
    }
    hdTextPos = 0
    hdTextStatic(hdInstalledText1)
    hdTextByte(0x0A)
    hdTextStatic(bundleValid ? hdInstalledText2Bundle
                             : hdInstalledText2)
    hdTextNumber(UInt64(hdPickCount))
    hdTextByte(0x2E)
    hdTextByte(0x0A)
    hdTextStatic(hdInstalledText3)
    hdTextByte(0x0A)
    hdTextStatic(hdInstalledText4)
    hdTextByte(0x0A)
    hdTextStatic(hdInstalledText5)
    hdTextByte(0x0A)
    if nextFree >= hdSbTotal
        || !hdWriteSector(nextFree) {
        _ = hdWriteSuperblock(UInt32(slot), nextFree)
        return false
    }
    if !hdWriteEntry(slot, hdInstalledName.utf8Start, 0, 13,
                     UInt32(nextFree), UInt32(hdTextPos)) {
        _ = hdWriteSuperblock(UInt32(slot), nextFree)
        return false
    }
    nextFree += 1
    slot += 1
    if !hdWriteSuperblock(UInt32(slot), nextFree) {
        return false
    }
    _ = hdFlush()
    return true
}

/// `install`: the visiting disc plants a home. The warning
/// and the typed word guard it as `format` is guarded; the
/// picks are gathered off the CD before the gate — the
/// thirteen from the root or the bundle, and the kernel and
/// the bundle themselves from the BOOT folder — so a disc
/// that cannot be read, or one carrying more than the
/// installer can carry, refuses the making before anything
/// is erased. Then the formatting, then the copying, then
/// the account: what was copied, what the disk now holds,
/// and the standing spoken in full — the disk carries
/// Cardnull itself, and `bootable` can make it start the
/// computer by itself behind the BIOS door.
func runInstall() {
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    // The source follows the serving layer (milestone 23):
    // a proven bundle's picks are gathered from memory; the
    // disc's, when no bundle serves. Only when neither world
    // holds the system's files is there nothing to install
    // from.
    if !bundleValid && !discIsoFound {
        writeLine(hdNoSourceLine)
        return
    }
    let picks = bundleValid ? hdCollectBundlePicks()
                            : hdCollectPicks()
    if picks < 0 {
        writeLine(discReadErrorLine)
        return
    }
    if picks == 0 {
        writeLine(hdNoSourceLine)
        return
    }
    if picks > hdStageCap {
        writeLine(hdTooManyLine)
        return
    }
    // The two boot files ride after the thirteen, gathered
    // from the disc's BOOT folder before the gate as well:
    // an install that cannot plant the kernel and the bundle
    // themselves is refused before anything is erased.
    if !hdCollectBootPicks() {
        writeLine(hdNoBootFilesLine)
        return
    }
    writeStatic(hdInstallWarnLabel)
    hdWriteModel()
    writeStatic(", ")
    writeNumber(hdSectors * UInt64(hdSectorBytes) / 1048576)
    writeStatic(" MiB")
    writeLine(hdFormatWarnClose)
    writeLine(bundleValid ? hdInstallFromBundleLine
                          : hdInstallFromLine)
    writeLine(hdInstallAskLine)
    writeStatic(hdYourWordLabel)
    if !hdConfirmationMatches(hdInstallWord) {
        writeLine(hdAbortedLine)
        return
    }
    if !hdFormat() {
        writeLine(hdWriteFailedLine)
        return
    }
    if !hdInstallCopy() {
        writeLine(hdInstallStoppedLine)
        return
    }
    writeStatic(hdInstalledLabel)
    writeNumber(UInt64(hdPickCount))
    writeLine(bundleValid ? hdInstalledMiddleBundle
                          : hdInstalledMiddle)
    if hdScanDirectory(0, 0) {
        writeStatic(hdHoldsLabel)
        writeNumber(UInt64(hdEntryCount))
        writeLine(hdEntryCount == 1 ? hdHoldsFileClose
                                    : hdHoldsFilesClose)
    }
    writeLine(hdBootBoundaryLine)
}

/// `bootable`'s vocabulary (milestone 28): the refusals, the
/// gate, and the account, in plain words.
let hdBootableNeedsLine: StaticString =
    "The hard disk is not a Cardnull disk yet. format makes it one, and install plants Cardnull on it."
let hdAlreadyBootableLine: StaticString =
    "This disk already starts the computer by itself."
let hdNoBootImageLine: StaticString =
    "The disc does not carry a sound boot image in its BOOT folder. Nothing was written."
let hdNoRoomMoveLine: StaticString =
    "There is not room on the disk to move its files behind a partition. Nothing was written."
let hdBootableWarnLine: StaticString =
    "bootable will move everything on the hard disk behind a partition, and lay Cardnull's own boot image and partition table at its head."
let hdBootableAskLine: StaticString =
    "Type BOOTABLE and press Enter to prepare the disk. Anything else gives up, and nothing is written."
let hdBootableUnprovenLine: StaticString =
    "The preparation did not prove out: the disk does not answer as a prepared Cardnull disk. What stands on it now is not promised; format can make it whole again."
let hdBootableDoneLine: StaticString =
    "The disk is prepared: it can start the computer by itself behind the BIOS door."

/// Where a prepared disk's pieces stand (milestone 28): the
/// boot image at sector 4, and the filesystem's new home at
/// sector 2048 — room for the table, the image, and honest
/// emptiness between them, and the place the partition
/// entry names.
let hdBootImageHome: UInt64 = 4
let hdPartitionHome: UInt64 = 2048

/// The boot image's place and measure on the disc, found by
/// hdFetchBootImage before the gate: its extent in CD
/// sectors and its length in bytes.
var hdBootImageExtent: UInt32 = 0
var hdBootImageSize: UInt32 = 0

/// Fetches the boot image's facts off the disc and proves
/// its shape before anything is promised: the image must
/// stand in the disc's BOOT folder, run past one sector and
/// no further than the ground before the partition allows,
/// and its first sector must wear the 55 AA tail a boot
/// sector wears. A disc without it — or with a misshapen
/// one — is a plain refusal, and nothing is written.
func hdFetchBootImage() -> Bool {
    if !discIsoFound { return false }
    if !hdResolveDiscFile(hdBiosBootPath) { return false }
    hdBootImageExtent = resolvedExtent
    hdBootImageSize = resolvedSize
    let size = Int(hdBootImageSize)
    if size <= hdSectorBytes
        || size > Int(hdPartitionHome - hdBootImageHome)
            * hdSectorBytes {
        return false
    }
    if !discReadSector(hdBootImageExtent) { return false }
    let buffer = discBuffer()
    return buffer[510] == 0x55 && buffer[511] == 0xAA
}

/// Lays the boot image at the disk's head, a sector at a
/// time out of the disc's sectors — the two drives' measures
/// being four apart — with the first sector's boot table
/// patched for its new home before it is written: the image
/// stands at sector 4, which is 1 in the 2048-byte units the
/// table reckons in, and the table names the image's whole
/// length. The home is still 0 while this runs, so the
/// home-relative hands speak true disk sectors here.
func hdWriteBootImage() -> Bool {
    let size = Int(hdBootImageSize)
    let sectors = (size + hdSectorBytes - 1) / hdSectorBytes
    var cdCached: UInt32 = 0xFFFFFFFF
    var chunk = 0
    while chunk < sectors {
        let sourceByte = chunk * hdSectorBytes
        let lba = hdBootImageExtent
            + UInt32(sourceByte / discSectorBytes)
        if lba != cdCached {
            if !discReadSector(lba) { return false }
            cdCached = lba
        }
        let cd = discBuffer()
        let frame = hdData()
        var index = 0
        while index < hdSectorBytes {
            frame[index] = 0
            index += 1
        }
        var take = size - sourceByte
        if take > hdSectorBytes { take = hdSectorBytes }
        let offset = sourceByte % discSectorBytes
        index = 0
        while index < take {
            frame[index] = cd[offset + index]
            index += 1
        }
        if chunk == 0 {
            hdPut32(frame, 12, 1)
            hdPut32(frame, 16, UInt32(size))
        }
        if !hdWriteSector(hdBootImageHome + UInt64(chunk)) {
            return false
        }
        chunk += 1
    }
    return true
}

/// `bootable`: a prepared disk boots Cardnull by itself
/// (milestone 28). The refusals come first and write nothing:
/// no disk, a disk that is not Cardnull's yet, a disk already
/// prepared, no room to move its files, or no sound boot
/// image on the disc to lay at its head. Behind the typed
/// word, the making goes in the order that keeps every
/// half-way state honest: the filesystem is copied to its
/// new home sector by sector, top down, so the copy can
/// never trample ground it has not read yet; the boot image
/// is laid at sector 4 with its table patched; and the MBR —
/// the patched boot sector wearing one Cardnull partition —
/// is written last of all, because the moment it stands, the
/// disk is a bootable one and must already be whole. Then
/// the disk is judged again and its directory counted: the
/// success is claimed only when the disk itself answers
/// ready and prepared, with the same files standing.
func runBootable() {
    hdRaise()
    if !hdFound {
        writeLine(hdNoDiskLine)
        return
    }
    let state = hdReadState()
    if state == hdStateSilent {
        writeLine(hdSilentAnswerLine)
        return
    }
    if state != hdStateReady {
        writeLine(hdBootableNeedsLine)
        return
    }
    if hdBootable {
        writeLine(hdAlreadyBootableLine)
        return
    }
    if !hdFetchBootImage() {
        writeLine(hdNoBootImageLine)
        return
    }
    if !hdScanDirectory(0, 0) {
        writeLine(hdSilentAnswerLine)
        return
    }
    let entriesBefore = hdEntryCount
    let nextFreeBefore = hdSbNextFree
    if nextFreeBefore + hdPartitionHome > hdSbTotal {
        writeLine(hdNoRoomMoveLine)
        return
    }
    writeLine(hdBootableWarnLine)
    writeLine(hdCdUntouchedLine)
    writeLine(hdBootableAskLine)
    writeStatic(hdYourWordLabel)
    if !hdConfirmationMatches(hdBootableWord) {
        writeLine(hdAbortedLine)
        return
    }
    // (a) The migration: every standing sector of the
    // filesystem, copied to its new home, top down.
    var sector = nextFreeBefore
    while sector > 0 {
        sector -= 1
        if !hdReadSector(sector) {
            writeLine(hdWriteFailedLine)
            return
        }
        if !hdWriteSector(sector + hdPartitionHome) {
            writeLine(hdWriteFailedLine)
            return
        }
    }
    // (b) The boot image at sector 4, its table patched.
    if !hdWriteBootImage() {
        writeLine(hdWriteFailedLine)
        return
    }
    // (c) The MBR, built in the field from the patched first
    // sector standing at sector 4 — its code kept whole, one
    // partition entry laid in the table's place, the rest of
    // the table's ground zeroed — and written last.
    if !hdReadSector(hdBootImageHome) {
        writeLine(hdWriteFailedLine)
        return
    }
    let buffer = hdData()
    var index = 446
    while index < 510 {
        buffer[index] = 0
        index += 1
    }
    buffer[446] = 0x80
    buffer[450] = 0xCA
    hdPut32(buffer, 454, UInt32(hdPartitionHome))
    hdPut32(buffer, 458, UInt32(hdSectors - hdPartitionHome))
    if !hdWriteSector(0) {
        writeLine(hdWriteFailedLine)
        return
    }
    // (d) The writings made to stand.
    if !hdFlush() {
        writeLine(hdWriteFailedLine)
        return
    }
    // The proof: the disk judged fresh must answer ready and
    // prepared, with the same next-free reckoning, and its
    // directory must count the same files as before the move.
    if hdReadState() != hdStateReady || !hdBootable
        || hdSbNextFree != nextFreeBefore {
        writeLine(hdBootableUnprovenLine)
        return
    }
    if !hdScanDirectory(0, 0) || hdEntryCount != entriesBefore {
        writeLine(hdBootableUnprovenLine)
        return
    }
    writeLine(hdBootableDoneLine)
}

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
//   install plant Cardnull on the hard disk: format it and
//           copy the disc's own files onto it — Cardnull
//           itself among them — behind the typed confirmation
//           (milestone 21; the kernel and bundle joined the
//           copying at milestone 28)
//   bootable prepare the hard disk to start the computer by
//           itself: the filesystem moved behind a partition,
//           our boot image at its head, behind the typed
//           confirmation (milestone 28)
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
let guiCommand: StaticString = "gui"
let mouseCommand: StaticString = "mouse"
let soundCommand: StaticString = "sound"
let netCommand: StaticString = "net"
let diskCommand: StaticString = "disk"
let formatCommand: StaticString = "format"
let dsaveCommand: StaticString = "dsave"
let dlsCommand: StaticString = "dls"
let dcatCommand: StaticString = "dcat"
let installCommand: StaticString = "install"
let bootableCommand: StaticString = "bootable"

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
let helpInstallLine: StaticString =
    "  install install Cardnull onto the hard disk (erases it)"
let helpBootableLine: StaticString =
    "  bootable prepare the hard disk to start the computer by itself"

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
    let isGui = commandMatches(guiCommand)
    let isMouse = commandMatches(mouseCommand)
    let isSound = commandMatches(soundCommand)
    let isNet = commandMatches(netCommand)
    let isDisk = commandMatches(diskCommand)
    let isFormat = commandMatches(formatCommand)
    let isDsave = firstWordMatches(dsaveCommand)
    let isDls = commandMatches(dlsCommand)
    let isDcat = firstWordMatches(dcatCommand)
    let isInstall = commandMatches(installCommand)
    let isBootable = commandMatches(bootableCommand)

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
            writeLine(helpGuiLine)
            writeLine(helpMouseLine)
            writeLine(helpSoundLine)
            writeLine(helpNetLine)
            writeLine(helpDiskLine)
            writeLine(helpFormatLine)
            writeLine(helpDsaveLine)
            writeLine(helpDlsLine)
            writeLine(helpDcatLine)
            writeLine(helpInstallLine)
            writeLine(helpBootableLine)
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
        } else if isInstall {
            runInstall()
        } else if isBootable {
            runBootable()
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
