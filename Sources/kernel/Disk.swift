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
// The commands are ten: `disk` reports both drives and the
// hard disk's state; `format` makes a blank or foreign disk a
// Cardnull disk, behind a typed confirmation; `dsave` saves a
// line of words as a file; `dls` lists the disk's files;
// `dcat` reads one back; `rename` renames one of the disk's
// files, `copy` copies one, and `delete` — behind the same
// typed confirmation — removes one, its name and its
// directory slot set down free and its data's ground never
// given again (milestone 30); `install` — behind the same
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
let hdDeleteWord: StaticString = "delete"

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
    " already stands on the disk."
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

// ---------------------------------------------------------------------------
// Milestone 30: the disk's files gain their manners — a file
// can be renamed, copied, and deleted.
//
// Until now a name, once given to a file on the hard disk,
// stood for the disk's life: `dsave` could give a name, and
// nothing could change it, carry the file's bytes to a
// second name, or take the file away. This stone adds the
// three keeping-house commands of the family — `rename`,
// `copy`, and `delete` — working on the disk's own files
// alone. The disc's files are the disc's, read-only as
// ever, and no road is made from them here; `install`
// remains the one carrying from the disc.
//
// `rename` is a directory matter and nothing more: the
// entry that stands is found, and its name field alone is
// rewritten — the entry is remade in its own slot by the
// family's own writing hand, with the file's start and
// length carried over untouched — so the file's run, its
// length, and its place in the directory do not move, and
// no data sector is touched. Because the entry itself is
// renamed — no second entry is made and none is unmade —
// the name it leaves stands free: a later `dsave` may take
// it, and the file answers to its new name alone.
//
// `copy` walks the road the format already trusts, the one
// `dsave` and `install` walk: the source's bytes are read
// and written, sector by sector, to a fresh unbroken run
// at the data's next free sector; the new entry is
// written; the superblock is written last. The two files
// then stand independent — each has its own run, and what
// befalls one says nothing about the other.
//
// `delete` removes a file, and because removing is the
// destructive act of this family it stands behind the
// family's typed gate, as `format` and `install` do: the
// word DELETE must be typed at the asking, and anything
// else gives up with nothing written. The removing itself
// unmakes the directory entry whole — its sixty-four bytes
// returned to zero, so the slot stands exactly as a
// never-used slot stands — and the superblock's count is
// set one lower, written last as ever. Two things are set
// free: the file's name, which a later save may take, and
// its directory slot. One thing is not: the file's data
// run. The data's next free sector never walks backward
// in this format, so the deleted file's ground is never
// given to another file; its bytes stand on the disk
// unread — no directory names them, and no command can
// reach them — until a `format` makes the disk new. That
// is the format's plain bargain, and it is written where
// the format is defined, in docs/DISK.md.
//
// The old rule this stone retires is milestone 21's: a
// name once standing was never reused, there being no
// command that could set one down. Renaming and deleting
// are that setting down, and the rule now stands as it is
// written in DISK.md: a name that stands cannot be taken —
// by save, rename, or copy alike — and a name set down
// stands free again. There is still no overwrite anywhere
// in the format.
//
// The refusals are the family's own, in the family's
// words: no disk, a disk not Cardnull's yet, a file the
// disk does not hold, a new name this house cannot keep, a
// new name already standing, a full directory, no room,
// and — rename's own — a new name that is the name the
// file already wears, which would rename nothing. Every
// refusal is spoken before any writing, and a refusal
// writes nothing at all: the proof of that stands on the
// bench, in a host-side hash of the disk taken before and
// after a session of refused commands, byte for byte the
// same.
// ---------------------------------------------------------------------------

/// rename's, copy's, and delete's vocabulary: their
/// usages, the gate's asking, and their answers' shapes,
/// with the numbers and the names spoken between them.
let hdRenameUsageLine: StaticString =
    "rename wants two names: rename OLD NEW"
