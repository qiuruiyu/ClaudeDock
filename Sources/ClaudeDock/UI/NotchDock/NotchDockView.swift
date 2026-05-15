import SwiftUI
import AppKit

struct NotchDockView: View {
    @ObservedObject var controller: NotchDockController
    @ObservedObject var store: SessionStore
    let aliases: AliasStore
    let focuser: TerminalFocuser
    private let resolver = NameResolver()

    var body: some View {
        Group {
            if case .showing(let s, _) = controller.state {
                bannerContent(for: s)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { _ = await focuser.focus(s) }
                        controller.userClickedBanner()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Pure ink background — matches the popover's identity. Solid color
        // (not NSVisualEffectView material) so the banner always renders the
        // same regardless of wallpaper. On notched Macs this still tucks
        // invisibly under the physical notch (both are black).
        .background(Theme.ink)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 0
            )
        )
        .animation(.easeInOut(duration: 0.22), value: stateKey)
    }

    /// Stable identity for animation triggers — avoids re-triggering on the
    /// per-render `until:` timestamp inside .showing.
    private var stateKey: String {
        switch controller.state {
        case .hidden: return "hidden"
        case .showing(let s, _): return "showing-\(s.id)"
        }
    }

    private func bannerContent(for s: Session) -> some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Theme.color(for: s.status))
                .frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name(for: s))
                        .font(Theme.mono(13, weight: .medium))
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    if let idx = s.sameCwdIndex {
                        Text("·\(idx)")
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.creamDim)
                    }
                }
                Text(Theme.statusLabel(for: s.status).uppercased())
                    .font(Theme.mono(9, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(Theme.color(for: s.status))
            }
            Spacer()
            Text("›")
                .font(Theme.mono(13, weight: .medium))
                .foregroundStyle(Theme.amber)
        }
    }

    private func name(for s: Session) -> String {
        resolver.resolve(cwd: s.identity.cwd,
                         workKey: s.identity.workKey,
                         aliasStore: aliases)
    }
}
