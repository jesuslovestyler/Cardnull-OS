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
let guiPowerLabel: StaticString = "Power"
let guiAmLabel: StaticString = "AM"
let guiPmLabel: StaticString = "PM"
let guiPowerQuestion: StaticString = "What would you like to do?"
let guiShutDownLabel: StaticString = "Shut Down"
let guiRestartLabel: StaticString = "Restart"
let guiNotNowLabel: StaticString = "Not now"
let guiAreYouSure: StaticString = "Are you sure?"
let guiWillShutDown: StaticString = "The computer will shut down."
let guiWillRestart: StaticString = "The computer will restart."
let guiYesShutDown: StaticString = "Yes, shut down"
let guiYesRestart: StaticString = "Yes, restart"
let guiNoGoBack: StaticString = "No, go back"
let guiShuttingDownLine: StaticString = "Shutting down..."
let guiRestartingLine: StaticString = "Restarting..."
let guiBibleTitle: StaticString = "Bible"
let guiReadBibleLabel: StaticString = "Read the Bible"
let guiAllBooksLabel: StaticString = "< All books"
let guiBibleIndexName: StaticString = "BIBLE-IDX.TXT"
let guiBibleMagic: StaticString = "CARDNULL BIBLE 1"
let guiBibleNoRideLine: StaticString =
    "The Bible did not ride with the system files."
let guiSafeOffLine: StaticString =
    "You can turn the computer off now."
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

/// The Welcome card's Bible button (milestone 34): a wide
/// button beneath the house verse, in the row the card's
/// taller standing makes — "Read the Bible", the door to
/// the Bible window, standing on the desktop's greeting
/// card where a new reader already looks. It stands only
/// when the card's height gives it its own row clear of
/// the Click-me button's; on a short screen the card keeps
/// its old measure and the button is withheld, the layout's
/// own law — the `bible` command opens the window there.
func guiBibleButtonStands() -> Bool {
    guiWinH >= 360
}

func guiBibleButtonContains(_ x: Int, _ y: Int) -> Bool {
    guiBibleButtonStands()
        && x >= guiWinX + 32 && x < guiWinX + guiWinW - 32
        && y >= guiWinY + 232 && y < guiWinY + 276
}

func guiPaintBibleButton() {
    if !guiBibleButtonStands() { return }
    let buttonX = guiWinX + 32
    let buttonY = guiWinY + 232
    let buttonW = guiWinW - 64
    guiFillRect(buttonX, buttonY, buttonW, 44, guiButtonColor)
    guiFillRect(buttonX, buttonY, buttonW, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY + 42, buttonW, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY, 2, 44, guiBorderColor)
    guiFillRect(buttonX + buttonW - 2, buttonY, 2, 44,
                guiBorderColor)
    let labelW = guiTextGlyphs(guiReadBibleLabel) * 16
    guiDrawText(buttonX + (buttonW - labelW) / 2, buttonY + 14,
                2, guiReadBibleLabel, guiInkColor)
}

/// The Welcome card's Shield button (milestone 35): a
/// second wide button beneath the Bible's, in the row the
/// card's second growth makes — "The Shield", the door to
/// the Shield window, standing on the greeting card beside
/// the Bible's door, the house's two standings side by
/// side. It stands only when the card's height gives it
/// its own row clear of the Click-me button's; where it
/// does not, the `shield` command opens the window.
let guiShieldLabel: StaticString = "The Shield"

func guiShieldButtonStands() -> Bool {
    guiWinH >= 424
}

func guiShieldButtonContains(_ x: Int, _ y: Int) -> Bool {
    guiShieldButtonStands()
        && x >= guiWinX + 32 && x < guiWinX + guiWinW - 32
        && y >= guiWinY + 288 && y < guiWinY + 332
}

