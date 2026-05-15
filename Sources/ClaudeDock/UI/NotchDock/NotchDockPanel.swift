import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchDockPanel {
    private let controller: NotchDockController
    private let store: SessionStore
    private let panel: NSPanel
    private let hostingView: NSHostingView<NotchDockView>
    private var cancellables = Set<AnyCancellable>()

    init(controller: NotchDockController,
         store: SessionStore,
         aliases: AliasStore,
         focuser: TerminalFocuser) {
        self.controller = controller
        self.store = store
        let view = NotchDockView(controller: controller, store: store,
                                 aliases: aliases, focuser: focuser)
        self.hostingView = NSHostingView(rootView: view)

        self.panel = NSPanel(contentRect: .zero,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hostingView

        controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .hidden:
                    self.panel.orderOut(nil)
                case .showing:
                    self.reposition()
                    self.panel.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)
    }

    private func reposition() {
        guard let screen = NotchGeometry.currentMainScreen() else { return }
        let rect = NotchGeometry.bannerRect(for: screen)
        panel.setFrame(rect, display: true, animate: panel.isVisible)
    }
}
