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

