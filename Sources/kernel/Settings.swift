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
// Milestone 38: the Settings window — the tenth window, and
// the house's choices, in plain words.
//
// A settings window is honest only where the house truly
// has a choice to offer, so this page carries three, and
// no more:
//
//   The clock — whether the bar's clock reads in the
//   twelve-hour form ("3:45 PM") or the twenty-four-hour
//   form ("15:45"). Both shapes stand on the page as the
//   choices themselves, so the choosing is the seeing.
//
//   The mouse — Slower, Steady, or Faster: the pointer's
//   travel reckoned at half, as it is, or double, in
//   guiFinishMousePacket. Slower keeps the half-counts'
//   remainders, so a small movement is never rounded
//   away to nothing.
//
//   The Welcome card at the start — whether the desktop
//   opens with the greeting card standing and holding
//   the room. The standing default is the house's own
//   standing behaviour: the card closed, the Terminal
//   holding the room. The choice takes hold at the next
//   start, and the page says so.
//
// What is NOT here matters as much: the Shield has no
// setting, because its law is not a choice (milestone
// 35's window says why); the sound has no switch,
// because the house makes none of its own — its one
// phrase is sung only when it is asked for at the
// Terminal. A switch that governed nothing would be a
// lie drawn in a button's shape.
//
// The keeping: the choices are kept in a small plain
// file on the Cardnull disk, SETTINGS.TXT — three short
// lines a person can open and read, written by the disk
// family's own roads (hdCreateFile when it does not
// stand; its own sector rewritten when it does, the
// record being one fixed measure of forty-eight bytes).
// It is read once, as the face opens, before the first
// painting. Where no Cardnull disk answers, the choices
// still hold — until the machine is shut down — and the
// page's foot line says which keeping stands, in plain
// words, and is answered again at every choosing.
//
// The doors in are the family's two: the Welcome card's
// "Settings" button — the card grown a fourth row taller
// where the screen allows, beneath "How do I..." — and
// the Terminal's `settings` command. The window keeps
// the family's manners entire: the room by focus, the
// drag by its title bar, the maximize box and the
// double-click, its close box closing it alone. It has
// no scroll: the page is the whole of it.
// ---------------------------------------------------------------------------

var settingsOpen = false
var guiFocusSettings = false
var guiSettingsX = 0
var guiSettingsY = 0
var guiSettingsW = 0
var guiSettingsH = 0
var settingsSavedX = 0
var settingsSavedY = 0
var settingsSavedW = 0
var settingsSavedH = 0
var settingsMaximized = false
var settingsTitlePressArmed = false
var settingsTitlePressTick: UInt64 = 0

/// The `settings` command's word for the face, left when
/// the command is typed at the text console.
var settingsWantedAtFace = false

/// The choices themselves, at their standing defaults —
/// the house's own behaviour since before this window
/// stood: the clock in its twelve-hour form, the mouse
/// at its own pace, the Welcome card closed at the
/// start.
var settingsClock24 = false
var settingsMouseGear = 1
var settingsWelcomeAtStart = false

/// The Slower gear's kept remainders, one per axis: the
/// half of a count that has not yet whole-moved the
/// pointer, carried to the next packet so nothing is
/// rounded away.
var settingsRemX = 0
var settingsRemY = 0

/// The keeping's standing, as the page's foot line tells
/// it: 1 the choices are kept on the disk; 2 they last
/// only until shut down. Answered by the load at the
/// face's opening and by every save.
var settingsKept = 2

let guiSettingsTitle: StaticString = "Settings"
let guiSettingsHeading: StaticString =
    "Your choices, in plain words."
let guiSettingsClockLine: StaticString =
    "How should the clock read?"
let guiSettingsClock12Label: StaticString = "3:45 PM"
let guiSettingsClock24Label: StaticString = "15:45"
let guiSettingsMouseLine: StaticString =
    "How fast should the mouse move?"
let guiSettingsSlowerLabel: StaticString = "Slower"
let guiSettingsSteadyLabel: StaticString = "Steady"
let guiSettingsFasterLabel: StaticString = "Faster"
let guiSettingsWelcomeLine: StaticString =
    "Show the Welcome card at the start?"
