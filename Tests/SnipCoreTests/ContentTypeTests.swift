import XCTest
@testable import SnipCore

final class ContentTypeTests: XCTestCase {
    func testKnownTypes() {
        XCTAssertEqual(ContentType.mime(forExtension: "png"), "image/png")
        XCTAssertEqual(ContentType.mime(forExtension: "jpg"), "image/jpeg")
        XCTAssertEqual(ContentType.mime(forExtension: "txt"), "text/plain; charset=utf-8")
    }

    func testCaseAndLeadingDotInsensitive() {
        XCTAssertEqual(ContentType.mime(forExtension: "PNG"), "image/png")
        XCTAssertEqual(ContentType.mime(forExtension: ".JpEg"), "image/jpeg")
    }

    func testUnknownFallsBackToOctetStream() {
        XCTAssertEqual(ContentType.mime(forExtension: "xyz"), "application/octet-stream")
    }
}
