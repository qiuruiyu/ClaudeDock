// Sources/ClaudeDock/App/main.swift
import AppKit

LogBootstrap.configure()

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // LSUIElement: no Dock icon
    app.run()
}
