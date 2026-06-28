import Foundation

public enum UploadOrigin: Equatable {
    case capture, drop, text
}

public struct UploadItem {
    public let data: Data
    public let fileExtension: String
    public let origin: UploadOrigin
    public let isBurner: Bool

    public init(data: Data, fileExtension: String, origin: UploadOrigin, isBurner: Bool) {
        self.data = data
        self.fileExtension = fileExtension
        self.origin = origin
        self.isBurner = isBurner
    }
}

public struct UploadOutcome: Equatable {
    public let key: String
    public let url: URL
    public let copiedOptimistically: Bool
    public let verified: Bool

    public init(key: String, url: URL, copiedOptimistically: Bool, verified: Bool) {
        self.key = key
        self.url = url
        self.copiedOptimistically = copiedOptimistically
        self.verified = verified
    }
}
