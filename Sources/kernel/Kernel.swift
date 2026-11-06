// Cardnull OS — kernel entry point (skeleton)
//
// This file is the seed of the kernel proper: the function the boot path
// will call once the processor is awake, its tables are set, and control
// passes from the thin assembly floor into Swift.
//
// Today it is a skeleton with an honest job: when the boot chain is wired
// (roadmap milestone 1), kmain will write the machine's first word to the
// screen — CARDNULL — through the text console the boot code prepares.
//
// Written in Swift, in the open, in the public domain.

/// The kernel's first word, and the whole of milestone 1's ambition.
public let cardnullBanner = "CARDNULL"

/// Kernel entry point. Called once by the boot path; never returns —
/// an operating system that finishes has stopped being one.
public func kmain() {
    // Milestone 1 wires this to the screen console prepared by the boot
    // floor: print cardnullBanner, then idle with interrupts enabled.
    while true {
        // Rest. The work comes to us by interrupt.
    }
}
