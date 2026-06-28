import Foundation

public struct UploadError: Error, Equatable {
    public let statusCode: Int
    public init(statusCode: Int) { self.statusCode = statusCode }
}

public protocol ObjectUploader {
    func put(data: Data, to url: URL, contentType: String) async throws
}

public struct URLSessionUploader: ObjectUploader {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func put(data: Data, to url: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UploadError(statusCode: http.statusCode)
        }
    }
}
