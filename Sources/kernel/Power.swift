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
// Milestone 33: the wall clock, and the power to leave.
//
// Two gifts, both spoken in plain words on the desktop.
//
// The clock: the machine keeps its own time in a small
// battery-kept chip (the CMOS real-time clock, at ports
// 0x70/0x71) — the same chip that has told PCs the time since
// the beginning. The bar reads it once a second and paints
// what it says the way a kitchen clock speaks it. The kernel
// keeps no timezone of its own and makes no correction: the
// time shown is the machine's own time, exactly as its owner
// set it. (Before this milestone the bar showed the uptime,
// honestly labelled; uptime is still the Terminal's business,
// under the shell's own `uptime` command.)
//
// The leaving: the bar gains a Power button, at the Home
// button's left hand. It opens a card — the Power card —
// asking in plain words what the reader would like to do:
// Shut Down, Restart, or Not now. Either leaving is asked
// twice: the card then asks "Are you sure?" and only a plain
// "Yes" acts, so a stray click can never kill the machine.
// The card holds the room while it stands: presses elsewhere
// are the card's affair and do nothing, the wheel does
// nothing, and Escape sets the card aside.
//
// Shutting down asks the machine's own power tables (ACPI,
// parsed once at boot from the bootloader's word) to enter
// the sleeping-off state, S5: the FADT names the control
// register, the DSDT's _S5_ package names the sleep value to
// write there. Restart walks the two oldest roads — the
// keyboard controller's reset line, then the reset control
// register — which between them answer on every machine this
// kernel has met. If no road answers, the screen says so in
// plain words and rests: better an honest screen than a
// pretend one.
// ---------------------------------------------------------------------------

/// The Power card's standing: open or not, and — while open —
/// which question it is asking: 0 choosing (Shut Down /
/// Restart / Not now), 1 asking after Shut Down, 2 asking
/// after Restart.
var powerOpen = false
var powerConfirm = 0

/// The Power card's place and shape, reckoned in runGui's
/// arrangement: centred over the work area, never carried.
var guiPowerX = 0
var guiPowerY = 0
var guiPowerW = 0
var guiPowerH = 0

/// The wall clock's latest reading, kept from the chip in
/// twenty-four-hour form; rtcValid is false when the chip's
/// answer was not sane, and the bar then paints no time
/// rather than a wrong one.
var rtcHour = 0
var rtcMinute = 0
var rtcSecond = 0
var rtcValid = false

/// The power tables' yield, gathered once at boot: the PM1
/// control ports and the S5 sleep values the DSDT named.
/// powerAcpiReady is true only when both halves were found.
var powerPm1a: UInt64 = 0
var powerPm1b: UInt64 = 0
var powerSlpTypA: UInt64 = 0
var powerSlpTypB: UInt64 = 0
var powerAcpiReady = false

/// One register of the timekeeping chip: the address port
/// names it, the data port carries it.
func rtcRegister(_ reg: UInt8) -> UInt8 {
    cardnullOutb(0x70, reg)
    return cardnullInb(0x71)
}

/// A packed-BCD byte as a plain number: the chip's older
/// dialect, which register B says whether it is speaking.
func rtcFromBcd(_ byte: UInt8) -> Int {
    Int(byte & 0x0F) + Int(byte >> 4) * 10
}

/// Reads the wall time from the chip into the keeping above.
/// The read is taken twice and believed only when the two
/// agree — a read straddling the second's turning would
/// otherwise mix two moments — and register A's
/// update-in-progress flag is waited out first, within a
/// bound. Register B's own word says whether the numbers
/// are binary or packed BCD, and whether the hour is kept
/// in twelve-hour form with a PM flag (the hour byte's top
/// bit) or in twenty-four-hour form. An answer outside the
/// day's honest ranges is not believed.
func rtcReadTime() {
    var attempt = 0
    while attempt < 8 {
        attempt += 1
        var spin = 0
        while rtcRegister(0x0A) & 0x80 != 0 && spin < 100000 {
            spin += 1
        }
        let regB = rtcRegister(0x0B)
        let seconds1 = rtcRegister(0x00)
        let minutes1 = rtcRegister(0x02)
        let hours1 = rtcRegister(0x04)
        let seconds2 = rtcRegister(0x00)
        let minutes2 = rtcRegister(0x02)
        let hours2 = rtcRegister(0x04)
        if seconds1 != seconds2 || minutes1 != minutes2
            || hours1 != hours2 {
            continue
        }
        let binary = regB & 0x04 != 0
        let twelveHour = regB & 0x02 == 0
        let pm = hours1 & 0x80 != 0
        let hourByte = hours1 & 0x7F
        var hour = binary ? Int(hourByte) : rtcFromBcd(hourByte)
        let minute = binary ? Int(minutes1) : rtcFromBcd(minutes1)
        let second = binary ? Int(seconds1) : rtcFromBcd(seconds1)
        if twelveHour {
            if hour == 12 {
                hour = pm ? 12 : 0
            } else if pm {
                hour += 12
            }
        }
        if hour < 0 || hour > 23 || minute < 0 || minute > 59
            || second < 0 || second > 59 {
            rtcValid = false
            return
        }
        rtcHour = hour
        rtcMinute = minute
        rtcSecond = second
        rtcValid = true
        return
    }
    rtcValid = false
}

