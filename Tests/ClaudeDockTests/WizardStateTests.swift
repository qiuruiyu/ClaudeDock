import Foundation
import Testing
@testable import ClaudeDock

@Suite @MainActor struct WizardStateTests {
    @Test func startsOnWelcome() {
        let s = WizardState()
        #expect(s.current == .welcome)
    }

    @Test func nextAdvancesSequentially() {
        let s = WizardState()
        s.next()
        #expect(s.current == .plugin)
        s.next()
        #expect(s.current == .notchDock)
        s.next()
        #expect(s.current == .hotkey)
        s.next()
        #expect(s.current == .done)
    }

    @Test func backNeverGoesBeforeWelcome() {
        let s = WizardState()
        s.back()
        #expect(s.current == .welcome)
    }

    @Test func skipJumpsToDone() {
        let s = WizardState()
        s.skip()
        #expect(s.current == .done)
    }
}