let guiSettingsShowLabel: StaticString = "Show it"
let guiSettingsHideLabel: StaticString = "Do not show it"
let guiSettingsNextStartLine: StaticString =
    "It takes hold at the next start."
let guiSettingsKeptLine: StaticString =
    "Your choices are kept on your disk."
let guiSettingsSessionLine: StaticString =
    "No disk: they last until you shut down."

// The keeping's file: its name, its record's measure,
// and the record's three lines' places within it —
// line one at 0, line two at 16, line three at 32,
// each sixteen bytes: the word, its value, spaces to
// the line's end, and a newline at its last byte.
let settingsNameLength = 12
let settingsRecordLength = 48
let settingsRecordStage = 64

/// Lays a word of the keeping's staging, byte by byte
/// from its letters.
func settingsPutWord(_ base: UnsafeMutablePointer<UInt8>,
                     _ offset: Int,
                     _ letters: [UInt8]) {
    var index = 0
    while index < letters.count {
        base[offset + index] = letters[index]
        index += 1
    }
}

/// Stages the keeping's name in the path scratch, where
/// the disk family's scans read their sought names.
func settingsStageName() {
    let path = discPath()
    settingsPutWord(path, 0,
        [0x53, 0x45, 0x54, 0x54, 0x49, 0x4E, 0x47, 0x53,
         0x2E, 0x54, 0x58, 0x54])  // SETTINGS.TXT
}

/// Builds the record in the path scratch's upper field,
/// clear of the staged name: three lines of sixteen
/// bytes, as the file's head comment describes.
func settingsBuildRecord() {
    let stage = discPath()
    var index = 0
    while index < settingsRecordLength {
        stage[settingsRecordStage + index] = 0x20
        index += 1
    }
    stage[settingsRecordStage + 15] = 0x0A
    stage[settingsRecordStage + 31] = 0x0A
    stage[settingsRecordStage + 47] = 0x0A
    settingsPutWord(stage, settingsRecordStage,
        [0x43, 0x4C, 0x4F, 0x43, 0x4B, 0x3D])  // CLOCK=
    if settingsClock24 {
        settingsPutWord(stage, settingsRecordStage + 6,
            [0x32, 0x34])  // 24
    } else {
        settingsPutWord(stage, settingsRecordStage + 6,
            [0x31, 0x32])  // 12
    }
    settingsPutWord(stage, settingsRecordStage + 16,
        [0x4D, 0x4F, 0x55, 0x53, 0x45, 0x3D])  // MOUSE=
    if settingsMouseGear == 0 {
        settingsPutWord(stage, settingsRecordStage + 22,
            [0x53, 0x4C, 0x4F, 0x57])  // SLOW
    } else if settingsMouseGear == 2 {
        settingsPutWord(stage, settingsRecordStage + 22,
            [0x46, 0x41, 0x53, 0x54])  // FAST
    } else {
        settingsPutWord(stage, settingsRecordStage + 22,
            [0x4E, 0x4F, 0x52, 0x4D])  // NORM
    }
    settingsPutWord(stage, settingsRecordStage + 32,
        [0x53, 0x54, 0x41, 0x52, 0x54, 0x3D])  // START=
    if settingsWelcomeAtStart {
        settingsPutWord(stage, settingsRecordStage + 38,
            [0x59, 0x45, 0x53])  // YES
    } else {
        settingsPutWord(stage, settingsRecordStage + 38,
            [0x4E, 0x4F])  // NO
    }
}

/// Whether the buffer's bytes at a place spell a word.
func settingsSpells(_ buffer: UnsafeMutablePointer<UInt8>,
                    _ offset: Int,
                    _ letters: [UInt8]) -> Bool {
    var index = 0
    while index < letters.count {
        if buffer[offset + index] != letters[index] {
            return false
        }
        index += 1
    }
    return true
}

