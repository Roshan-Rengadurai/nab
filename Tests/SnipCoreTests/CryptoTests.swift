import XCTest
@testable import SnipCore

final class CryptoTests: XCTestCase {
    // NIST/standard known answers.
    func testSha256OfEmptyString() {
        XCTAssertEqual(
            sha256Hex(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testSha256OfAbc() {
        XCTAssertEqual(
            sha256Hex("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    // RFC 4231 Test Case 2: key="Jefe", data="what do ya want for nothing?"
    func testHmacSha256Rfc4231Case2() {
        let mac = hmacSHA256(key: Data("Jefe".utf8), "what do ya want for nothing?")
        XCTAssertEqual(
            hexLower(mac),
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
        )
    }
}
