import SwiftUI
import AppKit

struct SessionListView: View {
    @ObservedObject var store: SessionStore
    let aliases: AliasStore
    let focuser: TerminalFocuser
    let onGearTap: () -> Void
    let onRefresh: () -> Void
    let onDismiss: () -> Void
    private let resolver = NameResolver()

    @State private var toast: String?
    @State private var renamingSession: Session?
    @State private var searchText: String = ""
    @State private var groupBy: GroupDim = .cwd
    @State private var showSearch: Bool = false
    @State private var endedExpanded: Bool = false

    enum GroupDim: String, CaseIterable, Identifiable {
        case cwd, gitRepo, color, status
        var id: String { rawValue }
        var label: String {
            switch self {
            case .cwd:     return "project"
            case .gitRepo: return "repo"
            case .color:   return "color"
            case .status:  return "status"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                hairline
                filterStrip
                hairline
                if showSearch || store.sessions.filter({ $0.status != .ended }).count >= 8 {
                    searchBar
                    hairline
                }
                sessionListOrEmpty
                hairline
                footer
            }
            if let toast {
                Text(toast)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.cream)
                    .padding(8)
                    .background(Theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.hairline2, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.top, 44)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .frame(width: Theme.popoverWidth, height: Theme.popoverHeight)
        .background(Theme.ink)
        .onChange(of: renamingSession) { _, sess in
            guard let sess else { return }
            presentRenameAlert(for: sess)
            renamingSession = nil
        }
    }

    // MARK: Chrome

    private var hairline: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    private var header: some View {
        HStack(spacing: 0) {
            // Aggregate status dot
            ZStack {
                Circle()
                    .fill(Theme.color(for: AggregateStatus.compute(store.sessions)))
                    .frame(width: 8, height: 8)
                if AggregateStatus.compute(store.sessions) == .red {
                    Circle()
                        .stroke(Theme.red.opacity(0.5), lineWidth: 1)
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulseRing ? 1.4 : 1.0)
                        .opacity(pulseRing ? 0.0 : 0.7)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulseRing)
                }
            }
            .frame(width: 16, height: 16)
            .padding(.leading, 12)
            .onAppear { pulseRing = true }

            HStack(spacing: 0) {
                Text("\(activeCount)")
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(" sessions")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.cream)
                if waitingCount > 0 {
                    Text("  \(waitingCount) waiting")
                        .font(Theme.mono(11, weight: .medium))
                        .foregroundStyle(Theme.red)
                }
            }
            .padding(.leading, 8)

            Spacer()

