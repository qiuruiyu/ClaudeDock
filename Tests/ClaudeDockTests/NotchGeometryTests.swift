import AppKit
import Testing
@testable import ClaudeDock

@Suite struct NotchGeometryTests {
    @Test func notchedMacAnchorsBelowSafeArea() {
        let screen = NotchGeometry.ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 950),
            safeAreaTop: 32)
        let rect = NotchGeometry.bannerRect(for: screen)
        #expect(abs(rect.midX - screen.frame.midX) < 1)
        let expectedTop = screen.frame.maxY - screen.safeAreaTop
        #expect(abs(rect.maxY - expectedTop) < 1)
    }

    @Test func notchlessMacAnchorsBelowMenuBar() {
        // Non-notched Mac: safeAreaTop is 0, but visibleFrame excludes the menu bar.
        // Banner must sit at visibleFrame.maxY (below menu bar), NOT frame.maxY
        // (which would overlap the menu bar — the v1.0 bug).
        let screen = NotchGeometry.ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 876),
            safeAreaTop: 0)
        let rect = NotchGeometry.bannerRect(for: screen)
        #expect(abs(rect.maxY - screen.visibleFrame.maxY) < 1)
        #expect(rect.maxY < screen.frame.maxY,
                "must NOT overlap the menu bar")
    }

    @Test func bannerWidthIsBounded() {
        let narrow = NotchGeometry.ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 380, height: 700),
            visibleFrame: NSRect(x: 0, y: 0, width: 380, height: 676),
            safeAreaTop: 0)
        let narrowRect = NotchGeometry.bannerRect(for: narrow)
        #expect(narrowRect.width <= narrow.frame.width)
        #expect(narrowRect.width >= 300)

        let wide = NotchGeometry.ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 5120, height: 2160),
            visibleFrame: NSRect(x: 0, y: 0, width: 5120, height: 2136),
            safeAreaTop: 0)
        let wideRect = NotchGeometry.bannerRect(for: wide)
        #expect(wideRect.width <= 480)
    }
}
