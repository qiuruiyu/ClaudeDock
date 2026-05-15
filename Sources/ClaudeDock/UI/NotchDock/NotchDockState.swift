import Foundation

enum NotchDockState: Equatable {
    case hidden
    case showing(Session, until: Date)

    static func == (lhs: NotchDockState, rhs: NotchDockState) -> Bool {
        switch (lhs, rhs) {
        case (.hidden, .hidden): return true
        case (.showing(let a, _), .showing(let b, _)): return a.id == b.id
        default: return false
        }
    }
}
