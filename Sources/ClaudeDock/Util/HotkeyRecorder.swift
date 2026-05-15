import AppKit

/// Pure-logic helpers for translating key codes / modifier masks into
/// human-readable strings, plus a validation rule that prevents users from
/// hijacking a bare key (e.g. "B" with no modifier).
///
/// The live-monitor side of the recorder is a small SwiftUI/AppKit attachment
/// in HotkeySettingsView; this struct only knows about the values.
enum HotkeyRecorder {
    enum Validation: Equatable {
        case ok
        case rejectedTooLoose
        case rejectedFunctionOnly
    }

    static func validate(keyCode: UInt16, modifiers: UInt) -> Validation {
        let mods = NSEvent.ModifierFlags(rawValue: modifiers)
        let interesting: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        if mods.intersection(interesting).isEmpty { return .rejectedTooLoose }
        return .ok
    }

    static func displayString(keyCode: UInt16, modifiers: UInt) -> String {
        let mods = NSEvent.ModifierFlags(rawValue: modifiers)
        var prefix = ""
        if mods.contains(.control)  { prefix += "⌃" }
        if mods.contains(.option)   { prefix += "⌥" }
        if mods.contains(.shift)    { prefix += "⇧" }
        if mods.contains(.command)  { prefix += "⌘" }
        let key = Self.keyName(for: keyCode)
        return prefix.isEmpty ? key : "\(prefix) \(key)"
    }

    private static let table: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",
    ]

    static func keyName(for keyCode: UInt16) -> String {
        table[keyCode] ?? "Key \(keyCode)"
    }
}
