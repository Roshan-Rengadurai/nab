import Foundation

struct UploadRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String
    let key: String
    let byteSize: Int
    let origin: String      // "capture" | "text" | "drop"
    let createdAt: Date

    init(url: String, key: String, byteSize: Int, origin: String) {
        self.id = UUID()
        self.url = url
        self.key = key
        self.byteSize = byteSize
        self.origin = origin
        self.createdAt = Date()
    }
}

/// Local-only upload history (spec §24), persisted as JSON in Application Support.
/// No central record of what anyone shared.
final class UploadHistory: ObservableObject {
    @Published private(set) var records: [UploadRecord] = []
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Snip", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("history.json")
        load()
    }

    func add(url: String, key: String, byteSize: Int, origin: String) {
        records.insert(UploadRecord(url: url, key: key, byteSize: byteSize, origin: origin), at: 0)
        save()
    }

    func delete(_ record: UploadRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([UploadRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