            iconButton(systemName: "magnifyingglass", tip: "Search") {
                withAnimation(.easeInOut(duration: 0.15)) { showSearch.toggle() }
            }
            iconButton(systemName: "arrow.clockwise", tip: "Refresh sessions", action: onRefresh)
            iconButton(systemName: "gearshape", tip: "Settings", action: onGearTap)
        }
        .frame(height: 38)
        .padding(.trailing, 8)
    }

    @State private var pulseRing: Bool = false

    private func iconButton(systemName: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.creamDim)
                .frame(width: 24, height: 24)
                .background(Theme.surface1.opacity(0.0001))   // hit-test area
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    private var filterStrip: some View {
        HStack(spacing: 4) {
            ForEach(GroupDim.allCases) { dim in
                chip(label: dim.label, active: groupBy == dim) {
                    groupBy = dim
                }
            }
            Spacer()
            Text("↓ recent")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper)
                .tracking(0.8)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
    }

    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(10, weight: active ? .medium : .regular))
                .foregroundStyle(active ? Theme.ink : Theme.creamDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(active ? Theme.amber : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.creamDeeper)
            TextField("", text: $searchText, prompt: Text("search…").foregroundStyle(Theme.creamDeeper))
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.cream)
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .transition(.opacity)
    }

    @ViewBuilder
    private var sessionListOrEmpty: some View {
        let (active, ended) = activeAndEnded()
        if active.isEmpty && ended.isEmpty {
            emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !active.isEmpty {
                        activeListBody(active)
                    }
                    if !ended.isEmpty {
                        endedSection(ended)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func activeListBody(_ active: [Session]) -> some View {
        ForEach(grouped(active), id: \.key) { group in
            Section {
                ForEach(group.members) { session in
                    row(for: session)
                }
            } header: {
                if shouldShowGroupHeader(group: group) {
                    groupHeader(group: group)
                }
            }
        }
    }

    private func endedSection(_ ended: [Session]) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) { endedExpanded.toggle() }
            }) {
                HStack(spacing: 10) {
                    Text("ENDED · \(ended.count)")
                        .font(Theme.mono(9, weight: .medium))
                        .foregroundStyle(Theme.creamDeeper)
                        .tracking(2.0)
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    Image(systemName: endedExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Theme.creamDeeper)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if endedExpanded {
                ForEach(ended) { session in
                    row(for: session)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func row(for session: Session) -> some View {
        let baseName = resolver.resolve(cwd: session.identity.cwd,
                                        workKey: session.identity.workKey,
                                        aliasStore: aliases)
        let suffix = session.sameCwdIndex.map { " #\($0)" } ?? ""
        let displayName = baseName + suffix
        SessionRowView(
            session: session,
            displayName: displayName,
            color: aliases.meta(forWorkKey: session.identity.workKey)?.color ?? .blue,
            isPinned: aliases.meta(forWorkKey: session.identity.workKey)?.pinned ?? false,
            onTap: { sess in await onRowTap(sess) },
            onRename: { sess in renamingSession = sess },
            onSetColor: { sess, c in store.setColor(workKey: sess.identity.workKey, to: c) },
            onTogglePin: { sess in
                let current = aliases.meta(forWorkKey: sess.identity.workKey)?.pinned ?? false
                store.setPinned(workKey: sess.identity.workKey, !current)
            },
            onCopyCwd: { sess in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(sess.identity.cwd, forType: .string)
            },
            onRevealFinder: { sess in
                NSWorkspace.shared.open(URL(fileURLWithPath: sess.identity.cwd))
            },
            onForget: { sess in store.forget(sessionId: sess.id) }
        )
    }

    private func shouldShowGroupHeader(group: (key: String, members: [Session])) -> Bool {
        // Hide single-group "cwd" header (avoids redundant label when only one project)
        return grouped(filteredSessions(store.sessions)).count > 1
    }

    private func groupHeader(group: (key: String, members: [Session])) -> some View {
        HStack(spacing: 10) {
            Text(groupHeaderLabel(group.key).uppercased())
                .font(Theme.mono(9, weight: .medium))
                .foregroundStyle(Theme.creamDeeper)
                .tracking(2.0)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            Text("\(group.members.count)")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func groupHeaderLabel(_ key: String) -> String {
        // For cwd grouping, key is a path — collapse to last component.
        if groupBy == .cwd {
            return (key as NSString).lastPathComponent
        }
        return key
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Text("⏎")
                .font(Theme.mono(9, weight: .medium))
                .foregroundStyle(Theme.creamDim)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Theme.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(" focus")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper)
                .padding(.trailing, 8)
            Text("⌘,")
                .font(Theme.mono(9, weight: .medium))
                .foregroundStyle(Theme.creamDim)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Theme.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(" settings")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper)
            Spacer()
            // Independence badge
            Circle().fill(Theme.green).frame(width: 4, height: 4)
            Text(" independent")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.green.opacity(0.7))
            Text(" · ")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.creamDeeper)
            Button { NSApp.terminate(nil) } label: {
                Text("quit")
                    .font(Theme.mono(9, weight: .medium))
                    .foregroundStyle(Theme.creamDim)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit ClaudeDock (or right-click the menu bar icon)")
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                Text("claudedock · ")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.creamDim)
                Text("awaiting")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.cream)
                BlinkingCaret()
            }
            Text("Open a terminal and run **claude**. The first hook event lands here within a second.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.creamDeeper)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Filtering + grouping

    private var activeCount: Int {
        store.sessions.filter { $0.status != .ended }.count
    }

    private var waitingCount: Int {
        store.sessions.filter { $0.status == .waitingInput }.count
    }

    private func filteredSessions(_ all: [Session]) -> [Session] {
        let lower = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return all.filter { s in
            // Include ended sessions only if they're not stale
            if lower.isEmpty { return true }
            let name = resolver.resolve(cwd: s.identity.cwd,
                                        workKey: s.identity.workKey,
                                        aliasStore: aliases).lowercased()
            return name.contains(lower) || s.identity.cwd.lowercased().contains(lower)
        }
    }

    private func activeAndEnded() -> (active: [Session], ended: [Session]) {
        let all = filteredSessions(store.sessions)
        var active: [Session] = []
        var ended: [Session] = []
        for s in all {
            if s.status == .ended { ended.append(s) } else { active.append(s) }
        }
        ended.sort { a, b in
            let ap = isPinned(a), bp = isPinned(b)
            if ap != bp { return ap && !bp }
            return a.lastEventAt > b.lastEventAt
        }
        return (active, ended)
    }

    private func grouped(_ sessions: [Session]) -> [(key: String, members: [Session])] {
        if sessions.isEmpty { return [] }
        let dict = Dictionary(grouping: sessions, by: { groupKey($0) })

        // Sort groups: those containing any pinned session come first, then alphabetical.
        let sortedGroups = dict.sorted { a, b in
            let aPinned = a.value.contains { isPinned($0) }
            let bPinned = b.value.contains { isPinned($0) }
            if aPinned != bPinned { return aPinned && !bPinned }
            return a.key < b.key
        }

        // Within each group, pinned first then recency-desc.
        return sortedGroups.map { (key, members) in
            let sorted = members.sorted { a, b in
                let ap = isPinned(a), bp = isPinned(b)
                if ap != bp { return ap && !bp }
                return a.lastEventAt > b.lastEventAt
            }
            return (key, sorted)
        }
    }

    private func isPinned(_ s: Session) -> Bool {
        aliases.meta(forWorkKey: s.identity.workKey)?.pinned ?? false
    }

    private func groupKey(_ s: Session) -> String {
        switch groupBy {
        case .cwd:     return s.identity.cwd
        case .gitRepo: return resolver.resolve(cwd: s.identity.cwd,
                                                workKey: s.identity.workKey,
                                                aliasStore: aliases)
        case .color:   return (aliases.meta(forWorkKey: s.identity.workKey)?.color.rawValue ?? "blue")
        case .status:  return s.status.rawValue
        }
    }

    // MARK: Row tap → focus terminal

    private func onRowTap(_ session: Session) async {
        let result = await focuser.focus(session)
        switch result {
        case .precise:
            onDismiss()
        case .activatedAppOnly:
            // The target app was activated — dismiss the popover so it
            // stops holding key-window status, otherwise macOS leaves
            // focus on our popover and the user has to click outside
            // to "complete" the focus switch.
            onDismiss()
        case .noTerminalHint:
            toast = "No terminal info recorded for this session."
            autoDismissToast()
        case .failed(let reason):
            toast = "Focus failed: \(reason)"
            autoDismissToast()
        }
    }

    private func autoDismissToast() {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            toast = nil
        }
    }

    // MARK: Rename modal

    private func presentRenameAlert(for sess: Session) {
        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = "Set an alias for the project at \(sess.identity.cwd)"
        let tf = NSTextField(string: aliases.meta(forWorkKey: sess.identity.workKey)?.alias ?? "")
        tf.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = tf
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = tf.stringValue.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                store.rename(workKey: sess.identity.workKey, to: trimmed)
            }
        }
    }
}

private struct BlinkingCaret: View {
    @State private var visible: Bool = true
    var body: some View {
        Rectangle()
            .fill(Theme.amber)
            .frame(width: 7, height: 14)
            .padding(.leading, 4)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { visible = false }
            }
    }
}