func guiPaintShieldButton() {
    if !guiShieldButtonStands() { return }
    let buttonX = guiWinX + 32
    let buttonY = guiWinY + 288
    let buttonW = guiWinW - 64
    guiFillRect(buttonX, buttonY, buttonW, 44, guiButtonColor)
    guiFillRect(buttonX, buttonY, buttonW, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY + 42, buttonW, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY, 2, 44, guiBorderColor)
    guiFillRect(buttonX + buttonW - 2, buttonY, 2, 44,
                guiBorderColor)
    let labelW = guiTextGlyphs(guiShieldLabel) * 16
    guiDrawText(buttonX + (buttonW - labelW) / 2, buttonY + 14,
                2, guiShieldLabel, guiInkColor)
}

/// The Welcome card's Help button (milestone 36): a
/// third wide button beneath the Shield's, in the
/// row the card's third growth makes — "How do
/// I...", the door to the Help window and its
/// plain answers. It stands only when the card's
/// height gives it its own row clear of the
/// Click-me button's; where it does not, the
/// `howdoi` command opens the window.
let guiHelpLabel: StaticString = "How do I..."

func guiHelpButtonStands() -> Bool {
    guiWinH >= 480
}

func guiHelpButtonContains(_ x: Int, _ y: Int) -> Bool {
    guiHelpButtonStands()
        && x >= guiWinX + 32 && x < guiWinX + guiWinW - 32
        && y >= guiWinY + 344 && y < guiWinY + 388
}

