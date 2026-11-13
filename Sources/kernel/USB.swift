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
// Milestone 32: seeing a USB stick.
//
// The machine gains a fourth road for bytes to travel: the
// USB bus. Until now every drive the kernel has known stood
// inside the machine — the CD it boots from and the hard disk
// it keeps its files on, both spoken to through the AHCI
// controller. A USB stick is a drive a person carries in a
// pocket and plugs in with a hand, and this stone teaches
// the kernel to see one: to find the bus's host controller,
// to wake the stick standing on it, to learn its name and
// its measure, and to read its sectors — so that a stick
// carrying Cardnull's own disk format can have its files
// listed and read, word for word, through the same judging
// the hard disk is judged by.
//
//   - The controller is a UHCI — the Universal Host
//     Controller Interface, the first and plainest of the
//     USB host designs, and the one the chipset in these
//     machines (QEMU's q35 ICH9, and UTM's PC beside it)
//     presents when its USB is switched on. It is found the
//     way every device in this kernel is found: walking the
//     PCI bus and asking each function its class — serial
//     bus (0x0C), USB (0x03), UHCI (0x00) — and its door is
//     not memory but I/O ports: the fourth base register
//     names a small row of port addresses, spoken a word at
//     a time through the floor's word-wide hands, an
//     arrangement no other driver here uses. A machine
//     whose USB wears another design (EHCI, xHCI) is not
//     guessed at: the report says plainly that no controller
//     of the kind Cardnull speaks was found.
//   - The road itself is a schedule the controller walks
//     once a millisecond: a frame list of a thousand
//     entries, every one naming the driver's one queue
//     head, and under the queue head a short chain of
//     transfer descriptors — one for each stage of the
//     conversation — that the controller works through and
//     marks done, or marks with the error it met. The
//     kernel polls the last descriptor's standing with a
//     deadline, the way it polls everything: a silent
//     device costs the deadline, never the shell. Three
//     frames are the whole estate — the frame list, the
//     queue and its descriptors, and one data field —
//     taken once from the allocator at the first asking
//     and kept, their addresses physical as well as
//     virtual, the identity map's gift, which is what a
//     DMA engine must be told.
//   - A stick is woken the way the standard prescribes,
//     in words the code keeps close: its port is reset,
//     it is asked its own description at the address every
//     device is born with, it is given an address of its
//     own (1), it is asked its arrangement, and it is set
//     to that arrangement. The arrangement is read, not
//     assumed: the walk through its descriptors looks for
//     an interface that declares itself mass storage
//     (class 8) speaking the SCSI tongue (subclass 6) by
//     the bulk-only road (protocol 0x50), and takes the
//     two bulk doors that interface declares. A device
//     that answers but declares another kind — a keyboard,
//     say — is reported as exactly that: present, and not
//     a stick Cardnull can read. Nothing is faked from a
//     vendor's name or a guess.
//   - Storage is spoken in SCSI, carried in bulk-only
//     envelopes: a command wrapper, the data itself, and
//     a status wrapper that must sign its name and echo
//     the command's mark before its verdict is believed.
//     The kernel asks the stick its name (INQUIRY), asks
//     whether it is ready (TEST UNIT READY, with the
//     sense asked after when the answer is a refusal, the
//     way the standard expects), and asks its measure
//     (READ CAPACITY) — the last sector and the sector's
//     size, both the device's own numbers. Sectors are
//     then read one at a time (READ(10)) into the data
//     field. This stone reads only: no code path in this
//     section can write to a stick, and none pretends to.
//   - The filesystem is the hard disk's own — CARDNULL
//     DISK 1, defined in docs/DISK.md — judged on the
//     stick exactly as it is judged on the disk: sector 0
//     read fresh, the mark proven by its checksum and
//     geometry, a prepared stick's home found behind its
//     partition entry just as a prepared disk's is. The
//     judging code is spoken a second time over the USB
//     sector road rather than bent around a shared one,
//     the house's habit — the disc and the hard disk share
//     a controller and nothing else, and the stick shares
//     less. A stick whose format is not Cardnull's is
//     reported in plain words — seen, measured, and not
//     one Cardnull reads yet — and its bytes are never
//     interpreted.
//
// The commands are three: `usb` reports what is plugged
// in — the stick's own name for itself, its measure, and
// what stands on it — or says plainly that no stick is
// there; `uls` lists a Cardnull stick's files; `ucat`
// reads one back. Every command looks afresh: the port is
// read, the stick is woken and asked again, because a
// stick is a thing a hand can pull out between one
// command and the next, and a report remembered from an
// earlier asking could name a stick that is no longer
// there. The Files window keeps its disc face this stone;
// the stick's face there rides a later one, and nothing
// here dresses the Terminal's account up as one.
// ---------------------------------------------------------------------------

/// The controller's registers, as offsets from the I/O base
/// its fourth base register names: the command word, the
/// status word, the interrupt word (never armed — this
/// driver polls), the frame number, the frame list's base
/// address, the start-of-frame timing, and the two ports.
let usbRegCommand: UInt16 = 0x00
let usbRegStatus: UInt16 = 0x02
let usbRegInterrupt: UInt16 = 0x04
let usbRegFrameNumber: UInt16 = 0x06
let usbRegFrameBase: UInt16 = 0x08
let usbRegPort1: UInt16 = 0x10
let usbRegPort2: UInt16 = 0x12

/// The command word's bits this driver uses: run, host
/// reset, global reset, the configure flag (the schedule
/// the driver built is the machine's arrangement), and the
/// 64-byte packet bound a full-speed bus speaks.
let usbCmdRun: UInt16 = 0x0001
let usbCmdHostReset: UInt16 = 0x0002
let usbCmdGlobalReset: UInt16 = 0x0004
let usbCmdConfigure: UInt16 = 0x0040
let usbCmdMaxPacket: UInt16 = 0x0100

