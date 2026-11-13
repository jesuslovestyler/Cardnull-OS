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