/// Reads the record from the disk buffer's first bytes
/// into the choices, when its three lines name
/// themselves as this house's keeping. Any line whose
/// value is not a known word leaves that choice at its
/// standing default — a stranger's file is never parsed
/// into nonsense.
func settingsParseRecord(_ buffer: UnsafeMutablePointer<UInt8>) {
    if !settingsSpells(buffer, 0,
        [0x43, 0x4C, 0x4F, 0x43, 0x4B, 0x3D]) { return }
    if !settingsSpells(buffer, 16,
        [0x4D, 0x4F, 0x55, 0x53, 0x45, 0x3D]) { return }
    if !settingsSpells(buffer, 32,
        [0x53, 0x54, 0x41, 0x52, 0x54, 0x3D]) { return }
    if settingsSpells(buffer, 6, [0x32, 0x34]) {
        settingsClock24 = true
    } else if settingsSpells(buffer, 6, [0x31, 0x32]) {
        settingsClock24 = false
    }
    if settingsSpells(buffer, 22,
        [0x53, 0x4C, 0x4F, 0x57]) {
        settingsMouseGear = 0
    } else if settingsSpells(buffer, 22,
        [0x46, 0x41, 0x53, 0x54]) {
        settingsMouseGear = 2
    } else if settingsSpells(buffer, 22,
        [0x4E, 0x4F, 0x52, 0x4D]) {
        settingsMouseGear = 1
    }
    if settingsSpells(buffer, 38, [0x59, 0x45, 0x53]) {
        settingsWelcomeAtStart = true
    } else if settingsSpells(buffer, 38, [0x4E, 0x4F]) {
        settingsWelcomeAtStart = false
    }
}

/// The face's opening reading of the keeping, called
/// once as the face arranges itself, before its first
/// painting: raise the disk; where a Cardnull disk
/// stands ready, the keeping is the disk's (the file's
/// words where the file stands, the defaults where it
/// does not — and a saving will plant it); where none
/// answers, the choices are the session's. Reading
/// never writes, and a foreign disk is never mistaken
/// for the house's: its state is not the ready one.
func settingsLoad() {
    hdRaise()
    if !hdFound || hdReadState() != hdStateReady {
        settingsKept = 2
        return
    }
    settingsKept = 1
    settingsStageName()
    if !hdScanDirectory(0, settingsNameLength) { return }
    if hdFoundSlot < 0 { return }
    if hdFoundLength < UInt32(settingsRecordLength) {
        return
    }
    if !hdReadSector(UInt64(hdFoundStart)) { return }
    settingsParseRecord(hdData())
}

/// Keeps the choices as they now stand, down the disk
/// family's own roads, and answers the keeping's
/// standing for the page's foot line: where the file
/// already stands at the record's measure, its own
/// sector is rewritten in place; where it does not
/// stand, it is planted whole; where no Cardnull disk
/// answers — or a standing file is not this keeping's
/// shape — the choices are the session's, and the foot
/// line will say so.
func settingsSave() {
    settingsBuildRecord()
    hdRaise()
    if !hdFound || hdReadState() != hdStateReady {
        settingsKept = 2
        return
    }
    settingsStageName()
    if !hdScanDirectory(0, settingsNameLength) {
        settingsKept = 2
        return
    }
    if hdFoundSlot >= 0 {
        if hdFoundLength != UInt32(settingsRecordLength) {
            settingsKept = 2
            return
        }
        let buffer = hdData()
        var step = 0
        while step < hdSectorBytes {
            buffer[step] = 0
            step += 1
        }
        let stage = discPath()
        step = 0
        while step < settingsRecordLength {
            buffer[step] =
                stage[settingsRecordStage + step]
            step += 1
        }
        if !hdWriteSector(UInt64(hdFoundStart)) {
            settingsKept = 2
            return
        }
        _ = hdFlush()
        settingsKept = 1
        return
    }
    let stage = discPath()
    let result = hdCreateFile(stage, 0, settingsNameLength,
                              stage + settingsRecordStage,
                              settingsRecordLength)
    settingsKept = result == 0 ? 1 : 2
}

func settingsTextX() -> Int { guiSettingsX + 32 }

func guiSettingsContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiSettingsX && x < guiSettingsX + guiSettingsW
        && y >= guiSettingsY && y < guiSettingsY + guiSettingsH
}

func guiSettingsCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiSettingsX, guiSettingsW)
        && x < guiCloseBoxX(guiSettingsX, guiSettingsW)
            + guiBoxW
        && y >= guiSettingsY + guiBoxTop
        && y < guiSettingsY + guiBoxTop + guiBoxH
}

func guiSettingsMaxContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiMaxBoxX(guiSettingsX, guiSettingsW)
        && x < guiMaxBoxX(guiSettingsX, guiSettingsW)
            + guiBoxW
        && y >= guiSettingsY + guiBoxTop
        && y < guiSettingsY + guiBoxTop + guiBoxH
}

func guiSettingsTitleContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiSettingsX && x < guiSettingsX + guiSettingsW
        && y >= guiSettingsY && y < guiSettingsY + 36
}

// The choice buttons' places, reckoned from the
// window's own ground so the painters and the press
// read one reckoning: the clock's pair, the mouse's
// three, the Welcome card's pair.
func settingsClockBtnY() -> Int { guiSettingsY + 124 }
func settingsMouseBtnY() -> Int { guiSettingsY + 228 }
func settingsWelcomeBtnY() -> Int { guiSettingsY + 332 }
let settingsBtnH = 44

func settingsInBtn(_ x: Int, _ y: Int, _ btnX: Int,
                   _ btnY: Int, _ btnW: Int) -> Bool {
    x >= btnX && x < btnX + btnW
        && y >= btnY && y < btnY + settingsBtnH
}

