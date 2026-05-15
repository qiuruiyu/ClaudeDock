import AppKit

enum StatusIconRenderer {
    static func image(for status: AggregateStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let color: NSColor
            switch status {
            case .red:    color = .systemRed
            case .yellow: color = .systemYellow
            case .green:  color = .systemGreen
            case .gray:   color = NSColor.tertiaryLabelColor
            }
            color.setFill()
            let inset = rect.insetBy(dx: 4, dy: 4)
            NSBezierPath(ovalIn: inset).fill()
            return true
        }
        img.isTemplate = false
        return img
    }
}
