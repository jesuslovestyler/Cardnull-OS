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
// Milestone 35: the Shield window — the eighth window, and
// the house's law, given a face.
//
// The Shield was settled as system law on November 7,
// 2026, before it had any window: the family filter on,
// with no off switch anywhere; no telemetry, no tracking,
// ever. This window is that law's face on the desktop. It
// builds nothing new underneath — there is nothing to
// build, and the window does not pretend otherwise. What
// it does is say the standing, in plain words, where the
// person at the machine can read it:
//
//   The Shield is on guard.
//   The family filter is on, and there is no way to turn
//   it off — no switch, no setting, no secret door.
//   Nothing done here is sent anywhere.
//   Nothing from the network is let in to any window;
//   the wire answers only the errands the person began.
//
// Those are checkable words, and the window carries one
// live line to prove the last of them: the count of
// frames this machine has actually sent since it woke
// (netSpeechCount, kept at the wire's one sending door).
// Every one of those sends belongs to a conversation the
// person at the keyboard began — the `net` command's
// errands, and a held lease's own renewals of an errand
// already begun. The machine originates nothing.
//
// The doors in are two, both plain words: the Welcome
// card's "The Shield" button — the card grown a second
// row taller where the screen allows, beneath the
// Bible's — and the Terminal's `shield` command. The
// window keeps the family's manners entire: the room by
// focus, the drag by its title bar, the maximize box and
// the double-click, its close box closing it alone. It
// has no scroll and no settings, by design: a guard's
// standing is a page, not a document, and there is
// nothing in it to set.
// ---------------------------------------------------------------------------

var shieldOpen = false
var guiFocusShield = false
var guiShieldX = 0
var guiShieldY = 0
var guiShieldW = 0
var guiShieldH = 0
var shieldSavedX = 0
var shieldSavedY = 0
var shieldSavedW = 0
var shieldSavedH = 0
var shieldMaximized = false
var shieldTitlePressArmed = false
var shieldTitlePressTick: UInt64 = 0

/// The `shield` command's word for the face, left when
/// the command is typed at the text console.
var shieldWantedAtFace = false

let guiShieldTitle: StaticString = "The Shield"
let guiShieldHeading: StaticString = "The Shield is on guard."
let guiShieldFilterLine: StaticString =
    "The family filter is on."
let guiShieldNoOffLine1: StaticString =
    "There is no way to turn it off:"
let guiShieldNoOffLine2: StaticString =
    "no switch, no setting, no secret door."
let guiShieldSentLine1: StaticString =
    "Nothing you do here is sent anywhere."
let guiShieldSentLine2: StaticString =
    "No watching, no reporting, no phoning"
let guiShieldSentLine3: StaticString =
    "home. Not now, not ever."
let guiShieldWireLine1: StaticString =
    "Nothing from the network is let in to"
let guiShieldWireLine2: StaticString =
    "any window. The wire answers only"
let guiShieldWireLine3: StaticString =
    "the errands you began."
let guiShieldCountLabel: StaticString =
    "Times spoken on the network: "
let guiShieldCountLine2: StaticString =
    "- every one asked for by you."
let guiShieldLawLine1: StaticString =
    "That is the law of this house,"
let guiShieldLawLine2: StaticString =
    "written into the system itself."

func shieldTextX() -> Int { guiShieldX + 16 }
func shieldTextTop() -> Int { guiShieldY + 52 }

func guiShieldContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiShieldX && x < guiShieldX + guiShieldW
        && y >= guiShieldY && y < guiShieldY + guiShieldH
}

func guiShieldCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiShieldX, guiShieldW)
        && x < guiCloseBoxX(guiShieldX, guiShieldW) + guiBoxW
        && y >= guiShieldY + guiBoxTop
        && y < guiShieldY + guiBoxTop + guiBoxH
}

func guiShieldMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiShieldX, guiShieldW)
        && x < guiMaxBoxX(guiShieldX, guiShieldW) + guiBoxW
        && y >= guiShieldY + guiBoxTop
        && y < guiShieldY + guiBoxTop + guiBoxH
}

func guiShieldTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiShieldX && x < guiShieldX + guiShieldW
        && y >= guiShieldY && y < guiShieldY + 36
}