/// A port word's bits: a device stands here, the port is
/// enabled (the reset's success), the device is a
/// low-speed one, and the reset bit itself.
let usbPortConnected: UInt16 = 0x0001
let usbPortEnabled: UInt16 = 0x0004
let usbPortLowSpeed: UInt16 = 0x0100
let usbPortReset: UInt16 = 0x0200

/// The packets' names, as the USB standard numbers them:
/// the setup that opens every control conversation, and
/// the two directions of every road.
let usbPidSetup: UInt32 = 0x2D
let usbPidIn: UInt32 = 0x69
let usbPidOut: UInt32 = 0xE1

/// A transfer descriptor's standing, in its second word:
/// the descriptor is still working, the errors it can meet
/// gathered in one mask, and the fresh standing a new
/// descriptor is given — working, three errors allowed
/// before the host gives up, a short packet allowed to end
/// an inward road cleanly.
let usbTdActive: UInt32 = 0x00800000
let usbTdErrors: UInt32 = 0x00760000
let usbTdFresh: UInt32 = 0x00800000 | 0x18000000
let usbTdShortOk: UInt32 = 0x20000000
let usbTdSlow: UInt32 = 0x04000000

/// The descriptor pool's shape: the queue head stands at
/// the structure frame's head, and eight descriptors
/// follow it, each thirty-two bytes — the longest chain
/// this driver builds is three (setup, data, status), and
/// the rest is room.
let usbTdBase = 64
let usbTdStride = 32
let usbTdCount = 8

/// The data field's rooms: the stage every transfer moves
/// through at its head (a sector, a description, an
/// answer), and the bulk-only road's three scratches — the
/// command wrapper, the status wrapper, and the control
/// road's setup packet — each in its own ground so no
/// stage can trample another.
let usbStageBytes = 2048
let usbCbwOffset = 2048
let usbCswOffset = 2176
let usbSetupOffset = 3072

/// The one address this driver gives: a stick is woken at
/// the address every device is born with (0) and given 1,
/// there being one conversation at a time on this bus.
let usbDeviceAddress: UInt32 = 1

/// Did a UHCI controller answer, and where its door is.
/// The walk is made once and kept: a controller does not
/// arrive mid-sitting any more than a disk does.
var usbControllerFound = false
var usbIoBase: UInt16 = 0

/// Did the schedule's raising already run? The controller
/// is reset and set walking once, at the first asking,
/// and kept walking for the session; what is looked at
/// afresh each time is the port and the device on it.
var usbRaised = false

/// The driver's fields, taken from the allocator once: the
/// frame list, the structures (the queue head and its
/// descriptors), and the data field. Their addresses are
/// physical as well as virtual — the controller is a DMA
/// engine and must be told the physical ones.
var usbListFrame: UInt64 = 0
var usbStructFrame: UInt64 = 0
var usbDataFrame: UInt64 = 0

/// The last look's findings, refreshed by every command:
/// the port the stick stands on, whether it is a
/// low-speed device, the address it was given, its bulk
/// doors and their packet bounds, and its measure as READ
/// CAPACITY reported it — a count of sectors and the
/// sector's size, both the device's own numbers.
var usbPort = 0
var usbLowSpeed = false
var usbInEp: UInt32 = 0
var usbOutEp: UInt32 = 0
var usbInMax = 64
var usbOutMax = 64
var usbSectors: UInt64 = 0
var usbBlockSize: UInt32 = 512

/// The bulk doors' data toggles, kept between the stages
/// of a conversation and reset with each waking: the
/// bulk-only road numbers its packets in turn, and a
/// stage that loses count loses the conversation.
var usbToggleIn: UInt32 = 0
var usbToggleOut: UInt32 = 0

/// The command wrapper's mark, fresh with every command:
/// the status wrapper must echo it before its verdict is
/// believed, so a late answer to an earlier asking can
/// never be mistaken for this one's.
var usbBotTag: UInt32 = 0

/// The stick's own name for itself, from its INQUIRY
/// answer — the maker's word and the device's word, up to
/// twenty-four letters in a heap scratch, with its
/// reckoned length beside it, the disc model's own
/// arrangement kept a third time.
var usbNameAddress: UInt64 = 0
var usbNameLength = 0

/// The data field, as the pointer every USB hand shares.
@inline(__always)
func usbData() -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>(bitPattern: UInt(usbDataFrame))!
}

/// The queue head's words: the head link at the frame's
/// first word (nothing follows it — this schedule has one
/// queue), and the element link after it, which names the
/// chain being worked, or stands terminated when the
/// queue is at rest.
@inline(__always)
func usbQueue() -> UnsafeMutablePointer<UInt32> {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(usbStructFrame))!
}

/// One descriptor's words, by its place in the pool.
@inline(__always)
func usbTd(_ index: Int) -> UnsafeMutablePointer<UInt32> {
    UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(usbStructFrame + UInt64(usbTdBase
            + index * usbTdStride)))!
}

/// A descriptor's physical address, as the controller must
/// be told it — the same number as its pointer, the
/// identity map's gift.
func usbTdAddress(_ index: Int) -> UInt32 {
    UInt32(usbStructFrame) + UInt32(usbTdBase + index * usbTdStride)
}

/// The controller's words, read and written a word at a
/// time through its I/O door (the frame list's base, a
/// full address, travels the double-word road).
func usbReadReg(_ offset: UInt16) -> UInt16 {
    cardnullInw(usbIoBase + offset)
}

func usbWriteReg(_ offset: UInt16, _ value: UInt16) {
    cardnullOutw(usbIoBase + offset, value)
}