/// True when the bytes at the address are the RSDP's
/// signature, "RSD PTR ", and its first twenty bytes sum to
/// nothing modulo 256 — the table's own checksum.
func acpiRsdpFound(_ addr: UInt64) -> Bool {
    if mmioRead8(addr) != 0x52 || mmioRead8(addr + 1) != 0x53
        || mmioRead8(addr + 2) != 0x44
        || mmioRead8(addr + 3) != 0x20
        || mmioRead8(addr + 4) != 0x50
        || mmioRead8(addr + 5) != 0x54
        || mmioRead8(addr + 6) != 0x52
        || mmioRead8(addr + 7) != 0x20 {
        return false
    }
    var sum: UInt32 = 0
    var i: UInt64 = 0
    while i < 20 {
        sum &+= UInt32(mmioRead8(addr + i))
        i += 1
    }
    return sum & 0xFF == 0
}

/// Hunts the RSDP through a stretch of low memory, sixteen
/// bytes at a time — the stride the pointer keeps — and
/// returns its address, or 0 when the stretch holds none.
func acpiScanRsdp(_ from: UInt64, _ to: UInt64) -> UInt64 {
    var addr = from
    while addr + 20 <= to {
        if acpiRsdpFound(addr) { return addr }
        addr += 16
    }
    return 0
}

/// Takes the root tables' addresses from an RSDP standing at
/// the given address: the RSDT always, the XSDT when the
/// pointer is of the second revision.
func acpiTakeRsdp(_ addr: UInt64) {
    acpiRsdtAddr = UInt64(mmioRead32(addr + 16))
    acpiXsdtAddr = 0
    if mmioRead8(addr + 15) >= 2 {
        acpiXsdtAddr = UInt64(mmioRead32(addr + 24))
            | (UInt64(mmioRead32(addr + 28)) << 32)
    }
}

/// The root tables' addresses, from the RSDP however it was
/// come by: the bootloader's copy, or the pointer itself.
var acpiRsdtAddr: UInt64 = 0
var acpiXsdtAddr: UInt64 = 0

/// One AML integer at the address — the small constants a
/// package holds — spoken as a value and the count of bytes
/// it took: the opcodes for zero, one, and ones, and the
/// byte, word and double-word constant prefixes. Returns 0
/// when the byte there begins none of them.
func acpiParseInt(_ addr: UInt64, _ value: inout UInt64) -> Int {
    let op = mmioRead8(addr)
    switch op {
    case 0x00:
        value = 0
        return 1
    case 0x01:
        value = 1
        return 1
    case 0xFF:
        value = 0xFFFF_FFFF_FFFF_FFFF
        return 1
    case 0x0A:
        value = UInt64(mmioRead8(addr + 1))
        return 2
    case 0x0B:
        value = UInt64(mmioRead16(addr + 1))
        return 3
    case 0x0C:
        value = UInt64(mmioRead32(addr + 1))
        return 5
    default:
        return 0
    }
}

/// Reads one _S5_ package — its address is the package
/// opcode's — and keeps its two sleep values. The package
/// header is the AML length field (whose lead byte's top
/// two bits count any following length bytes) and the
/// element count; the values follow as small integers.
func acpiTakeS5Package(_ pkg: UInt64) -> Bool {
    let lead = mmioRead8(pkg + 1)
    let follow = Int(lead >> 6)
    let header = 2 + follow
    var pos = pkg + UInt64(header) + 1
    var a: UInt64 = 0
    var b: UInt64 = 0
    var used = acpiParseInt(pos, &a)
    if used == 0 { return false }
    pos += UInt64(used)
    used = acpiParseInt(pos, &b)
    if used == 0 { return false }
    powerSlpTypA = a & 0x07
    powerSlpTypB = b & 0x07
    return true
}

