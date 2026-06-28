import Foundation

public protocol StorageProvider {
    /// A presigned PUT URL for uploading bytes under `key`.
    func presignPutURL(key: String, expiresIn: Int, date: Date) throws -> URL
    /// The deterministic public share URL for `key`.
    func publicURL(forKey key: String) -> URL
}
