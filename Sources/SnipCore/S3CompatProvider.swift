import Foundation

public struct S3CompatProvider: StorageProvider {
    public let config: ProviderConfig
    private let signer: SigV4Signer

    public init(config: ProviderConfig, credentials: SigV4Credentials) {
        self.config = config
        self.signer = SigV4Signer(credentials: credentials, region: config.region, service: "s3")
    }

    /// The actual request URL the client signs and PUTs to.
    public func objectURL(forKey key: String) -> URL {
        var comps = URLComponents(url: config.endpoint, resolvingAgainstBaseURL: false)!
        if config.pathStyle {
            comps.path = "/\(config.bucket)/\(key)"
        } else {
            comps.host = "\(config.bucket).\(comps.host ?? "")"
            comps.path = "/\(key)"
        }
        return comps.url!
    }

    public func publicURL(forKey key: String) -> URL {
        if let base = config.publicBase {
            return base.appendingPathComponent(key)
        }
        return objectURL(forKey: key)
    }

    public func presignPutURL(key: String, expiresIn: Int, date: Date) throws -> URL {
        signer.presign(method: "PUT", url: objectURL(forKey: key), expiresIn: expiresIn, date: date)
    }
}
