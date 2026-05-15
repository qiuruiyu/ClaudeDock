import AppKit

enum NotchGeometry {
    struct ScreenInfo {
        let frame: NSRect
        let visibleFrame: NSRect    // excludes menu bar + dock
        let safeAreaTop: CGFloat    // > 0 only on notched Macs
    }

    static func currentMainScreen() -> ScreenInfo? {
        guard let s = NSScreen.main else { return nil }
        return ScreenInfo(
            frame: s.frame,
            visibleFrame: s.visibleFrame,
            safeAreaTop: s.safeAreaInsets.top)
    }

    /// Banner dimensions: 360 wide × 56 tall, clamped to screen width.
    static let bannerSize = NSSize(width: 360, height: 56)
    static let bannerMaxWidth: CGFloat = 480
    static let bannerMinWidth: CGFloat = 300

    static func bannerRect(for s: ScreenInfo) -> NSRect {
        // Width: prefer 360, clamp to [min, screenWidth].
        let width = min(bannerMaxWidth, max(bannerMinWidth, min(bannerSize.width, s.frame.width)))
        // Top y: notched → frame.maxY - safeAreaTop (tucks under notch).
        //        non-notched → visibleFrame.maxY (sits below menu bar — fixes v1.0 overlap).
        let topY: CGFloat
        if s.safeAreaTop > 0 {
            topY = s.frame.maxY - s.safeAreaTop
        } else {
            topY = s.visibleFrame.maxY
        }
        return NSRect(
            x: s.frame.midX - width / 2,
            y: topY - bannerSize.height,
            width: width,
            height: bannerSize.height)
    }
}