func guiPaintHelpButton() {
    if !guiHelpButtonStands() { return }
    let buttonX = guiWinX + 32
    let buttonY = guiWinY + 344
    let buttonW = guiWinW - 64
    guiFillRect(buttonX, buttonY, buttonW, 44, guiButtonColor)
    guiFillRect(buttonX, buttonY, buttonW, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY + 42, buttonW, 2, guiBorderColor)
    guiFillRect(buttonX, buttonY, 2, 44, guiBorderColor)
    guiFillRect(buttonX + buttonW - 2, buttonY, 2, 44,
                guiBorderColor)
    let labelW = guiTextGlyphs(guiHelpLabel) * 16
    guiDrawText(buttonX + (buttonW - labelW) / 2, buttonY + 14,
                2, guiHelpLabel, guiInkColor)
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
    guiPaintBibleButton()
    guiPaintShieldButton()
    guiPaintHelpButton()
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
/// in their fixed order (Welcome, Terminal, Files, Reader,
/// Write — the Write window joining the order at milestone
/// 31, painted after the Reader and before the feather's
/// window, as a document window stands)
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
    if holder != 6 && writeOpen { guiPaintWriteWindow() }
    if holder != 7 && bibleOpen { guiPaintBibleWindow() }
    if holder != 8 && shieldOpen { guiPaintShieldWindow() }
    if holder != 9 && helpOpen { guiPaintHelpWindow() }
    if holder == 1 && welcomeOpen { guiPaintWindow() }
    if holder == 2 && termOpen { guiPaintTerminal() }
    if holder == 3 && filesOpen { guiPaintFilesWindow() }
    if holder == 4 && readerOpen { guiPaintReaderWindow() }
    if holder == 6 && writeOpen { guiPaintWriteWindow() }
    if holder == 7 && bibleOpen { guiPaintBibleWindow() }
    if holder == 8 && shieldOpen { guiPaintShieldWindow() }
    if holder == 9 && helpOpen { guiPaintHelpWindow() }
    // The feather's window stands over the elders while its
    // session stands (milestone 25): a guest's face has no
    // launcher in the bar to raise it from burial, and the
    // Terminal's ground would swallow it whole — so it is
    // never buried. Its focus is told by its title bar's
    // colour, exactly as the elders' is; among themselves
    // the elders keep their holder-last law untouched.
    if featherWinOpen { guiPaintFeatherWindow() }
    // The Power card stands over everything while it stands
    // (milestone 33): it is asking a question the reader must
    // answer or set aside before anything else is touched.
    if powerOpen { guiPaintPowerCard() }
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
/// window and 4 the Reader since milestone 19, 5 the
/// feather's window since milestone 25, and 6 the Write
/// window since milestone 31), where in its
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

/// The widest ground the clock ever needs cleared: the wall
/// clock's longest face — "12:00 PM" — with breathing room at
/// either side. (Milestone 33: the bar's clock became the
/// machine's own wall clock, read from its timekeeping chip;
/// before that it showed the uptime, which was wider and is
/// still the Terminal's own business.)
let guiClockPatchW = 176

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
var barWriteBtnX = 0
var barWelcomeBtnX = 0
var barHomeBtnX = 0
var barPowerBtnX = 0
var barClockEndX = 0

/// The Files launcher's word (milestone 19): the bar names
/// the window it calls, as it names the other two.
let guiFilesTitle: StaticString = "Files"

/// Reckons the bar's layout from the screen's own width and
/// the mouse's standing (which sets the status word's length).
/// The standing order: a 16 margin; the status in its plain
/// words; a gap; the Terminal launcher; a gap; the Files
/// launcher (milestone 19); a gap; the Write launcher
/// (milestone 31 — four launchers now, reckoned by the same
/// budget as the three were); a gap; the Welcome launcher;
/// then open ground; the clock, ending one gap
/// before Power (milestone 33); Power; and Home, closing one
/// margin from the right edge. If the row cannot stand at
/// this width, the gaps — never the furniture — give: first
/// the status gap narrows to 12, then the launchers' gap to
/// 8. If it still cannot stand, the status word itself —
/// a report, not a control, as the clock is — is withheld,
/// and the launchers' gap closes altogether; the controls
/// all stand whole at any width that can hold them in a
/// row at all. (Milestone 37: the crowding is reckoned
/// against the Power button, the launchers' true right-hand
/// neighbour — before, it was reckoned against Home alone,
/// and at 1024 wide the Welcome launcher's edge slipped
/// eight pixels beneath Power's.) The clock is painted
/// only when its whole patch stands clear of the Welcome
/// launcher with a gap to spare; otherwise it is simply not
/// there, as it was crowded off before — only now by decision,
/// stated, and not by collision.
var guiStatusVisible = true

/// Lays the launcher chain from the status's measure and
/// the two gaps, and returns the Welcome launcher's right
/// edge — the reckoning guiLayoutBar's ladder tries at
/// each of its steps.
func barChainEnd(_ statusW: Int, _ statusGap: Int,
                 _ btnGap: Int) -> Int {
    barTermBtnX = barStatusX + statusW + statusGap
    barFilesBtnX = barTermBtnX
        + guiBarButtonWidth(guiTermTitle) + btnGap
    barWriteBtnX = barFilesBtnX
        + guiBarButtonWidth(guiFilesTitle) + btnGap
    barWelcomeBtnX = barWriteBtnX
        + guiBarButtonWidth(guiWriteTitle) + btnGap
    return barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
}

func guiLayoutBar() {
    barStatusX = 16
    barStatusW = guiTextGlyphs(guiMouseStandingWord()) * 16
    guiStatusVisible = true
    barHomeBtnX = framebufferWidth - 16
        - guiBarButtonWidth(guiHomeLabel)
    barPowerBtnX = barHomeBtnX - 16
        - guiBarButtonWidth(guiPowerLabel)
    if barChainEnd(barStatusW, 24, 16) > barPowerBtnX - 8 {
        _ = barChainEnd(barStatusW, 12, 16)
    }
    if barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
        > barPowerBtnX - 8 {
        _ = barChainEnd(barStatusW, 12, 8)
    }
    if barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
        > barPowerBtnX - 8 {
        guiStatusVisible = false
        _ = barChainEnd(0, 0, 8)
    }
    if barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle)
        > barPowerBtnX - 8 {
        _ = barChainEnd(0, 0, 0)
    }
    barClockEndX = barPowerBtnX - 16
    guiClockVisible = barClockEndX - guiClockPatchW
        >= barWelcomeBtnX + guiBarButtonWidth(guiWindowTitle) + 24
}

func guiBarFilesContains(_ x: Int, _ y: Int) -> Bool {
    x >= barFilesBtnX
        && x < barFilesBtnX + guiBarButtonWidth(guiFilesTitle)
        && y >= guiBarTop() + 4 && y < guiBarTop() + 32
}

