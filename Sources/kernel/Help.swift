// Cardnull OS — the Help window (milestone 36).
//
// The desktop's plain-words help: one page of
// questions a new person actually asks — "How do
// I…" — each with its answer in the same plain
// words, nothing coded, nothing assumed. The page
// is a reading page: it scrolls by the wheel, the
// scroll keys, and its rail, down the family's
// roads, and it keeps the family's manners entire
// (the room by focus, the drag, the maximize, the
// close box). Every sentence on it is true of the
// system as it stands — the doors it names are the
// doors that exist, the words it promises are the
// words the windows carry — because help that
// describes another machine is worse than none.
//
// Its doors are the family's two: the Welcome
// card's "How do I..." button, standing where the
// screen allows the card's taller shape, and the
// Terminal's `howdoi` command.
//
// This window's code stands in its own file, as
// the Split's standing rule (milestone 33.5) asks:
// a new subsystem arrives as a new file, never
// back into one huge kernel.

/// The Help window's standing: open or closed, and
/// the room's focus flag — the ninth standing in
/// guiRoomHolder's reckoning, after the Shield's 8.
var helpOpen = false
var guiFocusHelp = false
var helpWantedAtFace = false

/// The Help window's geometry, set by the face's
/// arrangement and carried by its drag, beside its
/// siblings' keepings.
var guiHelpX = 0
var guiHelpY = 0
var guiHelpW = 0
var guiHelpH = 0
var guiHelpSavedX = 0
var guiHelpSavedY = 0
var guiHelpSavedW = 0
var guiHelpSavedH = 0
var guiHelpMaximized = false

/// The title press's pairing, for the double-press
/// that trades the window's size, down the family's
/// road.
var helpTitlePressArmed = false
var helpTitlePressTick: UInt64 = 0

/// The page's scroll, in lines: the first line of
/// the table standing at the page's head.
var helpScroll = 0

let guiHelpTitle: StaticString = "How do I..."

/// The page itself: the heading and the questions
/// in cardinal, the answers in ink, a blank line
/// between one matter and the next. Hand-wrapped
/// at the page's width, as the Shield's page is —
/// thirty-eight letters at the outside, so no line
/// ever crowds the rail. helpLineFlags walks beside
/// it: true where the line stands in cardinal (the
/// heading and the questions), false for the ink of
/// the answers and the blanks.
let helpLines: [StaticString] = [
    "Plain answers, in plain words.",
    "",
    "How do I read the Bible?",
    "Press Welcome in the bottom bar,",
    "then Read the Bible - or type bible",
    "in the Terminal. Press a book's name",
    "to open it. The wheel and Page Down",
    "turn the page; Escape goes back to",
    "the list of books.",
    "",
    "How do I write something down?",
    "Press Write in the bottom bar. Type",
    "your words - Backspace rubs out -",
    "and press Save. The note is kept on",
    "the disk as a feather, and it is",
    "still there after a restart.",
    "",
    "How do I see my files?",
    "Press Files in the bottom bar. It",
    "shows what the disk holds; press a",
    "name to read it. Renaming and",
    "copying are plain there, and",
    "deleting asks you to type DELETE",
    "first, so it never happens by",
    "accident.",
    "",
    "How do I use the network?",
    "In the Terminal, type net. The",
    "machine asks for an address,",
    "answers, and reports - it speaks",
    "only when you ask it to. The Shield",
    "window keeps the count of all it",
    "has said.",
    "",
    "What is the Shield?",
    "The house's guard, written into the",
    "system itself: the family filter is",
    "on, there is no way to turn it off,",
    "and nothing you do here is watched",
    "or sent anywhere. Press The Shield",
    "on the Welcome card to read its",
    "standing.",
    "",
    "How do I shut down or restart?",
    "Press Power in the bottom bar. The",
    "card asks what you want, then asks",
    "Are you sure? Nothing happens until",
    "you answer - and No is always safe.",
    "",
    "How do I get back to the start?",
    "Press Home in the bottom bar, or",
    "the Escape key. Every window closes",
    "and the Terminal stands ready.",
    "Nothing is lost: your saved notes",
    "stay on the disk.",
    "",
    "What can I type in the Terminal?",
    "Type help, and the Terminal lists",
    "its words in plain order - bible,",
    "shield, howdoi, files, write, net,",
    "and the rest. Each one does what",
    "its name says.",
    "",
    "That is the whole of it. The house",
    "is small, and it is yours.",
]

