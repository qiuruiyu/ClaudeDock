import SwiftUI

struct SessionRowView: View {
    let session: Session
    let displayName: String
    let color: ColorTag
    let isPinned: Bool
    let onTap: (Session) async -> Void
    let onRename: (Session) -> Void
    let onSetColor: (Session, ColorTag) -> Void
    let onTogglePin: (Session) -> Void
    let onCopyCwd: (Session) -> Void
    let onRevealFinder: (Session) -> Void
    let onForget: (Session) -> Void

    @State private var isHovering = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            rail
            VStack(alignment: .leading, spacing: 4) {
                nameLine
                metaLine
            }
            .padding(.leading, 14)
            Spacer(minLength: 8)
            if isHovering {
                Text("focus ›")
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundStyle(Theme.amber)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(isHovering ? Theme.surface1 : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.14), value: isHovering)
        // Order matters: register count:2 first so it wins over single-tap.
        .onTapGesture(count: 2) { onRename(session) }
        .onTapGesture { Task { await onTap(session) } }
        .contextMenu { menuContents }
        .onAppear {
            if session.status == .waitingInput {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .opacity(session.status == .ended ? 0.55 : 1.0)
    }

    // MARK: Pieces

    private var rail: some View {
        // 3pt vertical color bar at the row's leading edge. Pulses softly when
        // status is waitingInput so the eye is drawn to the actionable row.
        Capsule()
            .fill(Theme.color(for: session.status))
            .frame(width: 3)
            .opacity(session.status == .waitingInput && pulse ? 0.55 : 1.0)
            .shadow(color: session.status == .waitingInput
                    ? Theme.red.opacity(pulse ? 0.5 : 0.0) : .clear,
                    radius: 4)
            .padding(.vertical, 1)
    }

    private var nameLine: some View {
        HStack(spacing: 7) {
            // User-assigned color tag (set via right-click → Set color).
            // Distinct from the status rail — that's automatic, this is your label.
            RoundedRectangle(cornerRadius: 2)
                .fill(SwiftUI.Color(colorTag: color))
                .frame(width: 7, height: 7)
            Text(baseName)
                .font(Theme.mono(13.5, weight: .medium))
                .foregroundStyle(Theme.cream)
                .lineLimit(1)
                .truncationMode(.tail)
            if let idx = session.sameCwdIndex {
                Text("·\(idx)")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.creamDeeper)
            }
            if isPinned {
                Text("★")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.amber)
            }
        }
    }

    /// `baseName` strips the trailing "#N" suffix that the caller appends to
    /// displayName — we render the index separately in a dimmer color.
    private var baseName: String {
        if session.sameCwdIndex != nil,
           let hashRange = displayName.range(of: " #", options: .backwards) {
            return String(displayName[..<hashRange.lowerBound])
        }
        return displayName
    }

    private var metaLine: some View {
        HStack(spacing: 7) {
            Text(Theme.statusLabel(for: session.status).uppercased())
                .font(Theme.mono(9, weight: .medium))
                .foregroundStyle(Theme.color(for: session.status))
                .tracking(1.2)
            Text("·")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper.opacity(0.6))
            Text(session.identity.workKey.prefix(6))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.creamDeeper)
            Text("·")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper.opacity(0.6))
            Text(relativeAgo(from: session.lastEventAt))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.creamDeeper)
        }
    }

    private func relativeAgo(from date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(max(s, 1))s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }

    // MARK: Context menu

    @ViewBuilder
    private var menuContents: some View {
        Button("Rename…") { onRename(session) }
        Menu("Set color") {
            ForEach(ColorTag.allCases, id: \.self) { c in
                Button(action: { onSetColor(session, c) }) {
                    Label(c.rawValue.capitalized, systemImage: "circle.fill")
                }
            }
        }
        Button(isPinned ? "Unpin" : "Pin") { onTogglePin(session) }
        Divider()
        Button("Copy cwd") { onCopyCwd(session) }
        Button("Reveal in Finder") { onRevealFinder(session) }
        Divider()
        Button("Forget", role: .destructive) { onForget(session) }
    }
}

extension SwiftUI.Color {
    init(colorTag: ColorTag) {
        switch colorTag {
        case .blue:   self = .blue
        case .green:  self = .green
        case .orange: self = .orange
        case .red:    self = .red
        case .purple: self = .purple
        case .pink:   self = .pink
        case .yellow: self = .yellow
        case .teal:   self = .teal
        }
    }
}
