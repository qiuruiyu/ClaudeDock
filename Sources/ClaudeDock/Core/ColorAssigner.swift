import Foundation

struct ColorAssigner: Sendable {
    private static let palette: [ColorTag] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .teal]

    /// Returns a stable color for a workKey, persisting on first call.
    func color(forWorkKey workKey: String, in store: AliasStore) -> ColorTag {
        if let existing = store.meta(forWorkKey: workKey)?.color { return existing }
        // Hash-based for deterministic distribution across the palette.
        var hash: UInt32 = 5381
        for byte in workKey.utf8 {
            hash = (hash &* 33) &+ UInt32(byte)
        }
        let idx = Int(hash) % Self.palette.count
        let chosen = Self.palette[idx]
        store.upsert(workKey: workKey, color: chosen)
        return chosen
    }
}
