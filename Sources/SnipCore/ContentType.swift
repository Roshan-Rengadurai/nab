import Foundation

public enum ContentType {
    private static let table: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "heic": "image/heic",
        "webp": "image/webp",
        "gif": "image/gif",
        "txt": "text/plain; charset=utf-8",
        "pdf": "application/pdf",
        "zip": "application/zip",
    ]

    public static func mime(forExtension ext: String) -> String {
        let key = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return table[key] ?? "application/octet-stream"
    }
}
