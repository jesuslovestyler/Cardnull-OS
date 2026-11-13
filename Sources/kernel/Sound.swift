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
