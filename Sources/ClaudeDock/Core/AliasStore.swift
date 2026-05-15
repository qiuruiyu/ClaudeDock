import Foundation

final class AliasStore {
    private let fileURL: URL
    private var map: [String: WorkKeyMeta]   // workKey → meta

    init(fileURL: URL = PathProvider.aliasesFile) {
        self.fileURL = fileURL
        self.map = Persistence.read([String: WorkKeyMeta].self, from: fileURL) ?? [:]
    }

    func meta(forWorkKey key: String) -> WorkKeyMeta? { map[key] }

    func upsert(workKey: String, alias: String? = nil, color: ColorTag? = nil, pinned: Bool? = nil) {
        var m = map[workKey] ?? WorkKeyMeta(alias: nil, color: .blue, pinned: false, lastSeen: Date())
        if let a = alias  { m.alias = a }
        if let c = color  { m.color = c }
        if let p = pinned { m.pinned = p }
        m.lastSeen = Date()
        map[workKey] = m
    }

    func touch(workKey: String) { upsert(workKey: workKey) }

    func save() throws { try Persistence.write(map, to: fileURL) }

    func allEntries() -> [(workKey: String, meta: WorkKeyMeta)] {
        return map.map { (workKey: $0.key, meta: $0.value) }
                  .sorted { ($0.meta.alias ?? "") < ($1.meta.alias ?? "") }
    }

    func resetAll() {
        map.removeAll()
        try? save()
    }
}
