import XCTest
@testable import SnipCore

final class S3CompatProviderTests: XCTestCase {
    private let creds = SigV4Credentials(accessKeyID: "AKIDEXAMPLE", secretAccessKey: "SECRET")

    private func fixedDate() -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.date(from: "20260101T000000Z")!
    }

    func testPathStyleObjectURL() {
        let config = ProviderConfig(
            id: "p1", kind: .r2,
            endpoint: URL(string: "https://acct.r2.cloudflarestorage.com")!,
            region: "auto", bucket: "shots", pathStyle: true, publicBase: nil
        )
        let provider = S3CompatProvider(config: config, credentials: creds)
        XCTAssertEqual(
            provider.objectURL(forKey: "ab12cd.png").absoluteString,
            "https://acct.r2.cloudflarestorage.com/shots/ab12cd.png"
        )
    }

    func testVirtualHostObjectURL() {
        let config = ProviderConfig(
            id: "p2", kind: .s3,
            endpoint: URL(string: "https://s3.us-east-1.amazonaws.com")!,
            region: "us-east-1", bucket: "shots", pathStyle: false, publicBase: nil
        )
        let provider = S3CompatProvider(config: config, credentials: creds)
        XCTAssertEqual(
            provider.objectURL(forKey: "ab12cd.png").absoluteString,
            "https://shots.s3.us-east-1.amazonaws.com/ab12cd.png"
        )
    }

    func testPublicURLUsesCustomBaseWhenSet() {
        let config = ProviderConfig(
            id: "p3", kind: .r2,
            endpoint: URL(string: "https://acct.r2.cloudflarestorage.com")!,
            region: "auto", bucket: "shots", pathStyle: true,
            publicBase: URL(string: "https://cdn.example.com")!
        )
        let provider = S3CompatProvider(config: config, credentials: creds)
        XCTAssertEqual(
            provider.publicURL(forKey: "ab12cd.png").absoluteString,
            "https://cdn.example.com/ab12cd.png"
        )
    }

    func testPublicURLFallsBackToObjectURL() {
        let config = ProviderConfig(
            id: "p4", kind: .r2,
            endpoint: URL(string: "https://acct.r2.cloudflarestorage.com")!,
            region: "auto", bucket: "shots", pathStyle: true, publicBase: nil
        )
        let provider = S3CompatProvider(config: config, credentials: creds)
        XCTAssertEqual(provider.publicURL(forKey: "k.png"), provider.objectURL(forKey: "k.png"))
    }

    func testPresignPutProducesSignedPutURL() throws {
        let config = ProviderConfig(
            id: "p5", kind: .r2,
            endpoint: URL(string: "https://acct.r2.cloudflarestorage.com")!,
            region: "auto", bucket: "shots", pathStyle: true, publicBase: nil
        )
        let provider = S3CompatProvider(config: config, credentials: creds)
        let url = try provider.presignPutURL(key: "ab12cd.png", expiresIn: 300, date: fixedDate())
        XCTAssertEqual(url.path, "/shots/ab12cd.png")
        XCTAssertTrue(url.absoluteString.contains("X-Amz-Signature="))
        XCTAssertTrue(url.absoluteString.contains("X-Amz-Expires=300"))
    }
}