let helpLineFlags: [Bool] = [
    true,
    false,
    true, false, false, false, false, false, false,
    false,
    true, false, false, false, false, false,
    false,
    true, false, false, false, false, false, false, false,
    false,
    true, false, false, false, false, false, false,
    false,
    true, false, false, false, false, false, false, false,
    false,
    true, false, false, false, false,
    false,
    true, false, false, false, false, false,
    false,
    true, false, false, false, false, false,
    false,
    false, false,
]

func helpTextX() -> Int { guiHelpX + 16 }
func helpTextTop() -> Int { guiHelpY + 52 }
func helpRailX() -> Int { guiHelpX + guiHelpW - 40 }
func helpBottom() -> Int { guiHelpY + guiHelpH - 16 }

/// The page's visible rows: the body's height in
/// twenty-four-pixel lines (the text stands at
/// scale 2, as the Shield's page does).
func helpVisibleRows() -> Int {
    max(1, (helpBottom() - helpTextTop()) / 24)
}

func helpMaxScroll() -> Int {
    max(0, helpLines.count - helpVisibleRows())
}

func guiHelpContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiHelpX && x < guiHelpX + guiHelpW
        && y >= guiHelpY && y < guiHelpY + guiHelpH
}

func guiHelpCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiHelpX, guiHelpW)
        && x < guiCloseBoxX(guiHelpX, guiHelpW) + guiBoxW
        && y >= guiHelpY + guiBoxTop
        && y < guiHelpY + guiBoxTop + guiBoxH
}

func guiHelpMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiHelpX, guiHelpW)
        && x < guiMaxBoxX(guiHelpX, guiHelpW) + guiBoxW
        && y >= guiHelpY + guiBoxTop
        && y < guiHelpY + guiBoxTop + guiBoxH
}

func guiHelpTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiHelpX && x < guiHelpX + guiHelpW
        && y >= guiHelpY && y < guiHelpY + 36
}

func guiHelpUpContains(_ x: Int, _ y: Int) -> Bool {
    x >= helpRailX() && x < helpRailX() + 28
        && y >= helpTextTop() && y < helpTextTop() + 28
}

func guiHelpDownContains(_ x: Int, _ y: Int) -> Bool {
    x >= helpRailX() && x < helpRailX() + 28
        && y >= helpBottom() - 28 && y < helpBottom()
}

