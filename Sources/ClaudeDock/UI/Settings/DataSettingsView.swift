import SwiftUI
import AppKit

struct DataSettingsView: View {
    @ObservedObject var aliasesObserver: AliasesObserver
    @State private var entries: [DataFolderInspector.Entry] = []
    @State private var lastError: String?

    final class AliasesObserver: ObservableObject {
        let store: AliasStore
        @Published var snapshot: [(workKey: String, meta: WorkKeyMeta)] = []
        init(store: AliasStore) {
            self.store = store
            self.snapshot = store.allEntries()
        }
        func refresh() { snapshot = store.allEntries() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data").font(.system(size: 12, weight: .semibold))

            GroupBox("Application Support folder") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PathProvider.applicationSupportRoot.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if entries.isEmpty {
                        Text("Folder is empty or doesn't exist yet.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            HStack {
                                Image(systemName: entry.kind == .directory ? "folder" : "doc")
                                    .frame(width: 12)
                                Text(entry.relativePath).font(.system(size: 11))
                                Spacer()
                                Text(DataFolderInspector.formattedSize(entry.byteSize))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            if entry.relativePath == "backups" {
                                Text("Empty by design — we never put a settings.json backup here because we never touched settings.json.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.leading, 18)
                            }
                        }
                    }
                    HStack {
                        Button("Reveal in Finder") { revealInFinder() }
                            .controlSize(.small)
                        Button("Refresh") { reload() }
                            .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }

            GroupBox("Aliases") {
                VStack(alignment: .leading, spacing: 4) {
                    if aliasesObserver.snapshot.isEmpty {
                        Text("No aliases set yet. Right-click a session row → Rename to add one.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(aliasesObserver.snapshot, id: \.workKey) { row in
                            HStack {
                                Text(row.meta.alias ?? "—").font(.system(size: 11))
                                Spacer()
                                Text(row.workKey.prefix(12).description)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Reset all aliases & colors") {
                        aliasesObserver.store.resetAll()
                        aliasesObserver.refresh()
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }

            if let e = lastError {
                Text(e).font(.system(size: 10)).foregroundStyle(.orange)
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        do {
            entries = try DataFolderInspector.inspect(at: PathProvider.applicationSupportRoot)
            aliasesObserver.refresh()
        } catch {
            lastError = "Inspect failed: \(error.localizedDescription)"
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([PathProvider.applicationSupportRoot])
    }
}
