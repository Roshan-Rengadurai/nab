import XCTest
@testable import SnipCore

// Deterministic RNG so we can assert exact slugs.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}

final class KeyGeneratorTests: XCTestCase {
    private func fixedDate() -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: "2026-06-26")!
    }

    func testSlugLengthAndCharset() {
        let gen = KeyGenerator(scheme: NamingScheme(slugLength: 10))
        var rng = SeededRNG(seed: 42)
        let key = gen.makeKey(ext: "png", date: fixedDate(), using: &rng)
        XCTAssertTrue(key.hasSuffix(".png"))
        let slug = key.dropLast(".png".count)
        XCTAssertEqual(slug.count, 10)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        XCTAssertTrue(slug.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func testDeterministicWithSeededRng() {
        let gen = KeyGenerator(scheme: NamingScheme(slugLength: 8))
        var a = SeededRNG(seed: 7)
        var b = SeededRNG(seed: 7)
        XCTAssertEqual(
            gen.makeKey(ext: "png", date: fixedDate(), using: &a),
            gen.makeKey(ext: "png", date: fixedDate(), using: &b)
        )
    }

    func testDatePrefix() {
        let gen = KeyGenerator(scheme: NamingScheme(slugLength: 6, datePrefix: true))
        var rng = SeededRNG(seed: 1)
        let key = gen.makeKey(ext: "txt", date: fixedDate(), using: &rng)
        XCTAssertTrue(key.hasPrefix("2026-06-26-"), "got \(key)")
        XCTAssertTrue(key.hasSuffix(".txt"))
    }
}
