// Cardnull OS — the kernel.
//
// This file is the kernel proper: the function the boot floor calls once
// the processor is awake, its page tables are set, and control passes
// from the thin assembly floor into Swift.
//
// It is written in Embedded Swift — Swift compiled freestanding, with no
// operating system beneath it and no standard library beyond what can
// live on bare metal. Nothing is imported; there is nothing to import
// from yet.
//
// Written in Swift, in the open, in the public domain.

/// Provided by the boot floor (boot.S): stops the processor with `hlt`,
/// forever. The kernel's rest, once its work is done.
@_silgen_name("cardnull_halt")
func cardnullHalt() -> Never

/// The kernel's first word, and the whole of milestone 1's ambition.
///
/// A StaticString, not a String: Embedded Swift has no heap and no
/// String type yet, so the banner lives in the kernel's read-only data
/// as raw UTF-8 bytes — which is all the screen needs from it.
public let cardnullBanner: StaticString = "CARDNULL"

/// Writes one character cell into the VGA text buffer.
///
/// The PC text screen is a memory-mapped grid at physical address
/// 0xB8000: 80 columns x 25 rows, two bytes per cell — the character,
/// then its attribute (color). We write through a raw pointer; on bare
/// metal, that is not recklessness, it is the hardware manual.
@inline(__always)
func vgaWrite(cell offset: Int, character: UInt8, attribute: UInt8) {
    let buffer = UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
    buffer[offset] = UInt16(attribute) << 8 | UInt16(character)
}

/// Kernel entry point. Called once by the boot floor; never returns —
/// an operating system that finishes has stopped being one.
///
/// Milestone 1, in full: put CARDNULL on the screen, then rest.
@_cdecl("kmain")
public func kmain() {
    // White letters (0xF) on a black field (0x0).
    let attribute: UInt8 = 0x0F

    // Wipe the screen the bootloader left behind: 80 x 25 blank cells,
    // so the first word stands on a clean field.
    for cell in 0 ..< (80 * 25) {
        vgaWrite(cell: cell, character: 0x20, attribute: attribute)
    }

    // The banner, at the top-left cell. A StaticString's bytes are
    // stored NUL-terminated in read-only data (Embedded Swift's trimmed
    // StaticString offers the pointer but not the length), so walk to
    // the terminator — and never past the edge of the first row.
    var cell = 0
    while cell < 80 {
        let character = cardnullBanner.utf8Start[cell]
        if character == 0 { break }
        vgaWrite(cell: cell, character: character, attribute: attribute)
        cell += 1
    }

    // The first word is spoken. Rest, and let the work come by interrupt.
    cardnullHalt()
}