/// Gives the room to the Shield window, by the family's
/// road.
func guiSetFocusShield() {
    if guiFocusShield && !guiFocusTerminal && !guiFocusFiles
        && !guiFocusReader && !guiFocusWrite && !guiFocusBible
        && !guiFocusHelp && !guiFocusSettings {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = false
    guiFocusShield = true
    guiFocusHelp = false
    guiFocusSettings = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Shield window on its standing page.
func guiOpenShield() {
    shieldOpen = true
    guiSetFocusShield()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// The Shield window's maximize and restore, one control,
/// down the family's road.
func guiToggleShieldMaximize() {
    if shieldMaximized {
        guiShieldX = shieldSavedX
        guiShieldY = shieldSavedY
        guiShieldW = shieldSavedW
        guiShieldH = shieldSavedH
        shieldMaximized = false
    } else {
        shieldSavedX = guiShieldX
        shieldSavedY = guiShieldY
        shieldSavedW = guiShieldW
        shieldSavedH = guiShieldH
        guiShieldX = 0
        guiShieldY = guiWorkTop
        guiShieldW = framebufferWidth
        guiShieldH = guiBarTop() - guiWorkTop
        shieldMaximized = true
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Paints the Shield window's maximize box, as its
/// siblings'.
func guiPaintShieldMaxBox() {
    let boxX = guiMaxBoxX(guiShieldX, guiShieldW)
    let boxY = guiShieldY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if shieldMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Shield window's title strip alone.
func guiPaintShieldTitleBar(_ held: Bool) {
    guiFillRect(guiShieldX, guiShieldY, guiShieldW, 36,
                held ? guiHeldBarColor
                    : (guiFocusShield ? guiCardinalColor
                                      : guiDimBarColor))
    guiDrawText(guiShieldX + 16, guiShieldY + 10, 2,
                guiShieldTitle, guiWhiteColor)
    guiPaintShieldMaxBox()
    guiPaintXBox(guiCloseBoxX(guiShieldX, guiShieldW),
                 guiShieldY + guiBoxTop)
}

/// Paints the Shield window whole: shadow, parchment body
/// and border — a page's colours, as its siblings wear —
/// its title strip, and the standing, line by line, in
/// plain words. The count line is composed as the Welcome
/// card composes its clicks: the words, then the number
/// the wire's own account keeps.
func guiPaintShieldWindow() {
    guiFillRect(guiShieldX + 10, guiShieldY + 12, guiShieldW,
                guiShieldH, guiShadowColor)
    guiFillRect(guiShieldX, guiShieldY, guiShieldW,
                guiShieldH, guiParchmentColor)
    guiFillRect(guiShieldX, guiShieldY, guiShieldW, 2,
                guiBorderColor)
    guiFillRect(guiShieldX, guiShieldY + guiShieldH - 2,
                guiShieldW, 2, guiBorderColor)
    guiFillRect(guiShieldX, guiShieldY, 2, guiShieldH,
                guiBorderColor)
    guiFillRect(guiShieldX + guiShieldW - 2, guiShieldY, 2,
                guiShieldH, guiBorderColor)
    guiPaintShieldTitleBar(false)
    let x = shieldTextX()
    var row = 0
    func line(_ text: StaticString, _ color: UInt32) {
        guiDrawText(x, shieldTextTop() + row * 16, 2, text,
                    color)
        row += 1
    }
    line(guiShieldHeading, guiCardinalColor)
    row += 1
    line(guiShieldFilterLine, guiInkColor)
    line(guiShieldNoOffLine1, guiInkColor)
    line(guiShieldNoOffLine2, guiInkColor)
    row += 1
    line(guiShieldSentLine1, guiInkColor)
    line(guiShieldSentLine2, guiInkColor)
    line(guiShieldSentLine3, guiInkColor)
    row += 1
    line(guiShieldWireLine1, guiInkColor)
    line(guiShieldWireLine2, guiInkColor)
    line(guiShieldWireLine3, guiInkColor)
    row += 1
    let countEnd = guiDrawText(
        x, shieldTextTop() + row * 16, 2, guiShieldCountLabel,
        guiInkColor)
    guiDrawDecimal(countEnd + 4, shieldTextTop() + row * 16,
                   2, netSpeechCount, guiInkColor)
    row += 1
    line(guiShieldCountLine2, guiInkColor)
    row += 1
    line(guiShieldLawLine1, guiInkColor)
    line(guiShieldLawLine2, guiInkColor)
}

/// A press inside the Shield window, asked as its siblings
/// are: its close box closes it alone — the room falling
/// to the Terminal when the Terminal stands; its maximize
/// box trades its size; its title bar takes hold for the
/// drag, unless the press is the second of a pair; any
/// other press gives the window the room. There is nothing
/// else in it to press: that is the point of the window.
func guiPressShield(_ x: Int, _ y: Int) -> Bool {
    if !shieldOpen { return false }
    if !guiShieldContains(x, y) { return false }
    if guiShieldCloseContains(x, y) {
        shieldOpen = false
        if guiFocusShield {
            guiFocusShield = false
            guiFocusTerminal = termOpen
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiShieldMaxContains(x, y) {
        guiSetFocusShield()
        guiToggleShieldMaximize()
        return true
    }
    if guiShieldTitleContains(x, y) {
        guiSetFocusShield()
        if shieldTitlePressArmed
            && ticks &- shieldTitlePressTick
                <= guiDoubleClickTicks {
            shieldTitlePressArmed = false
            guiToggleShieldMaximize()
            return true
        }
        shieldTitlePressArmed = true
        shieldTitlePressTick = ticks
        guiBeginDrag(8, x, y)
        return true
    }
    guiSetFocusShield()
    return true
}

/// The `shield` command's work, down the `bible` command's
/// own road: in the Terminal, the window opens where the
/// conversation stands; at the text console, the face
/// opens with the window standing on it.
func runShieldCommand() {
    if consoleInTerminal {
        guiOpenShield()
    } else {
        shieldWantedAtFace = true
        runGui()
    }
}