let hdCopyUsageLine: StaticString =
    "copy wants two names: copy OLD NEW"
let hdDeleteUsageLine: StaticString =
    "delete wants a name: delete GREETING"
let hdSameNameLine: StaticString =
    "That is the name it already has. Nothing was renamed."
let hdRenamedLabel: StaticString = "Renamed "
let hdCopiedLabel: StaticString = "Copied "
let hdToWord: StaticString = " to "
let hdDotClose: StaticString = "."
let hdDeleteWarnLabel: StaticString = "delete will remove "
let hdDeleteWarnMiddle: StaticString = " ("
let hdDeleteWarnClose: StaticString =
    " bytes) from the hard disk for good. Nothing can bring it back."
let hdDeleteAskLine: StaticString =
    "Type DELETE and press Enter to remove it. Anything else gives up, and nothing is written."
let hdDeletedLabel: StaticString = "Deleted "

/// The two name words rename and copy are spoken with,
/// reckoned from the argument scratch: their starts and
/// lengths stand in the globals below. One leading slash
/// on the first word is forgiven, as the family forgives
/// it everywhere.
var hdWord1Start = 0
var hdWord1Length = 0
var hdWord2Start = 0
var hdWord2Length = 0

/// Reckons the two name words standing in the argument
/// scratch. The answering is false when the line does not
/// carry exactly two words — a name missing, or a third
/// word trailing behind the second, is the usage's affair,
/// answered by the caller in the command's own words:
/// taking the first two words of three and letting the
/// third go silently could rename a file to a name the
/// typist did not mean whole.
func hdParseTwoNames(_ argument: UnsafeMutablePointer<UInt8>,
                     _ argLength: Int) -> Bool {
    var start = 0
    if start < argLength && argument[start] == 0x2F { start += 1 }
    var end1 = start
    while end1 < argLength && argument[end1] != 0x20 { end1 += 1 }
    hdWord1Start = start
    hdWord1Length = end1 - start
    var start2 = end1
    while start2 < argLength && argument[start2] == 0x20 {
        start2 += 1
    }
    var end2 = start2
    while end2 < argLength && argument[end2] != 0x20 { end2 += 1 }
    hdWord2Start = start2
    hdWord2Length = end2 - start2
    var rest = end2
    while rest < argLength && argument[rest] == 0x20 { rest += 1 }
    if hdWord1Length == 0 || hdWord2Length == 0 { return false }
    return rest >= argLength
}

/// True when the word standing in the argument scratch at
/// `start`, `length` letters long, is a name this house can
/// keep: the reckoning `dsave` makes of the name it is
/// given — letters, digits, dots, dashes and underscores,
/// at most the directory's reach of thirty-one, and never
/// "." or "..". It judges names being given, never names
/// being sought: a name the disk cannot hold is answered
/// by the seeking itself, as not on the disk.
func hdNameCanStand(_ argument: UnsafeMutablePointer<UInt8>,
                    _ start: Int, _ length: Int) -> Bool {
    if length <= 0 || length > hdNameCap { return false }
    var index = start
    while index < start + length {
        let byte = argument[index]
        let letter = byte >= 0x41 && byte <= 0x5A
            || byte >= 0x61 && byte <= 0x7A
        let digit = byte >= 0x30 && byte <= 0x39
        if !letter && !digit && byte != 0x2E && byte != 0x2D
            && byte != 0x5F {
            return false
        }
        index += 1
    }
    if length == 1 && argument[start] == 0x2E { return false }
    if length == 2 && argument[start] == 0x2E
        && argument[start + 1] == 0x2E { return false }
    return true
}

/// True when the two name words are one name, capitals
/// folded for the meeting, as every name in this house is
/// matched.
func hdWordsAreOneName(
    _ argument: UnsafeMutablePointer<UInt8>) -> Bool {
    if hdWord1Length != hdWord2Length { return false }
    var index = 0
    while index < hdWord1Length {
        if featherFold(argument[hdWord1Start + index])
            != featherFold(argument[hdWord2Start + index]) {
            return false
        }
        index += 1
    }
    return true
}