/// Gives the room to the Help window: the whole
/// desktop is repainted in its new standing, as
/// its siblings' giving hands repaint it.
func guiSetFocusHelp() {
    if guiFocusHelp && !guiFocusTerminal && !guiFocusFiles
        && !guiFocusReader && !guiFocusWrite && !guiFocusBible
        && !guiFocusShield {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = false
    guiFocusShield = false
    guiFocusHelp = true
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Help window on its page's head.
func guiOpenHelp() {
    helpOpen = true
    helpScroll = 0
    guiSetFocusHelp()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// The Help window's maximize and restore, one
/// control, down the family's road: the page
/// keeps its wrapping (the table is hand-wrapped,
/// as the Shield's is) and simply shows more or
/// fewer of its lines.
func guiToggleHelpMaximize() {
    if guiHelpMaximized {
        guiHelpX = guiHelpSavedX
        guiHelpY = guiHelpSavedY
        guiHelpW = guiHelpSavedW
        guiHelpH = guiHelpSavedH
        guiHelpMaximized = false
    } else {
        guiHelpSavedX = guiHelpX
        guiHelpSavedY = guiHelpY
        guiHelpSavedW = guiHelpW
        guiHelpSavedH = guiHelpH
        guiHelpX = 16
        guiHelpY = guiWorkTop
        guiHelpW = framebufferWidth - 32
        guiHelpH = guiBarTop() - guiWorkTop - 8
        guiHelpMaximized = true
    }
    if helpScroll > helpMaxScroll() {
        helpScroll = helpMaxScroll()
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Scrolls the page by whole lines, clamped and
/// repainted, down the elders' road.
func helpScrollBy(_ lines: Int) {
    let target = min(max(helpScroll + lines, 0), helpMaxScroll())
    if target == helpScroll { return }
    helpScroll = target
    pointerHide()
    guiPaintHelpWindow()
    pointerShow()
}

/// Paints the Help window's maximize box: an empty
/// square, or the restore pair when the window
/// stands maximized, down the family's road.
func guiPaintHelpMaxBox() {
    let boxX = guiMaxBoxX(guiHelpX, guiHelpW)
    let boxY = guiHelpY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if guiHelpMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Help window's title bar: cardinal
/// when it holds the room, dim when it does not,
/// its name, and its two boxes.
func guiPaintHelpTitleBar(_ held: Bool) {
    guiFillRect(guiHelpX, guiHelpY, guiHelpW, 36,
                held ? guiHeldBarColor
                    : (guiFocusHelp ? guiCardinalColor
                                    : guiDimBarColor))
    guiDrawText(guiHelpX + 16, guiHelpY + 10, 2,
                guiHelpTitle, guiWhiteColor)
    guiPaintHelpMaxBox()
    guiPaintXBox(guiCloseBoxX(guiHelpX, guiHelpW),
                 guiHelpY + guiBoxTop)
}

/// Paints the Help window whole: its shadow, its
/// parchment body and border, its title bar, the
/// page's visible lines in their colors, and the
/// rail's two boxes at the body's right.
func guiPaintHelpWindow() {
    guiFillRect(guiHelpX + 10, guiHelpY + 12, guiHelpW,
                guiHelpH, guiShadowColor)
    guiFillRect(guiHelpX, guiHelpY, guiHelpW, guiHelpH,
                guiParchmentColor)
    guiFillRect(guiHelpX, guiHelpY, guiHelpW, 2,
                guiBorderColor)
    guiFillRect(guiHelpX, guiHelpY + guiHelpH - 2,
                guiHelpW, 2, guiBorderColor)
    guiFillRect(guiHelpX, guiHelpY, 2, guiHelpH,
                guiBorderColor)
    guiFillRect(guiHelpX + guiHelpW - 2, guiHelpY, 2,
                guiHelpH, guiBorderColor)
    guiPaintHelpTitleBar(false)
    var row = 0
    while row < helpVisibleRows() {
        let line = helpScroll + row
        if line >= helpLines.count { break }
        guiDrawText(helpTextX(),
                    helpTextTop() + row * 24, 2,
                    helpLines[line],
                    helpLineFlags[line]
                        ? guiCardinalColor : guiInkColor)
        row += 1
    }
    guiPaintScrollButton(helpRailX(), helpTextTop(), true,
                         helpScroll > 0)
    guiPaintScrollButton(helpRailX(), helpBottom() - 28,
                         false, helpScroll < helpMaxScroll())
}

/// A press inside the Help window, asked as its
/// siblings are: its close box closes it alone;
/// its maximize box trades its size; its title
/// bar takes hold for the drag, unless the press
/// is the second of a pair; its rail steps the
/// page a line; any other press gives the window
/// the room.
func guiPressHelp(_ x: Int, _ y: Int) -> Bool {
    if !helpOpen { return false }
    if !guiHelpContains(x, y) { return false }
    if guiHelpCloseContains(x, y) {
        helpOpen = false
        if guiFocusHelp {
            guiFocusHelp = false
            guiFocusTerminal = termOpen
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiHelpMaxContains(x, y) {
        guiSetFocusHelp()
        guiToggleHelpMaximize()
        return true
    }
    if guiHelpTitleContains(x, y) {
        guiSetFocusHelp()
        if helpTitlePressArmed
            && ticks &- helpTitlePressTick
                <= guiDoubleClickTicks {
            helpTitlePressArmed = false
            guiToggleHelpMaximize()
            return true
        }
        helpTitlePressArmed = true
        helpTitlePressTick = ticks
        guiBeginDrag(9, x, y)
        return true
    }
    if guiHelpUpContains(x, y) {
        guiSetFocusHelp()
        helpScrollBy(-1)
        return true
    }
    if guiHelpDownContains(x, y) {
        guiSetFocusHelp()
        helpScrollBy(1)
        return true
    }
    guiSetFocusHelp()
    return true
}

/// The `howdoi` command's work, down the `bible`
/// command's own road: in the Terminal, the
/// window opens where the conversation stands;
/// at the text console, the face opens with the
/// window standing on it.
func runHowdoiCommand() {
    if consoleInTerminal {
        guiOpenHelp()
    } else {
        helpWantedAtFace = true
        runGui()
    }
}