func guiBarWriteContains(_ x: Int, _ y: Int) -> Bool {
    x >= barWriteBtnX
        && x < barWriteBtnX + guiBarButtonWidth(guiWriteTitle)
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

/// The bar's Power button: the Home button's left-hand
/// neighbour, one gap away (milestone 33). Its standing stripe
/// shows while the Power card is open.
func guiBarPowerContains(_ x: Int, _ y: Int) -> Bool {
    x >= barPowerBtnX
        && x < barPowerBtnX + guiBarButtonWidth(guiPowerLabel)
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

/// Paints the bar's clock: the machine's own wall time, read
/// from its timekeeping chip once a second (milestone 33) and
/// spoken the way a kitchen clock speaks it — "9:05 AM",
/// "12:00 PM" — plain digits and the small word, nothing a
/// reader must decode. (Before this milestone the bar showed
/// the session's uptime, honestly labelled; the uptime is
/// still the Terminal's own business, under its own command.)
/// The line is right-anchored: it ends where the layout says
/// the clock's ground ends, and its start is reckoned from
/// its own width, so it stands in its place at any width. The
/// patch is first laid fresh in the bar's ground, so a
/// growing hour leaves no tail of its shorter self behind.
/// When the chip's answer is not sane the patch is left
/// empty rather than painted with a time the kernel does not
/// believe. On a screen too narrow to hold it beside the
/// launchers the layout withholds it, and it is simply not
/// painted.
func guiPaintClock() {
    guiClockSecond = ticks / 100
    if !guiClockVisible { return }
    let y = guiBarTop() + 10
    guiFillRect(barClockEndX - guiClockPatchW, guiBarTop() + 4,
                guiClockPatchW, 28, guiBarColor)
    if !rtcValid { return }
    let hour12 = rtcHour % 12 == 0 ? 12 : rtcHour % 12
    let hourDigits = hour12 >= 10 ? 2 : 1
    let startX = barClockEndX
        - (hourDigits * 16 + 16 + 32 + 16 + 32)
    var penX = guiDrawNumber(startX, y, UInt64(hour12),
                             guiHintColor)
    guiDrawGlyph(penX, y, 2, 0x3A, guiHintColor)
    penX += 16
    guiDrawTwoDigits(penX, y, UInt64(rtcMinute), guiHintColor)
    penX += 32
    penX += 16
    guiDrawText(penX, y, 2,
                rtcHour >= 12 ? guiPmLabel : guiAmLabel,
                guiHintColor)
}

/// Paints the bottom bar whole: its ground, the gold rule
/// along its head, the mouse's standing in plain words, the
/// four launchers at their reckoned places (Terminal,
/// Files, Write, Welcome — milestones 19 and 31), the
/// clock, the Power button (milestone 33), and the Home
/// button.
func guiPaintBar() {
    let top = guiBarTop()
    guiFillRect(0, top, framebufferWidth, guiBarHeight, guiBarColor)
    guiFillRect(0, top, framebufferWidth, 2, guiGoldColor)
    if guiStatusVisible {
        guiDrawText(barStatusX, top + 10, 2,
                    guiMouseStandingWord(), guiHintColor)
    }
    guiPaintBarButton(barTermBtnX,
                      guiBarButtonWidth(guiTermTitle),
                      guiTermTitle, termOpen)
    guiPaintBarButton(barFilesBtnX,
                      guiBarButtonWidth(guiFilesTitle),
                      guiFilesTitle, filesOpen)
    guiPaintBarButton(barWriteBtnX,
                      guiBarButtonWidth(guiWriteTitle),
                      guiWriteTitle, writeOpen)
    guiPaintBarButton(barWelcomeBtnX,
                      guiBarButtonWidth(guiWindowTitle),
                      guiWindowTitle, welcomeOpen)
    guiPaintClock()
    guiPaintBarButton(barPowerBtnX,
                      guiBarButtonWidth(guiPowerLabel),
                      guiPowerLabel, powerOpen)
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
/// by the same rule while its session stands. Milestone 31
/// names a sixth, the Write window, served by the same rule
/// again.
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
    } else if window == 6 {
        dragOffsetX = px - guiWriteX
        dragOffsetY = py - guiWriteY
        dragRectX = guiWriteX
        dragRectY = guiWriteY
        dragRectW = guiWriteW
        dragRectH = guiWriteH
    } else if window == 5 {
        dragOffsetX = px - guiFeatherX
        dragOffsetY = py - guiFeatherY
        dragRectX = guiFeatherX
        dragRectY = guiFeatherY
        dragRectW = guiFeatherW
        dragRectH = guiFeatherH
    } else if window == 7 {
        dragOffsetX = px - guiBibleX
        dragOffsetY = py - guiBibleY
        dragRectX = guiBibleX
        dragRectY = guiBibleY
        dragRectW = guiBibleW
        dragRectH = guiBibleH
    } else if window == 8 {
        dragOffsetX = px - guiShieldX
        dragOffsetY = py - guiShieldY
        dragRectX = guiShieldX
        dragRectY = guiShieldY
        dragRectW = guiShieldW
        dragRectH = guiShieldH
    } else if window == 9 {
        dragOffsetX = px - guiHelpX
        dragOffsetY = py - guiHelpY
        dragRectX = guiHelpX
        dragRectY = guiHelpY
        dragRectW = guiHelpW
        dragRectH = guiHelpH
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
    } else if window == 6 {
        guiPaintWriteTitleBar(true)
    } else if window == 5 {
        guiPaintFeatherTitleBar(true)
    } else if window == 7 {
        guiPaintBibleTitleBar(true)
    } else if window == 8 {
        guiPaintShieldTitleBar(true)
    } else if window == 9 {
        guiPaintHelpTitleBar(true)
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
    } else if carried == 6 {
        moved = dragRectX != guiWriteX || dragRectY != guiWriteY
        guiWriteX = dragRectX
        guiWriteY = dragRectY
    } else if carried == 7 {
        moved = dragRectX != guiBibleX || dragRectY != guiBibleY
        guiBibleX = dragRectX
        guiBibleY = dragRectY
    } else if carried == 8 {
        moved = dragRectX != guiShieldX || dragRectY != guiShieldY
        guiShieldX = dragRectX
        guiShieldY = dragRectY
    } else if carried == 9 {
        moved = dragRectX != guiHelpX || dragRectY != guiHelpY
        guiHelpX = dragRectX
        guiHelpY = dragRectY
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
    } else if carried == 6 {
        guiPaintWriteTitleBar(false)
    } else if carried == 7 {
        guiPaintBibleTitleBar(false)
    } else if carried == 8 {
        guiPaintShieldTitleBar(false)
    } else if carried == 9 {
        guiPaintHelpTitleBar(false)
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
        || guiFocusWrite || guiFocusBible || guiFocusShield
        || guiFocusHelp
    if guiFocusTerminal == toTerminal && !filesHeld { return }
    guiFocusTerminal = toTerminal
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = false
    guiFocusShield = false
    guiFocusHelp = false
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
        if termOpen && !guiFocusFiles && !guiFocusReader
            && !guiFocusWrite && !guiFocusBible
            && !guiFocusShield && !guiFocusHelp {
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
    if guiBibleButtonContains(x, y) {
        guiOpenBible()
        return true
    }
    if guiShieldButtonContains(x, y) {
        guiOpenShield()
        return true
    }
    if guiHelpButtonContains(x, y) {
        guiOpenHelp()
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
    // While the Power card stands (milestone 33), a press is
    // the card's affair alone: the question it asks — shut
    // down, restart, or not now — is answered or set aside
    // before the desktop is touched again.
    if powerOpen {
        _ = guiPressPower(x, y)
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
    if !(writeOpen && guiWriteTitleContains(x, y)
        && !guiWriteCloseContains(x, y)
        && !guiWriteMaxContains(x, y)) {
        writeTitlePressArmed = false
    }
    if !(filesOpen && guiFilesListContains(x, y)) {
        filesPressArmed = false
    }
    if y >= guiBarTop() {
        if guiBarHomeContains(x, y) {
            guiWantsHome = true
            return
        }
        if guiBarPowerContains(x, y) {
            guiOpenPower()
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
        if guiBarWriteContains(x, y) {
            if writeOpen {
                guiSetFocusWrite()
            } else {
                guiOpenWrite()
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
    var candidate = 9
    while candidate >= 1 {
        if candidate != holder && candidate != 5
            && guiPressWindow(candidate, x, y) { return }
        candidate -= 1
    }
    guiSetFocus(false)
}

/// Asks one window, by its number in the standing order
/// (1 the Welcome card, 2 the Terminal, 3 the Files window,
/// 4 the Reader, 6 the Write window), to answer a press —
/// the seniority walk's
/// one step, so guiPressAt's order is a reckoning and not a
/// thicket. The two elder windows answer as they always have;
/// the two younger ones first check that they stand at all.
func guiPressWindow(_ window: Int, _ x: Int, _ y: Int) -> Bool {
    if window == 1 { return guiPressWelcome(x, y) }
    if window == 2 { return guiPressTerminal(x, y) }
    if window == 3 { return guiPressFiles(x, y) }
    if window == 6 { return guiPressWrite(x, y) }
    if window == 7 { return guiPressBible(x, y) }
    if window == 8 { return guiPressShield(x, y) }
    if window == 9 { return guiPressHelp(x, y) }
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
    if window == 6 {
        return (guiWriteX, guiWriteY, guiWriteW, guiWriteH)
    }
    if window == 7 {
        return (guiBibleX, guiBibleY, guiBibleW, guiBibleH)
    }
    if window == 8 {
        return (guiShieldX, guiShieldY, guiShieldW, guiShieldH)
    }
    if window == 9 {
        return (guiHelpX, guiHelpY, guiHelpW, guiHelpH)
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
    if window == 6 { return writeOpen }
    if window == 7 { return bibleOpen }
    if window == 8 { return shieldOpen }
    if window == 9 { return helpOpen }
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
/// window (3), the Reader (4), the Write window (6), or
/// the Welcome side, which is no window holding it (1) —
/// and the desktop is
/// repainted whole in its new standing, the holder
/// painted last and on top, exactly the face's own rule.
/// A call that changes nothing paints nothing.
func guiSessionFocus(_ window: Int) {
    let feather = window == 5
    let terminal = window == 2
    let files = window == 3
    let reader = window == 4
    let write = window == 6
    let bible = window == 7
    let shield = window == 8
    let help = window == 9
    if guiFocusFeather == feather && guiFocusTerminal == terminal
        && guiFocusFiles == files && guiFocusReader == reader
        && guiFocusWrite == write && guiFocusBible == bible
        && guiFocusShield == shield && guiFocusHelp == help {
        return
    }
    guiFocusFeather = feather
    guiFocusTerminal = terminal
    guiFocusFiles = files
    guiFocusReader = reader
    guiFocusWrite = write
    guiFocusBible = bible
    guiFocusShield = shield
    guiFocusHelp = help
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
        if guiBarWriteContains(x, y) {
            if writeOpen { guiSessionFocus(6) }
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
    var candidate = 9
    while candidate >= 1 {
        if candidate != holder && candidate != 5
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
    // While the Power card stands (milestone 33), a turning
    // is no one's: the card's question is answered by hand
    // or set aside, not scrolled past.
    if powerOpen { return }
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
    var candidate = 9
    while candidate >= 1 {
        if candidate != holder && candidate != 5
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
    if window == 6 {
        if guestWindowed {
            guiSessionFocus(6)
        } else {
            guiSetFocusWrite()
        }
        if writeMode == 1 {
            writeListScrollBy(-guiWheelStep * delta)
        } else {
            writeScrollBy(-guiWheelStep * delta)
        }
        return true
    }
    if window == 7 {
        if guestWindowed {
            guiSessionFocus(7)
        } else {
            guiSetFocusBible()
        }
        bibleScrollBy(-guiWheelStep * delta)
        return true
    }
    if window == 8 {
        // The Shield's page does not scroll — there is
        // nothing in it to set or to hunt for; the wheel
        // over it only gives it the room (milestone 35).
        if guestWindowed {
            guiSessionFocus(8)
        } else {
            guiSetFocusShield()
        }
        return true
    }
    if window == 9 {
        if guestWindowed {
            guiSessionFocus(9)
        } else {
            guiSetFocusHelp()
        }
        helpScrollBy(-guiWheelStep * delta)
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
    let wantWrite = writeWantedAtFace
    writeWantedAtFace = false
    let wantBible = bibleWantedAtFace
    bibleWantedAtFace = false
    let wantShield = shieldWantedAtFace
    shieldWantedAtFace = false
    let wantHelp = helpWantedAtFace
    helpWantedAtFace = false
    if !useFramebuffer {
        writeLine(guiNoScreenLine)
        return
    }
    // The face's arrangement (milestone 14): the Welcome card
    // compact at the left, for when it is called up; the
    // Terminal large over the work area — a modest inset from
    // the edges, under the desktop's name, above the bar.
    guiWinW = min(448, framebufferWidth - 32)
    // Milestone 34: the card stands a row taller where the
    // screen allows, for the Bible button's row beneath the
    // verse (see guiPaintBibleButton); milestone 35 grows
    // it a second row for the Shield button's. On a short
    // screen it keeps the measure the screen affords and
    // the buttons are withheld by their own standings.
    guiWinH = min(480, framebufferHeight - guiBarHeight - 140)
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
    // Milestone 31's window joins the arrangement: a page's
    // shape standing off-centre over the Terminal, reckoned
    // as the Reader's is — its width and height from the
    // screen's own measure, its place clamped inside the
    // work area by the same two clamps.
    guiWriteW = min(720, framebufferWidth - 32)
    guiWriteH = min(520, guiBarTop() - guiWorkTop - 24)
    guiWriteX = min(280, framebufferWidth - guiWriteW - 16)
    guiWriteY = 112
    if guiWriteY + guiWriteH > guiBarTop() - 8 {
        guiWriteY = guiBarTop() - 8 - guiWriteH
    }
    if guiWriteY < guiWorkTop { guiWriteY = guiWorkTop }
    // Milestone 34's window joins the arrangement: the Bible
    // window, a reader's shape standing over the Terminal's
    // right side, reckoned as the Reader's is.
    guiBibleW = min(688, framebufferWidth - 32)
    guiBibleH = min(520, guiBarTop() - guiWorkTop - 24)
    guiBibleX = min(300, framebufferWidth - guiBibleW - 16)
    guiBibleY = 112
    if guiBibleY + guiBibleH > guiBarTop() - 8 {
        guiBibleY = guiBarTop() - 8 - guiBibleH
    }
    if guiBibleY < guiWorkTop { guiBibleY = guiWorkTop }
    bibleOpen = false
    bibleReading = false
    bibleScroll = 0
    bibleListScroll = 0
    // Milestone 35's window joins the arrangement: the
    // Shield window, a page's shape standing a step down
    // and left of the Bible window's place, reckoned as
    // its siblings' are.
    guiShieldW = min(688, framebufferWidth - 32)
    guiShieldH = min(420, guiBarTop() - guiWorkTop - 24)
    guiShieldX = min(232, framebufferWidth - guiShieldW - 16)
    guiShieldY = 128
    if guiShieldY + guiShieldH > guiBarTop() - 8 {
        guiShieldY = guiBarTop() - 8 - guiShieldH
    }
    if guiShieldY < guiWorkTop { guiShieldY = guiWorkTop }
    shieldOpen = false
    // Milestone 36's window joins the arrangement: the
    // Help window, a reading page's shape on the Bible
    // window's own ground, reckoned as its siblings'
    // are.
    guiHelpW = min(688, framebufferWidth - 32)
    guiHelpH = min(520, guiBarTop() - guiWorkTop - 24)
    guiHelpX = min(300, framebufferWidth - guiHelpW - 16)
    guiHelpY = 112
    if guiHelpY + guiHelpH > guiBarTop() - 8 {
        guiHelpY = guiBarTop() - 8 - guiHelpH
    }
    if guiHelpY < guiWorkTop { guiHelpY = guiWorkTop }
    helpOpen = false
    // Milestone 33's card joins the arrangement: the Power
    // card, centred over the work area — the one card that is
    // never carried about, for the question it asks should be
    // answered where it stands.
    guiPowerW = min(560, framebufferWidth - 32)
    guiPowerH = min(308, guiBarTop() - guiWorkTop - 24)
    guiPowerX = (framebufferWidth - guiPowerW) / 2
    guiPowerY = guiWorkTop
        + (guiBarTop() - guiWorkTop - guiPowerH) / 2
    powerOpen = false
    powerConfirm = 0
    welcomeOpen = false
    termMaximized = false
    termSavedX = guiTermX
    termSavedY = guiTermY
    termSavedW = guiTermW
    termSavedH = guiTermH
    filesOpen = false
    readerOpen = false
    writeOpen = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
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
    writeMaximized = false
    writeSavedX = guiWriteX
    writeSavedY = guiWriteY
    writeSavedW = guiWriteW
    writeSavedH = guiWriteH
    bibleMaximized = false
    bibleSavedX = guiBibleX
    bibleSavedY = guiBibleY
    bibleSavedW = guiBibleW
    bibleSavedH = guiBibleH
    guiFocusBible = false
    shieldMaximized = false
    shieldSavedX = guiShieldX
    shieldSavedY = guiShieldY
    shieldSavedW = guiShieldW
    shieldSavedH = guiShieldH
    guiFocusShield = false
    filesScroll = 0
    filesSelected = -1
    filesPressArmed = false
    filesTitlePressArmed = false
    readerTitlePressArmed = false
    writeTitlePressArmed = false
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
    // The wall clock's first reading (milestone 33), taken
    // before the first painting so the bar opens already
    // telling the time.
    rtcReadTime()
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
    if wantWrite {
        guiOpenWrite()
    }
    if wantBible {
        guiOpenBible()
    }
    if wantShield {
        guiOpenShield()
    }
    if wantHelp {
        guiOpenHelp()
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
            if powerOpen {
                // Milestone 33: while the Power card stands,
                // the keyboard is the card's alone: Escape sets
                // the card aside, and every other key is let
                // go — nothing is typed anywhere while the
                // question stands.
                e0Pending = false
                if code == 0x01 {          // Esc, pressed
                    guiClosePower()
                }
            } else if termOpen && guiFocusTerminal {
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
            } else if writeOpen && guiFocusWrite {
                if e0Pending {
                    e0Pending = false
                    writeExtendedKey(code)
                } else if code == 0xE0 {
                    e0Pending = true
                } else {
                    writeTakeKey(code)
                }
            } else if e0Pending {
                e0Pending = false
                guiScrollKey(code)
            } else if code == 0xE0 {
                e0Pending = true
            } else if code == 0x01 {          // Esc, pressed
                // Milestone 34: in the Bible window, Escape
                // climbs one step before it goes home — from
                // a book back to the list of books, as a
                // reader's hand expects; in the list it goes
                // home as it always has.
                if bibleOpen && guiFocusBible && bibleReading {
                    bibleBackToList()
                } else {
                    guiWantsHome = true
                }
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
        // The bar's clock, once a second: the time is read
        // fresh from the machine's own chip, and only its own
        // patch is repainted, in the pointer's hidden moment.
        if guiClockVisible && ticks / 100 != guiClockSecond {
            rtcReadTime()
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
    } else if guiFocusBible && bibleOpen {
        if code == 0x48 {
            bibleScrollBy(-1)
        } else if code == 0x50 {
            bibleScrollBy(1)
        } else if code == 0x49 {
            bibleScrollBy(-bibleVisibleRows())
        } else if code == 0x51 {
            bibleScrollBy(bibleVisibleRows())
        }
    } else if guiFocusHelp && helpOpen {
        if code == 0x48 {
            helpScrollBy(-1)
        } else if code == 0x50 {
            helpScrollBy(1)
        } else if code == 0x49 {
            helpScrollBy(-helpVisibleRows())
        } else if code == 0x51 {
            helpScrollBy(helpVisibleRows())
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
