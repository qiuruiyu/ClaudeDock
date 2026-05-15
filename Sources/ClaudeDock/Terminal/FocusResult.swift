enum FocusResult: Equatable, Sendable {
    case precise(app: String, window: String)
    case activatedAppOnly(app: String)
    case noTerminalHint
    case failed(reason: String)
}