/// Gives the room to the Settings window, by the
/// family's road.
func guiSetFocusSettings() {
    if guiFocusSettings && !guiFocusTerminal
        && !guiFocusFiles && !guiFocusReader
        && !guiFocusWrite && !guiFocusBible
        && !guiFocusShield && !guiFocusHelp {
        return
    }
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = false
    guiFocusShield = false
    guiFocusHelp = false
    guiFocusSettings = true
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Opens the Settings window on its standing page.
func guiOpenSettings() {
    settingsOpen = true
    guiSetFocusSettings()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// The Settings window's maximize and restore, one
/// control, down the family's road.
func guiToggleSettingsMaximize() {
    if settingsMaximized {
        guiSettingsX = settingsSavedX
        guiSettingsY = settingsSavedY
        guiSettingsW = settingsSavedW
        guiSettingsH = settingsSavedH
        settingsMaximized = false
    } else {
        settingsSavedX = guiSettingsX
        settingsSavedY = guiSettingsY
        settingsSavedW = guiSettingsW
        settingsSavedH = guiSettingsH
        guiSettingsX = 0
        guiSettingsY = guiWorkTop
        guiSettingsW = framebufferWidth
        guiSettingsH = guiBarTop() - guiWorkTop
        settingsMaximized = true
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Paints the Settings window's maximize box, as its
/// siblings'.
func guiPaintSettingsMaxBox() {
    let boxX = guiMaxBoxX(guiSettingsX, guiSettingsW)
    let boxY = guiSettingsY + guiBoxTop
    guiFillRect(boxX, boxY, guiBoxW, guiBoxH, guiButtonColor)
    if settingsMaximized {
        guiFillRect(boxX + 17, boxY + 5, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 18, boxY + 6, 10, 10, guiButtonColor)
        guiFillRect(boxX + 10, boxY + 11, 12, 12, guiWhiteColor)
        guiFillRect(boxX + 11, boxY + 12, 10, 10, guiButtonColor)
    } else {
        guiFillRect(boxX + 13, boxY + 7, 14, 14, guiWhiteColor)
        guiFillRect(boxX + 14, boxY + 8, 12, 12, guiButtonColor)
    }
}

/// Paints the Settings window's title strip alone.
func guiPaintSettingsTitleBar(_ held: Bool) {
    guiFillRect(guiSettingsX, guiSettingsY, guiSettingsW, 36,
                held ? guiHeldBarColor
                    : (guiFocusSettings ? guiCardinalColor
                                        : guiDimBarColor))
    guiDrawText(guiSettingsX + 16, guiSettingsY + 10, 2,
                guiSettingsTitle, guiWhiteColor)
    guiPaintSettingsMaxBox()
    guiPaintXBox(guiCloseBoxX(guiSettingsX, guiSettingsW),
                 guiSettingsY + guiBoxTop)
}

/// Paints one choice button: the chosen one in cardinal
/// with white words, as a held room's title bar is
/// cardinal; the others in the family's button ground
/// with its border, waiting.
func guiPaintSettingsChoice(_ btnX: Int, _ btnY: Int,
                            _ btnW: Int,
                            _ label: StaticString,
                            _ chosen: Bool) {
    if chosen {
        guiFillRect(btnX, btnY, btnW, settingsBtnH,
                    guiCardinalColor)
    } else {
        guiFillRect(btnX, btnY, btnW, settingsBtnH,
                    guiButtonColor)
        guiFillRect(btnX, btnY, btnW, 2, guiBorderColor)
        guiFillRect(btnX, btnY + settingsBtnH - 2, btnW, 2,
                    guiBorderColor)
        guiFillRect(btnX, btnY, 2, settingsBtnH,
                    guiBorderColor)
        guiFillRect(btnX + btnW - 2, btnY, 2, settingsBtnH,
                    guiBorderColor)
    }
    let labelW = guiTextGlyphs(label) * 16
    guiDrawText(btnX + (btnW - labelW) / 2, btnY + 14, 2,
                label, chosen ? guiWhiteColor : guiInkColor)
}

/// Paints the Settings window whole: shadow, parchment
/// body and border, its title strip, and the three
/// choices — each its question in cardinal, its answers
/// as buttons with the standing choice marked — the
/// next-start note under the third, and the keeping's
/// word along the foot.
func guiPaintSettingsWindow() {
    guiFillRect(guiSettingsX + 10, guiSettingsY + 12,
                guiSettingsW, guiSettingsH, guiShadowColor)
    guiFillRect(guiSettingsX, guiSettingsY, guiSettingsW,
                guiSettingsH, guiParchmentColor)
    guiFillRect(guiSettingsX, guiSettingsY, guiSettingsW, 2,
                guiBorderColor)
    guiFillRect(guiSettingsX, guiSettingsY + guiSettingsH - 2,
                guiSettingsW, 2, guiBorderColor)
    guiFillRect(guiSettingsX, guiSettingsY, 2,
                guiSettingsH, guiBorderColor)
    guiFillRect(guiSettingsX + guiSettingsW - 2,
                guiSettingsY, 2, guiSettingsH,
                guiBorderColor)
    guiPaintSettingsTitleBar(false)
    let x = settingsTextX()
    guiDrawText(x, guiSettingsY + 52, 2, guiSettingsHeading,
                guiCardinalColor)
    guiDrawText(x, guiSettingsY + 92, 2, guiSettingsClockLine,
                guiCardinalColor)
    guiPaintSettingsChoice(x, settingsClockBtnY(), 176,
                           guiSettingsClock12Label,
                           !settingsClock24)
    guiPaintSettingsChoice(x + 192, settingsClockBtnY(), 176,
                           guiSettingsClock24Label,
                           settingsClock24)
    guiDrawText(x, guiSettingsY + 196, 2,
                guiSettingsMouseLine, guiCardinalColor)
    guiPaintSettingsChoice(x, settingsMouseBtnY(), 128,
                           guiSettingsSlowerLabel,
                           settingsMouseGear == 0)
    guiPaintSettingsChoice(x + 144, settingsMouseBtnY(),
                           128, guiSettingsSteadyLabel,
                           settingsMouseGear == 1)
    guiPaintSettingsChoice(x + 288, settingsMouseBtnY(),
                           128, guiSettingsFasterLabel,
                           settingsMouseGear == 2)
    guiDrawText(x, guiSettingsY + 300, 2,
                guiSettingsWelcomeLine, guiCardinalColor)
    guiPaintSettingsChoice(x, settingsWelcomeBtnY(), 160,
                           guiSettingsShowLabel,
                           settingsWelcomeAtStart)
    guiPaintSettingsChoice(x + 176, settingsWelcomeBtnY(),
                           224, guiSettingsHideLabel,
                           !settingsWelcomeAtStart)
    guiDrawText(x, guiSettingsY + 392, 2,
                guiSettingsNextStartLine, guiHintColor)
    guiDrawText(x, guiSettingsY + guiSettingsH - 40, 2,
                settingsKept == 1 ? guiSettingsKeptLine
                                  : guiSettingsSessionLine,
                guiInkColor)
}

/// Applies one choosing: the choice is set, the keeping
/// is written as it now stands, and the desktop is
/// painted whole — the marked button moves, the foot
/// line answers again, and the bar's clock, if its form
/// was the choosing, already reads in its new shape.
func guiChooseSettings() {
    settingsSave()
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// A press inside the Settings window, asked as its
/// siblings are: its close box closes it alone — the
/// room falling to the Terminal when the Terminal
/// stands; its maximize box trades its size; its title
/// bar takes hold for the drag, unless the press is the
/// second of a pair; a press on a choice button makes
/// that choice; any other press gives the window the
/// room.
func guiPressSettings(_ x: Int, _ y: Int) -> Bool {
    if !settingsOpen { return false }
    if !guiSettingsContains(x, y) { return false }
    if guiSettingsCloseContains(x, y) {
        settingsOpen = false
        if guiFocusSettings {
            guiFocusSettings = false
            guiFocusTerminal = termOpen
        }
        pointerHide()
        guiPaintDesktop()
        pointerShow()
        return true
    }
    if guiSettingsMaxContains(x, y) {
        guiSetFocusSettings()
        guiToggleSettingsMaximize()
        return true
    }
    if guiSettingsTitleContains(x, y) {
        guiSetFocusSettings()
        if settingsTitlePressArmed
            && ticks &- settingsTitlePressTick
                <= guiDoubleClickTicks {
            settingsTitlePressArmed = false
            guiToggleSettingsMaximize()
            return true
        }
        settingsTitlePressArmed = true
        settingsTitlePressTick = ticks
        guiBeginDrag(10, x, y)
        return true
    }
    let textX = settingsTextX()
    if settingsInBtn(x, y, textX, settingsClockBtnY(), 176) {
        guiSetFocusSettings()
        settingsClock24 = false
        guiChooseSettings()
        return true
    }
    if settingsInBtn(x, y, textX + 192,
                     settingsClockBtnY(), 176) {
        guiSetFocusSettings()
        settingsClock24 = true
        guiChooseSettings()
        return true
    }
    if settingsInBtn(x, y, textX, settingsMouseBtnY(), 128) {
        guiSetFocusSettings()
        settingsMouseGear = 0
        settingsRemX = 0
        settingsRemY = 0
        guiChooseSettings()
        return true
    }
    if settingsInBtn(x, y, textX + 144,
                     settingsMouseBtnY(), 128) {
        guiSetFocusSettings()
        settingsMouseGear = 1
        settingsRemX = 0
        settingsRemY = 0
        guiChooseSettings()
        return true
    }
    if settingsInBtn(x, y, textX + 288,
                     settingsMouseBtnY(), 128) {
        guiSetFocusSettings()
        settingsMouseGear = 2
        settingsRemX = 0
        settingsRemY = 0
        guiChooseSettings()
        return true
    }
    if settingsInBtn(x, y, textX,
                     settingsWelcomeBtnY(), 160) {
        guiSetFocusSettings()
        settingsWelcomeAtStart = true
        guiChooseSettings()
        return true
    }
    if settingsInBtn(x, y, textX + 176,
                     settingsWelcomeBtnY(), 224) {
        guiSetFocusSettings()
        settingsWelcomeAtStart = false
        guiChooseSettings()
        return true
    }
    guiSetFocusSettings()
    return true
}

/// The `settings` command's work, down the family's own
/// road: in the Terminal, the window opens where the
/// conversation stands; at the text console, the face
/// opens with the window standing on it.
func runSettingsCommand() {
    if consoleInTerminal {
        guiOpenSettings()
    } else {
        settingsWantedAtFace = true
        runGui()
    }
}