/// Hunts the _S5_ package through the DSDT: the values-only
/// definition the firmware writes for it, `Name (_S5_,
/// Package ...)` — the name followed at once by the package
/// opcode. The first such package wins; the table's length
/// is believed within a sane bound.
func acpiHuntS5(_ dsdt: UInt64) -> Bool {
    let length = UInt64(mmioRead32(dsdt + 4))
    if length < 40 || length > 0x10_0000 { return false }
    var pos = dsdt + 36
    let end = dsdt + length - 5
    while pos < end {
        if mmioRead8(pos) == 0x5F && mmioRead8(pos + 1) == 0x53
            && mmioRead8(pos + 2) == 0x35
            && mmioRead8(pos + 3) == 0x5F
            && mmioRead8(pos + 4) == 0x12 {
            if acpiTakeS5Package(pos + 4) { return true }
        }
        pos += 1
    }
    return false
}

/// Gathers the power tables once, while the boot floor's
/// identity map still stands (kmain calls it before the
/// memory machinery moves in): the RSDP from the
/// bootloader's tags when it left one — type 15 the newer
/// copy, type 14 the older — else hunted the old way, in the
/// EBDA's first page and the last stretch below a megabyte.
/// Then the root table is walked to the FACP, which names
/// the control ports, and the DSDT is read for _S5_. What is
/// not found is not invented: powerAcpiReady says plainly
/// whether the asking will be by the tables.
func initPower(_ infoAddress: UInt64) {
    var tag = findTagOffset(15, infoAddress: infoAddress)
    if tag < 0 {
        tag = findTagOffset(14, infoAddress: infoAddress)
    }
    if tag >= 0 {
        acpiTakeRsdp(infoAddress + UInt64(tag) + 8)
    }
    if acpiRsdtAddr == 0 && acpiXsdtAddr == 0 {
        let ebda = UInt64(mmioRead16(0x40E)) << 4
        var found: UInt64 = 0
        if ebda != 0 {
            found = acpiScanRsdp(ebda, ebda + 1024)
        }
        if found == 0 {
            found = acpiScanRsdp(0xE0000, 0x100000)
        }
        if found != 0 {
            acpiTakeRsdp(found)
        }
    }
    let root = acpiXsdtAddr != 0 ? acpiXsdtAddr : acpiRsdtAddr
    if root == 0 { return }
    let entrySize: UInt64 = acpiXsdtAddr != 0 ? 8 : 4
    let rootLength = UInt64(mmioRead32(root + 4))
    if rootLength < 36 { return }
    let count = (rootLength - 36) / entrySize
    var fadt: UInt64 = 0
    var i: UInt64 = 0
    while i < count {
        let at = root + 36 + i * entrySize
        let entry = entrySize == 8
            ? UInt64(mmioRead32(at))
                | (UInt64(mmioRead32(at + 4)) << 32)
            : UInt64(mmioRead32(at))
        if entry != 0
            && mmioRead8(entry) == 0x46
            && mmioRead8(entry + 1) == 0x41
            && mmioRead8(entry + 2) == 0x43
            && mmioRead8(entry + 3) == 0x50 {
            fadt = entry
            break
        }
        i += 1
    }
    if fadt == 0 { return }
    let pm1a = UInt64(mmioRead32(fadt + 64))
    let pm1b = UInt64(mmioRead32(fadt + 68))
    var dsdt = UInt64(mmioRead32(fadt + 40))
    if dsdt == 0 && mmioRead32(fadt + 4) >= 148 {
        dsdt = UInt64(mmioRead32(fadt + 140))
            | (UInt64(mmioRead32(fadt + 144)) << 32)
    }
    var s5 = false
    if dsdt != 0 {
        s5 = acpiHuntS5(dsdt)
    }
    if pm1a != 0 && s5 {
        powerPm1a = pm1a
        powerPm1b = pm1b
        powerAcpiReady = true
    }
}

/// The farewell screen: the desktop's deep ground, and one
/// plain line at its heart, spoken large. The machine is
/// told goodbye honestly — no spinner, no pretence of work
/// being done.
func powerFarewell(_ line: StaticString) {
    pointerHide()
    guiFillRect(0, 0, framebufferWidth, framebufferHeight,
                guiBarColor)
    let width = guiTextGlyphs(line) * 24
    guiDrawText((framebufferWidth - width) / 2,
                framebufferHeight / 2 - 12, 3, line,
                guiParchmentColor)
}

