import XCTest
@testable import SnipCore

final class SigV4SignerTests: XCTestCase {
    private func fixedDate(_ amz: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.date(from: amz)!
    }

    // AWS documented presigned-GET example. Signing is method-agnostic, so a
    // correct GET signature proves the algorithm we reuse for PUT.
    func testMatchesAwsDocumentedExample() {
        let creds = SigV4Credentials(
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )
        let signer = SigV4Signer(credentials: creds, region: "us-east-1", service: "s3")
        let url = URL(string: "https://examplebucket.s3.amazonaws.com/test.txt")!

        let signed = signer.presign(
            method: "GET",
            url: url,
            expiresIn: 86400,
            date: fixedDate("20130524T000000Z")
        )

        let comps = URLComponents(url: signed, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues: comps.queryItems!.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(items["X-Amz-Algorithm"], "AWS4-HMAC-SHA256")
        XCTAssertEqual(items["X-Amz-Date"], "20130524T000000Z")
        XCTAssertEqual(items["X-Amz-Expires"], "86400")
        XCTAssertEqual(items["X-Amz-SignedHeaders"], "host")
        XCTAssertEqual(
            items["X-Amz-Credential"],
            "AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request"
        )
        XCTAssertEqual(
            items["X-Amz-Signature"],
            "aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"
        )
    }

    // Finding 1 regression: keys with spaces/Unicode must not crash and must stay percent-encoded.
    func testPresignEncodesKeyWithSpace() {
        let creds = SigV4Credentials(accessKeyID: "AKIDEXAMPLE", secretAccessKey: "SECRETKEY")
        let signer = SigV4Signer(credentials: creds, region: "auto", service: "s3")

        // Build a URL whose path contains a space via URLComponents (path is decoded).
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "acct.r2.cloudflarestorage.com"
        comps.path = "/bucket/my photo.jpg"
        let inputURL = comps.url!

        let signed = signer.presign(
            method: "PUT",
            url: inputURL,
            expiresIn: 300,
            date: fixedDate("20260101T120000Z")
        )

        // Must not crash (non-nil) and the space must be percent-encoded in the output.
        XCTAssertTrue(signed.absoluteString.contains("my%20photo.jpg"),
                      "Space in object key must be percent-encoded, got: \(signed.absoluteString)")
    }

    func testPutSignatureIsDeterministicAndAppended() {
        let creds = SigV4Credentials(accessKeyID: "AKIDEXAMPLE", secretAccessKey: "SECRETKEY")
        let signer = SigV4Signer(credentials: creds, region: "auto", service: "s3")
        let url = URL(string: "https://acct.r2.cloudflarestorage.com/bucket/ab12cd34ef.png")!

        let a = signer.presign(method: "PUT", url: url, expiresIn: 300, date: fixedDate("20260101T120000Z"))
        let b = signer.presign(method: "PUT", url: url, expiresIn: 300, date: fixedDate("20260101T120000Z"))
        XCTAssertEqual(a, b, "Same inputs must yield the same signed URL")
        XCTAssertTrue(a.absoluteString.contains("X-Amz-Signature="))
        XCTAssertEqual(a.path, "/bucket/ab12cd34ef.png", "Object path must be preserved")
    }
}
