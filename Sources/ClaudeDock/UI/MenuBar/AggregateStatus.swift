import Foundation

enum AggregateStatus: String, Equatable, Sendable {
    case red, yellow, green, gray

    static func compute(_ sessions: [Session]) -> AggregateStatus {
        let active = sessions.filter { $0.status != .ended }
        if active.isEmpty { return .gray }
        if active.contains(where: { $0.status == .waitingInput }) { return .red }
        if active.contains(where: { $0.status == .thinking }) { return .yellow }
        return .green
    }
}