/// Shuts the machine down, and does not return. The tables'
/// way first: the S5 value written to the control port the
/// FADT named — the machine powers off in the asking. Then
/// the two ports older chipsets answered (0x604 on the ICH
/// line, 0xB004 on the PIIX line), each given a moment to
/// take. If nothing answers, the screen says the reader may
/// turn the computer off now — the truth, in plain words —
/// and the kernel rests.
func powerShutDown() -> Never {
    powerFarewell(guiShuttingDownLine)
    if powerAcpiReady {
        let wordA = UInt16(truncatingIfNeeded:
            (powerSlpTypA << 10) | 0x2000)
        cardnullOutw(UInt16(truncatingIfNeeded: powerPm1a),
                     wordA)
        if powerPm1b != 0 {
            let wordB = UInt16(truncatingIfNeeded:
                (powerSlpTypB << 10) | 0x2000)
            cardnullOutw(UInt16(truncatingIfNeeded: powerPm1b),
                         wordB)
        }
        waitTicks(100)
    }
    cardnullOutw(0x604, 0x2000)
    waitTicks(50)
    cardnullOutw(0xB004, 0x2000)
    waitTicks(50)
    powerFarewell(guiSafeOffLine)
    cardnullHalt()
}

/// Restarts the machine, and does not return. The farewell
/// first; then the keyboard controller's reset line — its
/// input buffer drained first, within a bound, so the
/// command is heard — and, should that fail, the reset
/// control register's two-step. If even those fail, the
/// kernel rests under the farewell it already spoke.
func powerRestart() -> Never {
    powerFarewell(guiRestartingLine)
    var drain = 0
    while cardnullInb(0x64) & 0x02 != 0 && drain < 200000 {
        drain += 1
    }
    cardnullOutb(0x64, 0xFE)
    waitTicks(50)
    cardnullOutb(0xCF9, 0x02)
    cardnullOutb(0xCF9, 0x06)
    waitTicks(50)
    cardnullHalt()
}

/// The Power card's close box: the shared box, at the shared
/// place in its title bar.
func guiPowerCloseContains(_ x: Int, _ y: Int) -> Bool {
    x >= guiCloseBoxX(guiPowerX, guiPowerW)
        && x < guiCloseBoxX(guiPowerX, guiPowerW) + guiBoxW
        && y >= guiPowerY + guiBoxTop
        && y < guiPowerY + guiBoxTop + guiBoxH
}

/// One of the Power card's buttons, by its place in the
/// asking: in the choosing, 0 Shut Down, 1 Restart, 2 Not
/// now; in the confirming, 0 the plain Yes, 1 No, go back.
/// The rects are the same numbers the painting reads, so the
/// hand and the eye cannot disagree.
func guiPowerButtonRect(_ index: Int) -> (Int, Int, Int, Int) {
    let w = min(320, guiPowerW - 96)
    let x = guiPowerX + (guiPowerW - w) / 2
    let y = powerConfirm == 0
        ? guiPowerY + 116 + index * 56
        : guiPowerY + 164 + index * 56
    return (x, y, w, 44)
}

/// The card's buttons' labels, by the asking and the place.
func guiPowerButtonLabel(_ index: Int) -> StaticString {
    if powerConfirm == 0 {
        if index == 0 { return guiShutDownLabel }
        if index == 1 { return guiRestartLabel }
        return guiNotNowLabel
    }
    if index == 0 {
        return powerConfirm == 1 ? guiYesShutDown : guiYesRestart
    }
    return guiNoGoBack
}

/// Paints one of the card's buttons: the shared button ground
/// and border, its plain words centred.
func guiPaintPowerButton(_ index: Int) {
    let rect = guiPowerButtonRect(index)
    guiFillRect(rect.0, rect.1, rect.2, rect.3, guiButtonColor)
    guiFillRect(rect.0, rect.1, rect.2, 2, guiBorderColor)
    guiFillRect(rect.0, rect.1 + rect.3 - 2, rect.2, 2,
                guiBorderColor)
    guiFillRect(rect.0, rect.1, 2, rect.3, guiBorderColor)
    guiFillRect(rect.0 + rect.2 - 2, rect.1, 2, rect.3,
                guiBorderColor)
    let label = guiPowerButtonLabel(index)
    let labelW = guiTextGlyphs(label) * 16
    guiDrawText(rect.0 + (rect.2 - labelW) / 2, rect.1 + 14, 2,
                label, guiInkColor)
}

