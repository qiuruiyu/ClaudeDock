import AppKit
import Testing
@testable import ClaudeDock

@Suite struct HotkeyRecorderTests {
    @Test func displayStringForOptionSpace() {
        let s = HotkeyRecorder.displayString(keyCode: 49,
                                             modifiers: NSEvent.ModifierFlags.option.rawValue)
        #expect(s == "⌥ Space")
    }

    @Test func displayStringForCommandShiftK() {
        let mods: UInt = NSEvent.ModifierFlags.command.rawValue
                       | NSEvent.ModifierFlags.shift.rawValue
        let s = HotkeyRecorder.displayString(keyCode: 40, modifiers: mods)
        #expect(s == "⇧⌘ K")
    }

    @Test func emptyModifiersIsRejectedAsTooLoose() {
        let v = HotkeyRecorder.validate(keyCode: 49, modifiers: 0)
        #expect(v == .rejectedTooLoose)
    }

    @Test func validComboPasses() {
        let mods = NSEvent.ModifierFlags.option.rawValue
        let v = HotkeyRecorder.validate(keyCode: 49, modifiers: mods)
        #expect(v == .ok)
    }
}
