import Foundation

/// Uploads bytes to the hosted "Nab hosting" endpoint (the web app's POST
/// /api/upload). The server owns slug + expiry; we just send the image, a
/// license key, and a TTL, and get back the share URLs.
public struct NabHostedUploader {
    public struct Outcome: Equatable {
        public let slug: String
        public let imageURL: URL // direct image, embeds inline in Discord
        public let pageURL: URL  // branded viewer, rich card
        public let expiresAt: Int?
    }

    private struct Response: Decodable {
        let slug: String
        let imageUrl: String
        let pageUrl: String
        let expiresAt: Int?
    }

    private struct ErrorBody: Decodable { let error: String? }

    public let apiBase: URL
    private let session: URLSession

    public init(apiBase: URL, session: URLSession = .shared) {
        self.apiBase = apiBase
        self.session = session
    }

    /// POST the bytes. `ttlSeconds` 0 = never expires.
    public func upload(
        data: Data,
        contentType: String,
        ttlSeconds: Int,
        licenseKey: String
    ) async throws -> Outcome {
        var req = URLRequest(url: apiBase.appendingPathComponent("api/upload"))
        req.httpMethod = "POST"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue(licenseKey, forHTTPHeaderField: "x-nab-key")
        req.setValue(String(ttlSeconds), forHTTPHeaderField: "x-nab-ttl")

        let (respData, resp) = try await session.upload(for: req, from: data)
        guard let http = resp as? HTTPURLResponse else {
            throw UploadError(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UploadError(statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: respData)
        guard let img = URL(string: decoded.imageUrl),
              let page = URL(string: decoded.pageUrl) else {
            throw UploadError(statusCode: -2)
        }
        return Outcome(slug: decoded.slug, imageURL: img, pageURL: page,
                       expiresAt: decoded.expiresAt)
    }
}