/// Paints the Power card whole: its shadow, its parchment and
/// border, its title bar in the held colour — the card holds
/// the room from the moment it stands — with its name and
/// close box, and below, its question and its buttons. The
/// choosing asks what the reader would like to do; the
/// confirming asks "Are you sure?" and says plainly what
/// will happen, so the Yes that acts is a knowing one.
func guiPaintPowerCard() {
    guiFillRect(guiPowerX + 10, guiPowerY + 12, guiPowerW,
                guiPowerH, guiShadowColor)
    guiFillRect(guiPowerX, guiPowerY, guiPowerW, guiPowerH,
                guiParchmentColor)
    guiFillRect(guiPowerX, guiPowerY, guiPowerW, 2,
                guiBorderColor)
    guiFillRect(guiPowerX, guiPowerY + guiPowerH - 2, guiPowerW,
                2, guiBorderColor)
    guiFillRect(guiPowerX, guiPowerY, 2, guiPowerH,
                guiBorderColor)
    guiFillRect(guiPowerX + guiPowerW - 2, guiPowerY, 2,
                guiPowerH, guiBorderColor)
    guiFillRect(guiPowerX, guiPowerY, guiPowerW, 36,
                guiCardinalColor)
    guiDrawText(guiPowerX + 16, guiPowerY + 10, 2, guiPowerLabel,
                guiWhiteColor)
    guiPaintXBox(guiCloseBoxX(guiPowerX, guiPowerW),
                 guiPowerY + guiBoxTop)
    if powerConfirm == 0 {
        let q = guiPowerQuestion
        guiDrawText(guiPowerX + (guiPowerW
                        - guiTextGlyphs(q) * 16) / 2,
                    guiPowerY + 64, 2, q, guiInkColor)
        guiPaintPowerButton(0)
        guiPaintPowerButton(1)
        guiPaintPowerButton(2)
    } else {
        let q = guiAreYouSure
        guiDrawText(guiPowerX + (guiPowerW
                        - guiTextGlyphs(q) * 16) / 2,
                    guiPowerY + 60, 2, q, guiInkColor)
        let why = powerConfirm == 1
            ? guiWillShutDown : guiWillRestart
        guiDrawText(guiPowerX + (guiPowerW
                        - guiTextGlyphs(why) * 16) / 2,
                    guiPowerY + 96, 2, why, guiInkColor)
        guiPaintPowerButton(0)
        guiPaintPowerButton(1)
    }
}

/// Opens the Power card: the choosing question, fresh, and
/// the room yielded by every window — the card holds it
/// alone until it is answered or set aside. The desktop is
/// painted whole, the card over all.
func guiOpenPower() {
    powerOpen = true
    powerConfirm = 0
    guiFocusTerminal = false
    guiFocusFiles = false
    guiFocusReader = false
    guiFocusWrite = false
    guiFocusBible = false
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Sets the Power card aside unacted: the room returns to
/// the Terminal when it stands, as the elders' own closings
/// have always given it, and the desktop is painted whole.
func guiClosePower() {
    powerOpen = false
    powerConfirm = 0
    if termOpen {
        guiFocusTerminal = true
    }
    pointerHide()
    guiPaintDesktop()
    pointerShow()
}

/// Answers a press while the Power card stands. Every press
/// is the card's affair: the close box sets it aside, a
/// button advances or settles the asking, and a press
/// anywhere else does nothing at all — the machine is never
/// shut down or restarted by anything but the card's own
/// plain Yes, pressed in the confirming.
func guiPressPower(_ x: Int, _ y: Int) -> Bool {
    if guiPowerCloseContains(x, y) {
        guiClosePower()
        return true
    }
    let count = powerConfirm == 0 ? 3 : 2
    var index = 0
    while index < count {
        let rect = guiPowerButtonRect(index)
        if x >= rect.0 && x < rect.0 + rect.2
            && y >= rect.1 && y < rect.1 + rect.3 {
            guiPowerButtonPressed(index)
            return true
        }
        index += 1
    }
    return true
}

/// One of the card's buttons, pressed. In the choosing: Shut
/// Down and Restart step to their confirming — the machine
/// does NOT move yet — and Not now sets the card aside. In
/// the confirming: the plain Yes acts (and does not return),
/// and No, go back returns to the choosing.
func guiPowerButtonPressed(_ index: Int) {
    if powerConfirm == 0 {
        if index == 2 {
            guiClosePower()
            return
        }
        powerConfirm = index == 0 ? 1 : 2
        pointerHide()
        guiPaintPowerCard()
        pointerShow()
        return
    }
    if index == 1 {
        powerConfirm = 0
        pointerHide()
        guiPaintPowerCard()
        pointerShow()
        return
    }
    if powerConfirm == 1 {
        powerShutDown()
    }
    powerRestart()
}

/// Kernel entry point. Called once by the boot floor; never returns —
/// an operating system that finishes has stopped being one.
///