/// Finds the controller: walks the bus as every raising in
/// this kernel walks it — every function of every device
/// on bus 0 — asking for the USB class, the UHCI kind, and
/// an I/O door that stands. The first that answers is
/// taken: its I/O door and its bus mastery are switched on
/// in its command word, and the old firmware's legacy hold
/// on the bus is released, so no unseen hand traps the
/// ports out from under the driver.
func usbFindController() -> Bool {
    if usbControllerFound { return true }
    var device: UInt32 = 0
    while device < 32 {
        var function: UInt32 = 0
        while function < 8 {
            let id = pciConfigRead32(device, function, 0)
            if id & 0xFFFF != 0xFFFF {
                let classes = pciConfigRead32(device, function, 0x08)
                if classes >> 24 == 0x0C
                    && (classes >> 16) & 0xFF == 0x03
                    && (classes >> 8) & 0xFF == 0x00 {
                    let bar = pciConfigRead32(device, function, 0x20)
                    if bar & 1 == 1 && bar & 0xFFFFFFFC != 0 {
                        usbIoBase = UInt16(bar & 0xFFFFFFFC)
                        let commandWord = pciConfigRead32(
                            device, function, 0x04)
                        pciConfigWrite32(device, function, 0x04,
                                         commandWord | 0x05)
                        let legacy = pciConfigRead32(
                            device, function, 0xC0)
                        pciConfigWrite32(device, function, 0xC0,
                                         (legacy & 0xFFFF0000)
                                            | 0x00008F00)
                        usbControllerFound = true
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

/// Takes the driver's fields from the allocator, once, and
/// proves each one fit for the controller's hands: a DMA
/// engine of this era names 32 bits of address, so every
/// frame the controller will ever be told must stand below
/// 4 GiB — the allocator's own estate ends at that very
/// line, so the proof should never fail, and it is made
/// anyway, address by address, for the network card's own
/// stated reason: a controller told an address it cannot
/// reach does not complain — it writes somewhere else.
func usbTakeFrames() -> Bool {
    if usbListFrame != 0 { return true }
    usbListFrame = allocFrame()
    usbStructFrame = allocFrame()
    usbDataFrame = allocFrame()
    if usbListFrame == 0 || usbStructFrame == 0
        || usbDataFrame == 0 {
        return false
    }
    let reach: UInt64 = 0x1_0000_0000
    if usbListFrame >= reach || usbStructFrame >= reach
        || usbDataFrame >= reach {
        return false
    }
    if usbNameAddress == 0 {
        usbNameAddress = heapAlloc(32)
        if usbNameAddress == 0 { return false }
    }
    return true
}

/// Raises the controller, once: the schedule is built —
/// the frame list wiped and every entry pointed at the one
/// queue head, the queue head at rest — and the controller
/// is reset by both its resets, told its schedule's
/// address, and set walking with the configure flag
/// standing: the arrangement it walks is the driver's own.
/// Its interrupts are never armed; the driver polls, so
/// there is no new voice in the interrupt chorus to feed.
func usbRaiseController() -> Bool {
    if usbRaised { return true }
    if !usbTakeFrames() { return false }
    let list = UnsafeMutablePointer<UInt32>(
        bitPattern: UInt(usbListFrame))!
    let queue = usbQueue()
    var index = 0
    while index < 1024 {
        list[index] = UInt32(usbStructFrame) | 2
        index += 1
    }
    queue[0] = 1
    queue[1] = 1
    queue[2] = 0
    queue[3] = 0
    usbWriteReg(usbRegCommand, 0)
    usbWriteReg(usbRegCommand, usbCmdGlobalReset)
    waitTicks(2)
    usbWriteReg(usbRegCommand, 0)
    usbWriteReg(usbRegCommand, usbCmdHostReset)
    var waited: UInt64 = 0
    while usbReadReg(usbRegCommand) & usbCmdHostReset != 0 {
        if waited > 100 { return false }
        waitTicks(1)
        waited += 1
    }
    usbWriteReg(usbRegInterrupt, 0)
    usbWriteReg(usbRegStatus, 0x003F)
    usbWriteReg(usbRegFrameNumber, 0)
    cardnullOutl(usbIoBase + usbRegFrameBase, UInt32(usbListFrame))
    usbWriteReg(usbRegCommand,
                usbCmdRun | usbCmdConfigure | usbCmdMaxPacket)
    usbRaised = true
    return true
}

/// Lays one descriptor in the pool: its link (the next
/// descriptor depth-first, or the terminating word), its
/// fresh standing (with the slow mark when the device is a
/// low-speed one, and the short-packet pardon when the
/// road runs inward), the token naming the packet, the
/// address, the door, the toggle, and the length — the
/// length reckoned as the standard reckons it, one less
/// than the count, with the empty packet spelled in all
/// ones — and the buffer it moves bytes through.
func usbLayTd(_ index: Int, _ next: Int, _ pid: UInt32,
              _ address: UInt32, _ endpoint: UInt32,
              _ toggle: UInt32, _ length: Int, _ inward: Bool,
              _ bufferAddress: UInt32) {
    let td = usbTd(index)
    if next < 0 {
        td[0] = 1
    } else {
        // The link pointer's own grammar: bit 0 ends the
        // chain, bit 1 would name a queue head (the frame
        // list's entries carry it, pointing at this queue),
        // and bit 2 — set here — walks depth-first to the
        // next descriptor, which is what a chain is.
        td[0] = usbTdAddress(next) | 4
    }
    var status = usbTdFresh
    if usbLowSpeed { status |= usbTdSlow }
    if inward { status |= usbTdShortOk }
    td[1] = status
    let lengthField: UInt32 = length == 0
        ? 0x7FF : UInt32(length - 1)
    td[2] = pid | (address << 8) | (endpoint << 15)
        | (toggle << 19) | (lengthField << 21)
    td[3] = bufferAddress
}

/// Runs the chain standing in the first `count`
/// descriptors: the queue's element is pointed at the
/// first, and the driver rests — heartbeat by heartbeat,
/// never spinning — until every descriptor stands done,
/// or one names the error it met, or the deadline passes
/// (three seconds, a silent device's whole cost). The
/// queue is stilled on every road out. Truth comes home:
/// whether the chain completed whole.
func usbRunChain(_ count: Int) -> Bool {
    let queue = usbQueue()
    queue[1] = usbTdAddress(0)
    let deadline = ticks &+ 300
    var done = false
    var failed = false
    while !done && !failed {
        done = true
        var index = 0
        while index < count {
            let status = usbTd(index)[1]
            if status & usbTdErrors != 0 {
                failed = true
                break
            }
            if status & usbTdActive != 0 { done = false }
            index += 1
        }
        if !done && !failed {
            if ticks >= deadline {
                failed = true
            } else {
                cardnullHltOnce()
            }
        }
    }
    queue[1] = 1
    return !failed
}

/// A descriptor's true count: the bytes it actually moved,
/// read back out of its standing — the count less one, as
/// the standard spells it, with the all-ones spelling
/// meaning the empty packet.
func usbTdActual(_ index: Int) -> Int {
    let field = usbTd(index)[1] & 0x7FF
    if field == 0x7FF { return 0 }
    return Int(field) + 1
}

/// Stages a control conversation's opening packet in its
/// own ground: the eight bytes every setup carries — the
/// asking's kind and direction, the request's number, and
/// the three words of value, index, and length.
func usbStageSetup(_ requestType: UInt8, _ request: UInt8,
                   _ value: UInt16, _ index: UInt16,
                   _ length: UInt16) {
    let setup = usbData().advanced(by: usbSetupOffset)
    setup[0] = requestType
    setup[1] = request
    setup[2] = UInt8(value & 0xFF)
    setup[3] = UInt8(value >> 8)
    setup[4] = UInt8(index & 0xFF)
    setup[5] = UInt8(index >> 8)
    setup[6] = UInt8(length & 0xFF)
    setup[7] = UInt8(length >> 8)
}

/// One control conversation, whole: the setup, the data
/// stage when there is one (a single descriptor — every
/// asking this driver makes fits in the stage field), and
/// the status stage that closes it, its direction the
/// opposite of the data's and its packet empty. The data
/// toggle opens at the standing the standard prescribes
/// for each stage and the controller keeps the count
/// within the stage. Comes home with the data stage's
/// true count, or -1 when the chain did not complete.
func usbControl(_ address: UInt32, _ hasData: Bool,
                _ inward: Bool, _ dataLength: Int) -> Int {
    usbLayTd(0, 1, usbPidSetup, address, 0, 0,
             8, false, UInt32(usbDataFrame) + UInt32(usbSetupOffset))
    var count = 2
    if hasData {
        usbLayTd(1, 2, inward ? usbPidIn : usbPidOut, address, 0, 1,
                 dataLength, inward, UInt32(usbDataFrame))
        usbLayTd(2, -1, inward ? usbPidOut : usbPidIn, address, 0, 1,
                 0, !inward, UInt32(usbDataFrame))
        count = 3
    } else {
        usbLayTd(1, -1, usbPidIn, address, 0, 1, 0, true,
                 UInt32(usbDataFrame))
    }
    if !usbRunChain(count) { return -1 }
    if hasData { return usbTdActual(1) }
    return 0
}

/// Asks for a description — the device's own account of
/// itself or of its arrangement — at an address: the
/// standard asking (the host-to-device door's number 6),
/// with the kind in the value's high byte. The bytes land
/// at the stage's head; the true count comes home.
func usbGetDescriptor(_ address: UInt32, _ kind: UInt8,
                      _ length: Int) -> Int {
    usbStageSetup(0x80, 6, UInt16(kind) << 8, 0, UInt16(length))
    return usbControl(address, true, true, length)
}

/// One bulk stage, whole: a single descriptor carrying up
/// to the stage's whole length — the controller walks the
/// packets within it, advancing the toggle as it goes, and
/// the driver advances its own count by the packets the
/// true count implies, so the next stage opens where this
/// one closed. Comes home with the true count, or -1.
func usbBulk(_ endpoint: UInt32, _ inward: Bool,
             _ bufferOffset: Int, _ length: Int) -> Int {
    let toggle = inward ? usbToggleIn : usbToggleOut
    usbLayTd(0, -1, inward ? usbPidIn : usbPidOut,
             usbDeviceAddress, endpoint, toggle, length, inward,
             UInt32(usbDataFrame) + UInt32(bufferOffset))
    if !usbRunChain(1) { return -1 }
    let actual = usbTdActual(0)
    let maxPacket = inward ? usbInMax : usbOutMax
    var packets = 0
    if actual > 0 && maxPacket > 0 {
        packets = (actual + maxPacket - 1) / maxPacket
    }
    if packets % 2 == 1 {
        if inward {
            usbToggleIn ^= 1
        } else {
            usbToggleOut ^= 1
        }
    }
    return actual
}

/// One bulk-only conversation: the command wrapper laid
/// with its signature and a fresh mark, the command's own
/// bytes behind it; the data stage when the command
/// carries one; and the status wrapper, whose signature
/// and echoed mark are proven before its verdict is read.
/// Comes home with the data's true count — or -1 when the
/// road itself failed, or -2 when the device answered
/// with a refusal its sense must explain.
func usbBot(_ cdbLength: Int, _ dataLength: Int) -> Int {
    let data = usbData()
    let cbw = usbCbwOffset
    usbBotTag &+= 1
    if usbBotTag == 0 { usbBotTag = 1 }
    data[cbw + 0] = 0x55
    data[cbw + 1] = 0x53
    data[cbw + 2] = 0x42
    data[cbw + 3] = 0x43
    data[cbw + 4] = UInt8(usbBotTag & 0xFF)
    data[cbw + 5] = UInt8((usbBotTag >> 8) & 0xFF)
    data[cbw + 6] = UInt8((usbBotTag >> 16) & 0xFF)
    data[cbw + 7] = UInt8((usbBotTag >> 24) & 0xFF)
    data[cbw + 8] = UInt8(dataLength & 0xFF)
    data[cbw + 9] = UInt8((dataLength >> 8) & 0xFF)
    data[cbw + 10] = UInt8((dataLength >> 16) & 0xFF)
    data[cbw + 11] = UInt8((dataLength >> 24) & 0xFF)
    data[cbw + 12] = dataLength > 0 ? 0x80 : 0x00
    data[cbw + 13] = 0
    data[cbw + 14] = UInt8(cdbLength)
    if usbBulk(usbOutEp, false, usbCbwOffset, 31) != 31 {
        return -1
    }
    var actual = 0
    if dataLength > 0 {
        actual = usbBulk(usbInEp, true, 0, dataLength)
        if actual < 0 { return -1 }
    }
    if usbBulk(usbInEp, true, usbCswOffset, 13) != 13 {
        return -1
    }
    let csw = usbCswOffset
    if data[csw + 0] != 0x55 || data[csw + 1] != 0x53
        || data[csw + 2] != 0x42 || data[csw + 3] != 0x53 {
        return -1
    }
    let echoed = UInt32(data[csw + 4])
        | UInt32(data[csw + 5]) << 8
        | UInt32(data[csw + 6]) << 16
        | UInt32(data[csw + 7]) << 24
    if echoed != usbBotTag { return -1 }
    if data[csw + 12] != 0 { return -2 }
    return actual
}

/// Clears a SCSI command's ground in the wrapper's tail,
/// so no earlier asking's bytes ride along uninvited, and
/// the setters that follow lay the command's own bytes one
/// at a time — the house has no heap for a readier shape.
func usbClearCdb() {
    let data = usbData()
    var index = 0
    while index < 16 {
        data[usbCbwOffset + 15 + index] = 0
        index += 1
    }
}

func usbSetCdb(_ index: Int, _ byte: UInt8) {
    usbData()[usbCbwOffset + 15 + index] = byte
}

/// Asks the stick its name: INQUIRY, the first SCSI
/// asking — thirty-six bytes whose middle carries the
/// maker's word and the device's word, kept trimmed of
/// their padding in the name scratch. A refusal here is
/// not fatal to the waking: the measure matters more
/// than the name, and the report has an honest standing
/// word for a stick that will not give one.
func usbScsiInquire() {
    usbNameLength = 0
    usbClearCdb()
    usbSetCdb(0, 0x12)
    usbSetCdb(4, 36)
    if usbBot(6, 36) < 36 { return }
    let data = usbData()
    if usbNameAddress == 0 { return }
    let name = UnsafeMutablePointer<UInt8>(
        bitPattern: UInt(usbNameAddress))!
    var length = 0
    var field = 0
    while field < 2 {
        let start = field == 0 ? 8 : 16
        let span = field == 0 ? 8 : 16
        var index = 0
        var fieldLength = 0
        while index < span {
            let byte = data[start + index]
            if byte >= 0x20 && byte != 0x7F {
                name[length + index] = byte
                if byte != 0x20 { fieldLength = index + 1 }
            }
            index += 1
        }
        length += fieldLength
        if field == 0 && fieldLength > 0 && length < 30 {
            name[length] = 0x20
            length += 1
        }
        field += 1
    }
    usbNameLength = length
}

/// Asks whether the stick is ready, with the standard's
/// own patience: TEST UNIT READY, and when the answer is
/// a refusal, the sense is asked after (REQUEST SENSE,
/// which also clears the refusal's standing) and the
/// asking is made again — three askings in all, with a
/// breath between them, because a stick's motor and a
/// stick's pride both take a moment after a reset.
func usbScsiReady() -> Bool {
    var attempt = 0
    while attempt < 3 {
        usbClearCdb()
        let verdict = usbBot(6, 0)
        if verdict >= 0 { return true }
        if verdict == -1 { return false }
        usbClearCdb()
        usbSetCdb(0, 0x03)
        usbSetCdb(4, 18)
        _ = usbBot(6, 18)
        attempt += 1
        if attempt < 3 { waitTicks(5) }
    }
    return false
}

/// Asks the stick its measure: READ CAPACITY — the last
/// sector's number and the sector's size, both big-endian
/// as SCSI speaks them, both the device's own. The count
/// is the last sector's number and one more.
func usbScsiCapacity() -> Bool {
    usbClearCdb()
    usbSetCdb(0, 0x25)
    if usbBot(10, 8) < 8 { return false }
    let data = usbData()
    let last = UInt64(data[0]) << 24 | UInt64(data[1]) << 16
        | UInt64(data[2]) << 8 | UInt64(data[3])
    let size = UInt32(data[4]) << 24 | UInt32(data[5]) << 16
        | UInt32(data[6]) << 8 | UInt32(data[7])
    if size == 0 { return false }
    usbSectors = last + 1
    usbBlockSize = size
    return true
}

/// Reads one sector off the stick into the stage: READ(10)
/// for exactly one sector, its number big-endian in the
/// command, the stage's head its landing. The road the
/// filesystem's judging below travels.
func usbReadSector(_ lba: UInt64) -> Bool {
    if lba > 0xFFFFFFFF { return false }
    usbClearCdb()
    usbSetCdb(0, 0x28)
    usbSetCdb(2, UInt8((lba >> 24) & 0xFF))
    usbSetCdb(3, UInt8((lba >> 16) & 0xFF))
    usbSetCdb(4, UInt8((lba >> 8) & 0xFF))
    usbSetCdb(5, UInt8(lba & 0xFF))
    usbSetCdb(8, 1)
    return usbBot(10, 512) == 512
}

/// A port's reset, and the settling after: the reset bit
/// held for five hundredths of a second — the standard's
/// measure for a root port — then let go, a hundredth's
/// recovery, the port's enable raised by the driver's own
/// hand (the standard makes the bit read/write, and on
/// the bench's controller the port does not raise it
/// itself after a reset — the waking writes it standing,
/// as many a driver for this controller does), one more
/// hundredth for the port to settle, and the port's own
/// verdict read in its enabled bit. A device that does
/// not stand enabled after its reset did not answer its
/// waking.
func usbResetPort(_ port: Int) -> Bool {
    let reg = port == 0 ? usbRegPort1 : usbRegPort2
    let standing = usbReadReg(reg)
    usbWriteReg(reg, standing | usbPortReset)
    waitTicks(5)
    usbWriteReg(reg, usbReadReg(reg) & ~usbPortReset)
    waitTicks(1)
    usbWriteReg(reg, usbReadReg(reg) | usbPortEnabled)
    waitTicks(1)
    let after = usbReadReg(reg)
    usbLowSpeed = after & usbPortLowSpeed != 0
    return after & usbPortConnected != 0
        && after & usbPortEnabled != 0
}

/// Wakes the device standing on the chosen port and
/// arranges it: its description's head at the address it
/// was born with, an address of its own, its whole
/// description, and its arrangement read descriptor by
/// descriptor — the mass-storage interface found by its
/// declared numbers, its two bulk doors taken with their
/// packet bounds — and the arrangement set. Comes home
/// with the look's verdict: storage (its doors in hand),
/// notStorage (it answered, and declared another kind),
/// or failed (it did not answer its waking).
func usbWakeDevice() -> Int {
    if usbGetDescriptor(0, 1, 8) < 8 { return 2 }
    usbStageSetup(0x00, 5, UInt16(usbDeviceAddress), 0, 0)
    if usbControl(0, false, true, 0) < 0 { return 2 }
    waitTicks(1)
    let address = usbDeviceAddress
    if usbGetDescriptor(address, 1, 18) < 18 { return 2 }
    if usbGetDescriptor(address, 2, 9) < 9 { return 2 }
    let data = usbData()
    let total = Int(data[2]) | Int(data[3]) << 8
    if total < 9 || total > usbStageBytes { return 2 }
    if usbGetDescriptor(address, 2, total) < total { return 2 }
    let configValue = data[5]
    var offset = 0
    var inInterface = false
    var storage = false
    usbInEp = 0
    usbOutEp = 0
    while offset + 2 <= total {
        let length = Int(data[offset])
        let kind = data[offset + 1]
        if length < 2 { break }
        if kind == 4 && length >= 9 {
            inInterface = data[offset + 5] == 8
                && data[offset + 6] == 6
                && data[offset + 7] == 0x50
            if inInterface { storage = true }
        } else if kind == 5 && length >= 7 && inInterface {
            let door = data[offset + 2]
            let manner = data[offset + 3] & 3
            let packet = Int(data[offset + 4])
                | Int(data[offset + 5]) << 8
            if manner == 2 && packet > 0 {
                if door & 0x80 != 0 {
                    usbInEp = UInt32(door & 0x0F)
                    usbInMax = packet
                } else {
                    usbOutEp = UInt32(door & 0x0F)
                    usbOutMax = packet
                }
            }
        }
        offset += length
    }
    if !storage || usbInEp == 0 || usbOutEp == 0 { return 3 }
    usbStageSetup(0x00, 9, UInt16(configValue), 0, 0)
    if usbControl(address, false, true, 0) < 0 { return 2 }
    waitTicks(1)
    usbToggleIn = 0
    usbToggleOut = 0
    return 4
}

/// The look's verdicts, as the three commands share them:
/// no controller of the kind Cardnull speaks; a controller
/// standing, and nothing plugged into it; something
/// plugged in that did not answer its waking; something
/// that answered and declared another kind; and a storage
/// stick, woken, named where it would be named, and
/// measured.
let usbLookNone = 0
let usbLookNoDevice = 1
let usbLookFailed = 2
let usbLookNotStorage = 3
let usbLookStorage = 4

/// Looks at the bus, afresh: the controller found and
/// raised (once — those do not change under a sitting),
/// then each port asked in turn whether anything stands
/// on it, and anything standing woken and arranged. The
/// first stick that stands is the look's answer; a port
/// whose device declares another kind, or will not wake,
/// does not end the looking while another port stands
/// untried — but its verdict is remembered, so an empty
/// hand at the end can still say which truth it met.
func usbLook() -> Int {
    if !usbFindController() { return usbLookNone }
    if !usbRaiseController() { return usbLookFailed }
    var metOther = false
    var metFailure = false
    var port = 0
    while port < 2 {
        let reg = port == 0 ? usbRegPort1 : usbRegPort2
        if usbReadReg(reg) & usbPortConnected != 0 {
            usbPort = port
            if usbResetPort(port) {
                let verdict = usbWakeDevice()
                if verdict == 4 {
                    usbScsiInquire()
                    if !usbScsiReady() { return usbLookFailed }
                    if !usbScsiCapacity() { return usbLookFailed }
                    return usbLookStorage
                }
                if verdict == 3 { metOther = true }
                if verdict == 2 { metFailure = true }
            } else {
                metFailure = true
            }
        }
        port += 1
    }
    if metOther { return usbLookNotStorage }
    if metFailure { return usbLookFailed }
    return usbLookNoDevice
}

/// The stick's filesystem states, judged exactly as the
/// hard disk's are — the same five standings, spoken a
/// second time over the USB road, with the odd standing
/// the stick alone can hold: sectors that are not the 512
/// bytes the format is read in.
let usbStateAbsent = 0
let usbStateSilent = 1
let usbStateBlank = 2
let usbStateForeign = 3
let usbStateDamaged = 4
let usbStateReady = 5
let usbStateOddSector = 6

/// The stick filesystem's home, found by its judging the
/// way the disk's is: sector 0 of the filesystem, wherever
/// it stands — at the stick's head on a plain stick, or
/// behind a partition entry on a prepared one — and the
/// superblock's testimony beside it.
var usbHome: UInt64 = 0
var usbSbTotal: UInt64 = 0
var usbSbNextFree: UInt64 = 0

/// Proves the superblock standing in the stage: the
/// checksum, the version, and the geometry — the measure
/// it claims checked against the measure READ CAPACITY
/// gave, the hard disk's proof spoken over the stick.
func usbProveSuperblock() -> Int {
    let buffer = usbData()
    if hdChecksum(buffer) != hdGet64(buffer, 504) {
        return usbStateDamaged
    }
    if discU32(buffer, 16) != 1 { return usbStateDamaged }
    let total = hdGet64(buffer, 24)
    let nextFree = UInt64(discU32(buffer, 48))
    if total == 0 || total > usbSectors
        || UInt64(discU32(buffer, 40)) != hdDataStart
        || nextFree < hdDataStart || nextFree > total {
        return usbStateDamaged
    }
    usbSbTotal = total
    usbSbNextFree = nextFree
    return usbStateReady
}

/// True when the stage's head carries the format's mark,
/// letter for letter.
func usbFieldHasMagic() -> Bool {
    let buffer = usbData()
    var index = 0
    while index < hdMagicLength {
        if buffer[index] != hdMagic.utf8Start[index] {
            return false
        }
        index += 1
    }
    return true
}

/// Reads one of the filesystem's own sectors — its number
/// reckoned from its home, as the disk's reader reckons.
func usbReadHomeSector(_ relative: UInt64) -> Bool {
    usbReadSector(usbHome + relative)
}

/// Judges the stick afresh, as every disk command judges
/// its disk: its true first sector read, blank and plain
/// and prepared told apart by the same questions the hard
/// disk is asked — the mark at the head, or a signed MBR
/// carrying a partition of Cardnull's own type, behind
/// which the mark must stand and prove out.
func usbReadState() -> Int {
    usbHome = 0
    if usbBlockSize != 512 { return usbStateOddSector }
    if !usbReadSector(0) { return usbStateSilent }
    let buffer = usbData()
    var any = false
    var index = 0
    while index < hdSectorBytes {
        if buffer[index] != 0 { any = true; break }
        index += 1
    }
    if !any { return usbStateBlank }
    if usbFieldHasMagic() {
        return usbProveSuperblock()
    }
    if buffer[510] != 0x55 || buffer[511] != 0xAA {
        return usbStateForeign
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
    if entry >= 4 || candidate == 0 { return usbStateForeign }
    if !usbReadSector(candidate) { return usbStateSilent }
    if !usbFieldHasMagic() { return usbStateForeign }
    if usbProveSuperblock() != usbStateReady {
        return usbStateDamaged
    }
    if candidate + usbSbNextFree > usbSectors
        || partitionLength < usbSbNextFree {
        return usbStateDamaged
    }
    usbHome = candidate
    return usbStateReady
}

/// The stick directory scan's findings, kept as the disk's
/// are: how many entries stand used, and — when a name is
/// sought in the name scratch — the slot that holds it,
/// with its start and length beside.
var usbEntryCount = 0
var usbFoundSlot = -1
var usbFoundStart: UInt32 = 0
var usbFoundLength: UInt32 = 0

/// Walks the stick's whole directory, sector by sector —
/// the hard disk's walk spoken over the USB road, every
/// sector read fresh off the stick, because a stick's
/// directory is a thing its own sectors must testify to.
func usbScanDirectory(_ seekStart: Int, _ seekLength: Int) -> Bool {
    usbEntryCount = 0
    usbFoundSlot = -1
    usbFoundStart = 0
    usbFoundLength = 0
    let seek = discPath()
    var slot = 0
    var dirSector: UInt64 = 0
    while dirSector < hdDirSectors {
        if !usbReadHomeSector(hdDirStart + dirSector) {
            return false
        }
        let buffer = usbData()
        var inSector = 0
        while inSector < Int(hdSectorBytes) / hdEntryBytes {
            let base = inSector * hdEntryBytes
            if buffer[base] != 0 {
                usbEntryCount += 1
                if seekLength > 0 && usbFoundSlot < 0 {
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
                            usbFoundSlot = slot
                            usbFoundStart = discU32(buffer,
                                                    base + 32)
                            usbFoundLength = discU32(buffer,
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

/// Prints the stick's own name for itself — or, when it
/// gave none worth repeating, the plain standing word —
/// through the output door.
func usbWriteName() {
    if usbNameLength > 0 && usbNameAddress != 0 {
        let name = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(usbNameAddress))!
        var index = 0
        while index < usbNameLength {
            writeChar(name[index])
            index += 1
        }
    } else {
        writeStatic(usbGenericName)
    }
}

/// The USB commands' shared vocabulary: the absence, the
/// states, and the refusals — in plain words, with the
/// numbers spoken between them by writeNumber.
let usbGenericName: StaticString = "USB storage device"
let usbNoControllerLine: StaticString =
    "No USB controller of the kind Cardnull speaks (UHCI) was found."
let usbNoStickLine: StaticString =
    "USB stick: no stick is plugged in."
let usbNoAnswerLine: StaticString =
    "A USB device is plugged in, but it did not answer when it was asked."
let usbNotStorageLine: StaticString =
    "A USB device is plugged in, but it is not a storage stick, so there is nothing here Cardnull can read."
let usbStickLabel: StaticString = "USB stick: "
let usbStateBlankLine: StaticString =
    "  It is blank: nothing on it is Cardnull's yet."
let usbStateForeignLine: StaticString =
    "  It is not a Cardnull disk, and its format is not one Cardnull reads yet."
let usbStateDamagedLine: StaticString =
    "  Its Cardnull mark stands, but the mark does not prove out - the disk is damaged."
let usbStateSilentLine: StaticString =
    "  It did not answer when it was asked."
let usbOddSectorLine: StaticString =
    "  Its sectors are not the 512 bytes Cardnull reads, so its files cannot be read yet."
let usbReadyLabel: StaticString = "  A Cardnull disk: "
let usbReadyFilesWord: StaticString =
    " files stand on it. uls lists them; ucat NAME reads one."
let usbReadyFileWord: StaticString =
    " file stands on it. uls lists it; ucat NAME reads it."
let usbBootableReadyLine: StaticString =
    "  It can start the computer by itself."
let usbNotReadyLine: StaticString =
    "The stick is not a Cardnull disk Cardnull can read."
let usbSilentAnswerLine: StaticString =
    "The stick did not answer."
let usbUlsTitle: StaticString = "The USB stick:"
let usbEmptyLine: StaticString = "  (nothing here)"
let usbCountFilesClose: StaticString = " files on the stick."
let usbCountFileClose: StaticString = " file on the stick."
let usbUcatUsageLine: StaticString =
    "ucat wants a name: ucat GREETING"
let usbNotOnStickLabel: StaticString = "Not on the stick: "

/// The device-level account the three commands open with:
/// looks at the bus afresh and speaks the verdict the
/// looking met, returning true only when a storage stick
/// stands woken and measured, ready to be judged.
func usbSpeakLook() -> Bool {
    let look = usbLook()
    if look == usbLookNone {
        writeLine(usbNoControllerLine)
        return false
    }
    if look == usbLookNoDevice {
        writeLine(usbNoStickLine)
        return false
    }
    if look == usbLookFailed {
        writeLine(usbNoAnswerLine)
        return false
    }
    if look == usbLookNotStorage {
        writeLine(usbNotStorageLine)
        return false
    }
    return true
}

/// `usb`: the stick's account — what is plugged in, in
/// the stick's own words where it gives them: its name,
/// its measure in mebibytes with the true bytes beside
/// them, and what stands on it, judged as the hard disk
/// is judged. Nothing plugged in is an answer, not an
/// error, and it is spoken as plainly as a presence.
func runUsb() {
    if !usbSpeakLook() { return }
    writeStatic(usbStickLabel)
    usbWriteName()
    writeStatic(" - ")
    writeNumber(usbSectors * UInt64(usbBlockSize) / 1048576)
    writeStatic(hdMiBWord)
    writeNumber(usbSectors * UInt64(usbBlockSize))
    writeLine(hdBytesClose)
    let state = usbReadState()
    if state == usbStateBlank {
        writeLine(usbStateBlankLine)
    } else if state == usbStateForeign {
        writeLine(usbStateForeignLine)
    } else if state == usbStateDamaged {
        writeLine(usbStateDamagedLine)
    } else if state == usbStateSilent {
        writeLine(usbStateSilentLine)
    } else if state == usbStateOddSector {
        writeLine(usbOddSectorLine)
    } else if state == usbStateReady {
        if usbScanDirectory(0, 0) {
            writeStatic(usbReadyLabel)
            writeNumber(UInt64(usbEntryCount))
            writeLine(usbEntryCount == 1 ? usbReadyFileWord
                                         : usbReadyFilesWord)
            if usbHome != 0 {
                writeLine(usbBootableReadyLine)
            }
        } else {
            writeLine(usbStateSilentLine)
        }
    }
}

/// `uls`: the stick's files, in its directory's own
/// order — two spaces, the name, room to a modest column,
/// and the size — with the count beneath, as `dls` speaks
/// of the hard disk.
func runUls() {
    if !usbSpeakLook() { return }
    let state = usbReadState()
    if state == usbStateSilent || state == usbStateOddSector {
        writeLine(state == usbStateSilent ? usbSilentAnswerLine
                                          : usbOddSectorLine)
        return
    }
    if state != usbStateReady {
        writeLine(usbNotReadyLine)
        return
    }
    writeLine(usbUlsTitle)
    var count = 0
    var dirSector: UInt64 = 0
    while dirSector < hdDirSectors {
        if !usbReadHomeSector(hdDirStart + dirSector) {
            writeLine(usbSilentAnswerLine)
            return
        }
        let buffer = usbData()
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
        writeLine(usbEmptyLine)
    }
    writeNumber(UInt64(count))
    writeLine(count == 1 ? usbCountFileClose : usbCountFilesClose)
}

/// `ucat`: one file off the stick, printed through the
/// one output door with the disk reader's own forgiveness
/// — line feeds end lines, carriage returns are let go, a
/// tab steps to a plain space, and any other character
/// the screen cannot honestly draw is passed over. A name
/// the stick does not hold is answered as missing; a name
/// may wear one leading slash or none, as the house
/// forgives everywhere.
func runUcat() {
    let argLength = copyArgumentToScratch()
    let argument = discPath()
    var start = 0
    if start < argLength && argument[start] == 0x2F { start += 1 }
    let nameLength = argLength - start
    if nameLength <= 0 {
        writeLine(usbUcatUsageLine)
        return
    }
    if !usbSpeakLook() { return }
    let state = usbReadState()
    if state == usbStateSilent || state == usbStateOddSector {
        writeLine(state == usbStateSilent ? usbSilentAnswerLine
                                          : usbOddSectorLine)
        return
    }
    if state != usbStateReady {
        writeLine(usbNotReadyLine)
        return
    }
    if !usbScanDirectory(start, nameLength) {
        writeLine(usbSilentAnswerLine)
        return
    }
    if usbFoundSlot < 0 {
        writeStatic(usbNotOnStickLabel)
        var index = start
        while index < argLength {
            writeChar(argument[index])
            index += 1
        }
        writeNewline()
        return
    }
    var remaining = Int(usbFoundLength)
    var sector = UInt64(usbFoundStart)
    let buffer = usbData()
    while remaining > 0 {
        if !usbReadHomeSector(sector) {
            writeNewline()
            writeLine(usbSilentAnswerLine)
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
