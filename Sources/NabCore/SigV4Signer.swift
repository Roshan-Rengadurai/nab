import Foundation

public struct SigV4Credentials: Equatable {
    public let accessKeyID: String
    public let secretAccessKey: String
    public init(accessKeyID: String, secretAccessKey: String) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
    }
}

public struct SigV4Signer {
    public let credentials: SigV4Credentials
    public let region: String
    public let service: String

    public init(credentials: SigV4Credentials, region: String, service: String = "s3") {
        self.credentials = credentials
        self.region = region
        self.service = service
    }

    /// Produces a presigned URL by adding the X-Amz-* query parameters and the
    /// computed X-Amz-Signature. Signs only the `host` header and uses an
    /// UNSIGNED-PAYLOAD body hash (standard for presigned object URLs).
    public func presign(method: String, url: URL, expiresIn: Int, date: Date) -> URL {
        let amzDate = Self.amzDate(date)
        let dateStamp = Self.dateStamp(date)
        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host else {
            return url
        }
        let hostHeaderValue = Self.hostHeader(comps)
        let encodedPath = Self.uriEncode(comps.path.isEmpty ? "/" : comps.path, encodeSlash: false)
        let canonicalURI = encodedPath

        // Finding 3: Start with any pre-existing query items, then overwrite/add the
        // X-Amz auth params so the computed auth params always win.
        var params: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            params[item.name] = item.value ?? ""
        }
        params["X-Amz-Algorithm"] = "AWS4-HMAC-SHA256"
        params["X-Amz-Credential"] = "\(credentials.accessKeyID)/\(scope)"
        params["X-Amz-Date"] = amzDate
        params["X-Amz-Expires"] = String(expiresIn)
        params["X-Amz-SignedHeaders"] = "host"

        // Finding 2: Encode each key/value first, THEN sort by encoded key (AWS requirement).
        let canonicalQuery = params.keys
            .map { key in
                (Self.uriEncode(key, encodeSlash: true),
                 Self.uriEncode(params[key]!, encodeSlash: true))
            }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")

        let canonicalHeaders = "host:\(hostHeaderValue)\n"
        let signedHeaders = "host"
        let canonicalRequest = [
            method.uppercased(),
            canonicalURI,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            "UNSIGNED-PAYLOAD",
        ].joined(separator: "\n")

        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            scope,
            sha256Hex(canonicalRequest),
        ].joined(separator: "\n")

        let signingKey = Self.signingKey(
            secret: credentials.secretAccessKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = hexLower(hmacSHA256(key: signingKey, stringToSign))

        let scheme = comps.scheme ?? "https"
        let portSuffix = comps.port.map { ":\($0)" } ?? ""
        let finalQuery = canonicalQuery + "&X-Amz-Signature=" + signature
        // Use encodedPath (AWS SigV4 encoding) for both canonical URI and wire URL so
        // they are identical by construction and the signature always matches.
        return URL(string: "\(scheme)://\(host)\(portSuffix)\(encodedPath)?\(finalQuery)")!
    }

    // MARK: - Helpers

    static func hostHeader(_ comps: URLComponents) -> String {
        guard let host = comps.host else { return "" }
        if let port = comps.port { return "\(host):\(port)" }
        return host
    }

    // Finding 4: Static formatters, allocated once, safe to share across calls.
    private static let amzDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f
    }()

    private static let dateStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    static func amzDate(_ date: Date) -> String { amzDateFormatter.string(from: date) }
    static func dateStamp(_ date: Date) -> String { dateStampFormatter.string(from: date) }

    static func signingKey(secret: String, dateStamp: String, region: String, service: String) -> Data {
        let kDate = hmacSHA256(key: Data("AWS4\(secret)".utf8), dateStamp)
        let kRegion = hmacSHA256(key: kDate, region)
        let kService = hmacSHA256(key: kRegion, service)
        return hmacSHA256(key: kService, "aws4_request")
    }

    /// AWS-style RFC 3986 URI encoding. Unreserved characters pass through;
    /// "/" is preserved only when `encodeSlash` is false.
    static func uriEncode(_ s: String, encodeSlash: Bool) -> String {
        var out = ""
        for byte in s.utf8 {
            switch byte {
            case 0x41...0x5A, 0x61...0x7A, 0x30...0x39,
                 0x2D, 0x2E, 0x5F, 0x7E: // - . _ ~
                out.append(Character(UnicodeScalar(byte)))
            case 0x2F: // /
                out += encodeSlash ? "%2F" : "/"
            default:
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }
}