/// Speaks one word standing in the argument scratch
/// through the output door, letter for letter as typed.
func hdWriteWord(_ argument: UnsafeMutablePointer<UInt8>,
                 _ start: Int, _ length: Int) {
    var index = start
    while index < start + length {
        writeChar(argument[index])
        index += 1
    }
}

/// Unmakes one directory entry: the entry's whole
/// sixty-four bytes are returned to zero — the standing
/// mark, the name, the start, the length — so the slot
/// stands exactly as a never-used slot stands. The file's
/// data run is not touched: its ground is simply never
/// given again, as the milestone's own words above say.
func hdEraseEntry(_ slot: Int) -> Bool {
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
    return hdWriteSector(dirSector)
}

/// `rename`: a file on the hard disk takes a new name.
/// The old name is sought first — a file the disk does not
/// hold is answered as missing; then the new name is
/// judged: it must be a name this house can keep, it must
/// not be the name the file already wears, and it must
/// not already stand. The writing is one directory entry
/// remade in its slot, the file's start and length carried
/// over untouched, and the drive's cache made to stand.
func runRename() {
    let argLength = copyArgumentToScratch()
    let argument = discPath()
    if !hdParseTwoNames(argument, argLength) {
        writeLine(hdRenameUsageLine)
        return
    }
    if !hdNameCanStand(argument, hdWord2Start, hdWord2Length) {
        writeLine(hdBadNameLine)
        return
    }
    if hdWordsAreOneName(argument) {
        writeLine(hdSameNameLine)
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
    if !hdScanDirectory(hdWord1Start, hdWord1Length) {
        writeLine(hdSilentAnswerLine)
        return
    }
    if hdFoundSlot < 0 {
        writeStatic(hdNotOnDiskLabel)
        hdWriteWord(argument, hdWord1Start, hdWord1Length)
        writeNewline()
        return
    }
    let slot = hdFoundSlot
    let start = hdFoundStart
    let length = hdFoundLength
    if !hdScanDirectory(hdWord2Start, hdWord2Length) {
        writeLine(hdSilentAnswerLine)
        return
    }
    if hdFoundSlot >= 0 {
        writeStatic(hdTakenLabel)
        hdWriteWord(argument, hdWord2Start, hdWord2Length)
        writeLine(hdTakenClose)
        return
    }
    if !hdWriteEntry(slot, UnsafePointer(argument),
                     hdWord2Start, hdWord2Length, start, length) {
        writeLine(hdWriteFailedLine)
        return
    }
    _ = hdFlush()
    writeStatic(hdRenamedLabel)
    hdWriteWord(argument, hdWord1Start, hdWord1Length)
    writeStatic(hdToWord)
    hdWriteWord(argument, hdWord2Start, hdWord2Length)
    writeLine(hdDotClose)
}

/// `copy`: a file on the hard disk is copied to a new
/// name. The source is sought first, then the new name is
/// judged as rename judges it — keepable, and not already
/// standing — and the directory must have a slot and the
/// disk the room, both answered before any writing. The
/// copying itself walks the format's order: the source's
/// sectors, read and written one by one to a fresh run at
/// the data's next free sector; then the new entry; then
/// the superblock, last as ever.
func runCopy() {
    let argLength = copyArgumentToScratch()
    let argument = discPath()
    if !hdParseTwoNames(argument, argLength) {
        writeLine(hdCopyUsageLine)
        return
    }
    if !hdNameCanStand(argument, hdWord2Start, hdWord2Length) {
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
    if !hdScanDirectory(hdWord1Start, hdWord1Length) {
        writeLine(hdSilentAnswerLine)
        return
    }
    if hdFoundSlot < 0 {
        writeStatic(hdNotOnDiskLabel)
        hdWriteWord(argument, hdWord1Start, hdWord1Length)
        writeNewline()
        return
    }
    let sourceStart = UInt64(hdFoundStart)
    let sourceLength = UInt64(hdFoundLength)
    if !hdScanDirectory(hdWord2Start, hdWord2Length) {
        writeLine(hdSilentAnswerLine)
        return
    }
    if hdFoundSlot >= 0 {
        writeStatic(hdTakenLabel)
        hdWriteWord(argument, hdWord2Start, hdWord2Length)
        writeLine(hdTakenClose)
        return
    }
    if hdFreeSlot < 0 {
        writeLine(hdDirFullLine)
        return
    }
    let sectors = (sourceLength + UInt64(hdSectorBytes) - 1)
        / UInt64(hdSectorBytes)
    if hdSbNextFree + sectors > hdSbTotal {
        writeLine(hdDiskFullLine)
        return
    }
    var index: UInt64 = 0
    while index < sectors {
        if !hdReadSector(sourceStart + index) {
            writeLine(hdWriteFailedLine)
            return
        }
        if !hdWriteSector(hdSbNextFree + index) {
            writeLine(hdWriteFailedLine)
            return
        }
        index += 1
    }
    if !hdWriteEntry(hdFreeSlot, UnsafePointer(argument),
                     hdWord2Start, hdWord2Length,
                     UInt32(hdSbNextFree), UInt32(sourceLength)) {
        writeLine(hdWriteFailedLine)
        return
    }
    if !hdWriteSuperblock(UInt32(hdEntryCount + 1),
                          hdSbNextFree + sectors) {
        writeLine(hdWriteFailedLine)
        return
    }
    _ = hdFlush()
    writeStatic(hdCopiedLabel)
    hdWriteWord(argument, hdWord1Start, hdWord1Length)
    writeStatic(hdToWord)
    hdWriteWord(argument, hdWord2Start, hdWord2Length)
    writeStatic(hdSavedMiddle)
    writeNumber(sourceLength)
    writeLine(hdSavedClose)
}

/// `delete`: a file on the hard disk is removed, behind
/// the family's typed gate. The file is sought first — a
/// name the disk does not hold is answered as missing,
/// before any asking — then the warning names the file
/// and its size and says plainly that nothing can bring
/// it back, and the gate waits for the word DELETE:
/// anything else, a near miss, a bare Enter, Esc, gives up
/// with nothing written, in the family's own aborted
/// words. The removing unmakes the entry whole and sets
/// the superblock's count one lower, the superblock
/// written after the entry as the format's order demands;
/// the file's data run is left standing unread, its ground
/// never given again, as the milestone's words above say.
func runDelete() {
    let argLength = copyArgumentToScratch()
    let argument = discPath()
    var start = 0
    if start < argLength && argument[start] == 0x2F { start += 1 }
    let nameLength = argLength - start
    if nameLength <= 0 {
        writeLine(hdDeleteUsageLine)
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
        hdWriteWord(argument, start, nameLength)
        writeNewline()
        return
    }
    let slot = hdFoundSlot
    writeStatic(hdDeleteWarnLabel)
    hdWriteWord(argument, start, nameLength)
    writeStatic(hdDeleteWarnMiddle)
    writeNumber(UInt64(hdFoundLength))
    writeLine(hdDeleteWarnClose)
    writeLine(hdDeleteAskLine)
    writeStatic(hdYourWordLabel)
    if !hdConfirmationMatches(hdDeleteWord) {
        writeLine(hdAbortedLine)
        return
    }
    if !hdEraseEntry(slot) {
        writeLine(hdWriteFailedLine)
        return
    }
    if !hdWriteSuperblock(UInt32(hdEntryCount - 1),
                          hdSbNextFree) {
        writeLine(hdWriteFailedLine)
        return
    }
    _ = hdFlush()
    writeStatic(hdDeletedLabel)
    hdWriteWord(argument, start, nameLength)
    writeLine(hdDotClose)
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


