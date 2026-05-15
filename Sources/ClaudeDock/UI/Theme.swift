import SwiftUI

/// v2 "console" palette and type ramp. Warm cream on near-black with a single
/// amber accent; mono-first typography. See docs/design/popover-v2-console.html
/// for the design rationale.
enum Theme {
    // MARK: Palette

    static let ink         = Color(red: 14/255,  green: 13/255,  blue: 12/255)   // #0E0D0C
    static let cream       = Color(red: 232/255, green: 226/255, blue: 212/255)  // #E8E2D4
    static let creamDim    = Color(red: 232/255, green: 226/255, blue: 212/255).opacity(0.55)
    static let creamDeeper = Color(red: 232/255, green: 226/255, blue: 212/255).opacity(0.35)
    static let amber       = Color(red: 240/255, green: 167/255, blue: 66/255)   // #F0A742
    static let green       = Color(red: 127/255, green: 176/255, blue: 105/255)  // #7FB069
    static let yellow      = Color(red: 232/255, green: 185/255, blue: 72/255)   // #E8B948
    static let red         = Color(red: 217/255, green: 83/255,  blue: 79/255)   // #D9534F
    static let gray        = Color(red: 92/255,  green: 88/255,  blue: 82/255)   // #5C5852

    static let hairline    = Color(red: 232/255, green: 226/255, blue: 212/255).opacity(0.08)
    static let hairline2   = Color(red: 232/255, green: 226/255, blue: 212/255).opacity(0.14)
    static let surface1    = Color(red: 255/255, green: 246/255, blue: 230/255).opacity(0.04)
    static let surface2    = Color(red: 255/255, green: 246/255, blue: 230/255).opacity(0.08)

    // MARK: Surface sizes

    static let popoverWidth: CGFloat = 360
    static let popoverHeight: CGFloat = 520

    // MARK: Status color helpers

    static func color(for status: SessionStatus) -> Color {
        switch status {
        case .waitingInput: return red
        case .thinking:     return yellow
        case .idle:         return green
        case .starting:     return gray
        case .ended:        return gray
        }
    }

    static func color(for agg: AggregateStatus) -> Color {
        switch agg {
        case .red:    return red
        case .yellow: return yellow
        case .green:  return green
        case .gray:   return gray
        }
    }

    static func statusLabel(for status: SessionStatus) -> String {
        switch status {
        case .waitingInput: return "needs input"
        case .thinking:     return "thinking"
        case .idle:         return "idle"
        case .starting:     return "starting"
        case .ended:        return "ended"
        }
    }

    // MARK: Type helpers

    /// Primary display mono — used for session names and the aggregate label.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Sans for the few non-mono moments (empty-state secondary line, etc.).
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
