import Foundation

public enum ProviderKind: String, Equatable {
    case r2, s3, b2, minio, s3compat
}

public struct ProviderConfig: Equatable {
    public let id: String
    public let kind: ProviderKind
    public let endpoint: URL      // service endpoint base, e.g. https://acct.r2.cloudflarestorage.com
    public let region: String
    public let bucket: String
    public let pathStyle: Bool    // true for R2/MinIO/B2; false (virtual-host) for AWS S3
    public let publicBase: URL?   // optional custom domain / public bucket base for link gen

    public init(id: String, kind: ProviderKind, endpoint: URL, region: String,
                bucket: String, pathStyle: Bool, publicBase: URL?) {
        self.id = id
        self.kind = kind
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.pathStyle = pathStyle
        self.publicBase = publicBase
    }
}
