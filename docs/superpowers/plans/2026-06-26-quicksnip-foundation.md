# QuickSnip Foundation (M0 + M1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the menubar-resident skeleton and the screenshot-to-clipboard upload core: press a hotkey, capture a region, get a clean URL pointing at your own S3-compatible bucket on the clipboard ~instantly.

**Architecture:** A Swift Package with two targets — `QuickSnipCore` (a pure, fully unit-tested library holding all signing/keygen/URL/pipeline logic) and `QuickSnip` (a thin macOS executable that runs as a menubar agent and wires Core to AppKit). The client signs presigned PUT URLs locally with hand-rolled AWS Signature V4 and uploads bytes directly to the user's bucket — no server in the hot path. The shareable URL is deterministic from the object key, so it is copied to the clipboard before the upload finishes.

**Tech Stack:** Swift 5.9, macOS 13+ (Ventura), Swift Package Manager, AppKit (`NSStatusItem`, `NSPanel`, `NSPasteboard`), Foundation (`URLSession`, `Process`), CryptoKit (SHA-256 / HMAC), KeyboardShortcuts (Sindre Sorhus) for global hotkeys, XCTest.

## Global Constraints

- **Platform:** macOS 13 Ventura or newer. `Package.swift` declares `platforms: [.macOS(.v13)]`. Verbatim from spec §9.
- **Language:** Swift 5.9+. Verbatim from spec §9.
- **No vendor server in the hot path.** The client talks directly to the user's bucket; presigning is local using credentials from Keychain. Verbatim from spec §8, §54.
- **SigV4 is hand-rolled** (~150 lines), not Soto. Verbatim from spec §9, §27, and the user's decision for this plan.
- **Menubar agent, no dock icon** by default — achieved at runtime via `NSApp.setActivationPolicy(.accessory)` (the runtime equivalent of `LSUIElement`). Spec §11.
- **Secrets only in Keychain** — never in SQLite, UserDefaults, or logs. Spec §21, §9.
- **Objects are public-unlisted with unguessable keys** — random base62 slug, ≥ 48 bits entropy (default length 10). Spec §18, §29.
- **Deterministic URL → optimistic clipboard:** copy the link the instant the key is chosen, for normal captures; wait for upload verification for files > 5 MB and all burner uploads. Spec §6 ("optimistic-clipboard correctness guard").

**Out of scope for this plan (later milestones):** SQLite/GRDB history (M2), offline queue/retry/background URLSession (M2), drag-drop (M2), R2 setup wizard + Preferences UI + config validator + lifecycle expiry (M3), the text-highlight gesture (M4), the Worker module (M5). The `StorageProvider` protocol here is intentionally minimal (`presignPutURL` + `publicURL`); `deleteObject`/`validateConfig` from spec §33 are added in M2/M3.

---

## File Structure

```
Package.swift
Sources/
  QuickSnipCore/
    Crypto.swift                 # SHA-256 / HMAC-SHA256 / hex over CryptoKit
    SigV4Signer.swift            # AWS Signature V4 presigned-URL generation
    ContentType.swift            # file-extension → MIME mapping
    KeyGenerator.swift           # random base62 object-key generation
    ProviderConfig.swift         # storage target config (non-secret fields)
    StorageProvider.swift        # protocol + SigV4Credentials
    S3CompatProvider.swift       # objectURL / publicURL / presignPutURL
    ObjectUploader.swift         # protocol + URLSession PUT implementation
    ClipboardWriter.swift        # NSPasteboard write w/ transient marker
    UploadItem.swift             # pipeline input/output models
    UploadPipeline.swift         # keygen → optimistic copy → presign → PUT → verify
    KeychainStore.swift          # credential storage in macOS Keychain
    CaptureCommand.swift         # builds `screencapture` argument vectors (pure)
  QuickSnip/
    main.swift                   # entry point
    AppDelegate.swift            # lifecycle, accessory policy, wiring
    MenuBarController.swift      # NSStatusItem + NSMenu
    ToastController.swift        # borderless non-activating NSPanel HUD
    CaptureService.swift         # runs CaptureCommand via Process
    HotkeyManager.swift          # KeyboardShortcuts registration
    DevConfig.swift              # throwaway env-var config for the e2e smoke test
Tests/
  QuickSnipCoreTests/
    CryptoTests.swift
    SigV4SignerTests.swift
    ContentTypeTests.swift
    KeyGeneratorTests.swift
    S3CompatProviderTests.swift
    ObjectUploaderTests.swift
    ClipboardWriterTests.swift
    UploadPipelineTests.swift
    KeychainStoreTests.swift
    CaptureCommandTests.swift
```

Responsibility split: everything that can be a pure function or is testable without the app lifecycle lives in `QuickSnipCore` and gets real XCTest coverage. The `QuickSnip` executable holds only `NSApplication` lifecycle, the status item, the toast panel, the capture `Process` runner, and hotkey registration — verified by build + manual smoke test, since these are OS-integration shells with no meaningful pure logic.

---

## Task 1: Project skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/QuickSnipCore/Crypto.swift` (placeholder marker only this task)
- Create: `Sources/QuickSnip/main.swift` (minimal, replaced in Task 11)
- Test: `Tests/QuickSnipCoreTests/CryptoTests.swift` (smoke test only this task)

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable SPM package with library target `QuickSnipCore`, executable target `QuickSnip`, test target `QuickSnipCoreTests`, and the `KeyboardShortcuts` dependency available to `QuickSnip`.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/CryptoTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

final class CryptoTests: XCTestCase {
    func testPackageBuildsAndImports() {
        XCTAssertTrue(QuickSnipCore.packageIsWired)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CryptoTests/testPackageBuildsAndImports`
Expected: FAIL — compile error, `QuickSnipCore` has no member `packageIsWired` (and no `Package.swift` yet).

- [ ] **Step 3: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickSnip",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "QuickSnip", targets: ["QuickSnip"]),
        .library(name: "QuickSnipCore", targets: ["QuickSnipCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.1"),
    ],
    targets: [
        .target(name: "QuickSnipCore"),
        .executableTarget(
            name: "QuickSnip",
            dependencies: [
                "QuickSnipCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .testTarget(name: "QuickSnipCoreTests", dependencies: ["QuickSnipCore"]),
    ]
)
```

- [ ] **Step 4: Create the placeholder source files**

`Sources/QuickSnipCore/Crypto.swift`:

```swift
import Foundation

/// Marker used by the package smoke test in Task 1. Real crypto lands in Task 2.
public enum QuickSnipCore {
    public static let packageIsWired = true
}
```

`Sources/QuickSnip/main.swift`:

```swift
// Replaced in Task 11 with the real menubar app entry point.
print("QuickSnip skeleton")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter CryptoTests/testPackageBuildsAndImports`
Expected: PASS. (First run resolves the KeyboardShortcuts dependency — allow network time.)

- [ ] **Step 6: Commit**

```bash
git init
git add Package.swift Sources Tests
git commit -m "chore: scaffold QuickSnip SPM package (Core + executable + tests)"
```

---

## Task 2: Crypto primitives

**Files:**
- Modify: `Sources/QuickSnipCore/Crypto.swift`
- Test: `Tests/QuickSnipCoreTests/CryptoTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `func sha256Hex(_ data: Data) -> String`
  - `func sha256Hex(_ string: String) -> String`
  - `func hmacSHA256(key: Data, _ data: Data) -> Data`
  - `func hmacSHA256(key: Data, _ string: String) -> Data`
  - `func hexLower(_ data: Data) -> String`
  All are free functions in `QuickSnipCore`. Used by Task 3.

- [ ] **Step 1: Write the failing test**

Replace the contents of `Tests/QuickSnipCoreTests/CryptoTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CryptoTests`
Expected: FAIL — `sha256Hex`, `hmacSHA256`, `hexLower` are not defined.

- [ ] **Step 3: Implement the crypto primitives**

Replace the contents of `Sources/QuickSnipCore/Crypto.swift`:

```swift
import Foundation
import CryptoKit

/// Marker used by the package smoke test in Task 1.
public enum QuickSnipCore {
    public static let packageIsWired = true
}

/// Lowercase hex encoding of raw bytes.
public func hexLower(_ data: Data) -> String {
    let table = Array("0123456789abcdef".utf8)
    var out = [UInt8]()
    out.reserveCapacity(data.count * 2)
    for byte in data {
        out.append(table[Int(byte >> 4)])
        out.append(table[Int(byte & 0x0f)])
    }
    return String(decoding: out, as: UTF8.self)
}

public func sha256Hex(_ data: Data) -> String {
    hexLower(Data(SHA256.hash(data: data)))
}

public func sha256Hex(_ string: String) -> String {
    sha256Hex(Data(string.utf8))
}

public func hmacSHA256(key: Data, _ data: Data) -> Data {
    let mac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
    return Data(mac)
}

public func hmacSHA256(key: Data, _ string: String) -> Data {
    hmacSHA256(key: key, Data(string.utf8))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CryptoTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/Crypto.swift Tests/QuickSnipCoreTests/CryptoTests.swift
git commit -m "feat: SHA-256 / HMAC-SHA256 / hex primitives over CryptoKit"
```

---

## Task 3: SigV4 presigned-URL signer

**Files:**
- Create: `Sources/QuickSnipCore/SigV4Signer.swift`
- Test: `Tests/QuickSnipCoreTests/SigV4SignerTests.swift`

**Interfaces:**
- Consumes: `sha256Hex`, `hmacSHA256`, `hexLower` (Task 2).
- Produces:
  - `struct SigV4Credentials { let accessKeyID: String; let secretAccessKey: String }`
  - `struct SigV4Signer { init(credentials:region:service:); func presign(method:url:expiresIn:date:) -> URL }`
  - `service` defaults to `"s3"`. `presign` adds the `X-Amz-*` query params (signed-headers = `host`, payload = `UNSIGNED-PAYLOAD`) and appends `X-Amz-Signature`. Used by Task 6.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/SigV4SignerTests.swift`. The golden value is AWS's own documented example from "Authenticating Requests: Using Query Parameters (AWS Signature Version 4)":

```swift
import XCTest
@testable import QuickSnipCore

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SigV4SignerTests`
Expected: FAIL — `SigV4Signer` / `SigV4Credentials` are not defined.

- [ ] **Step 3: Implement the signer**

`Sources/QuickSnipCore/SigV4Signer.swift`:

```swift
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
        let canonicalURI = Self.uriEncode(comps.percentEncodedPath.isEmpty ? "/" : comps.path, encodeSlash: false)

        // Collect existing query items + the X-Amz auth params.
        var params: [String: String] = [
            "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
            "X-Amz-Credential": "\(credentials.accessKeyID)/\(scope)",
            "X-Amz-Date": amzDate,
            "X-Amz-Expires": String(expiresIn),
            "X-Amz-SignedHeaders": "host",
        ]
        for item in comps.queryItems ?? [] {
            params[item.name] = item.value ?? ""
        }

        let canonicalQuery = params.keys.sorted().map { key in
            "\(Self.uriEncode(key, encodeSlash: true))=\(Self.uriEncode(params[key]!, encodeSlash: true))"
        }.joined(separator: "&")

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
        return URL(string: "\(scheme)://\(host)\(portSuffix)\(comps.path)?\(finalQuery)")!
    }

    // MARK: - Helpers

    static func hostHeader(_ comps: URLComponents) -> String {
        guard let host = comps.host else { return "" }
        if let port = comps.port { return "\(host):\(port)" }
        return host
    }

    static func amzDate(_ date: Date) -> String { formatter("yyyyMMdd'T'HHmmss'Z'").string(from: date) }
    static func dateStamp(_ date: Date) -> String { formatter("yyyyMMdd").string(from: date) }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SigV4SignerTests`
Expected: PASS (2 tests). The `testMatchesAwsDocumentedExample` signature assertion is the proof of correctness.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/SigV4Signer.swift Tests/QuickSnipCoreTests/SigV4SignerTests.swift
git commit -m "feat: hand-rolled AWS SigV4 presigned-URL signer"
```

---

## Task 4: Content-type mapping

**Files:**
- Create: `Sources/QuickSnipCore/ContentType.swift`
- Test: `Tests/QuickSnipCoreTests/ContentTypeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum ContentType { static func mime(forExtension ext: String) -> String }`. Returns `"application/octet-stream"` for unknown extensions. Used by Tasks 9 and 16.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/ContentTypeTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

final class ContentTypeTests: XCTestCase {
    func testKnownTypes() {
        XCTAssertEqual(ContentType.mime(forExtension: "png"), "image/png")
        XCTAssertEqual(ContentType.mime(forExtension: "jpg"), "image/jpeg")
        XCTAssertEqual(ContentType.mime(forExtension: "txt"), "text/plain; charset=utf-8")
    }

    func testCaseAndLeadingDotInsensitive() {
        XCTAssertEqual(ContentType.mime(forExtension: ".PNG"), "image/png")
    }

    func testUnknownFallsBackToOctetStream() {
        XCTAssertEqual(ContentType.mime(forExtension: "xyz"), "application/octet-stream")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ContentTypeTests`
Expected: FAIL — `ContentType` is not defined.

- [ ] **Step 3: Implement the mapping**

`Sources/QuickSnipCore/ContentType.swift`:

```swift
import Foundation

public enum ContentType {
    private static let table: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "heic": "image/heic",
        "webp": "image/webp",
        "gif": "image/gif",
        "txt": "text/plain; charset=utf-8",
        "pdf": "application/pdf",
        "zip": "application/zip",
    ]

    public static func mime(forExtension ext: String) -> String {
        let key = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return table[key] ?? "application/octet-stream"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ContentTypeTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/ContentType.swift Tests/QuickSnipCoreTests/ContentTypeTests.swift
git commit -m "feat: file-extension to MIME content-type mapping"
```

---

## Task 5: Object-key generator

**Files:**
- Create: `Sources/QuickSnipCore/KeyGenerator.swift`
- Test: `Tests/QuickSnipCoreTests/KeyGeneratorTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct NamingScheme { var slugLength: Int; var datePrefix: Bool; init(slugLength: Int = 10, datePrefix: Bool = false) }`
  - `struct KeyGenerator { let scheme: NamingScheme; func makeKey(ext: String, date: Date, using rng: inout some RandomNumberGenerator) -> String }`
  - Slug is base62 (`A–Z a–z 0–9`). With `datePrefix`, key is `yyyy-MM-dd-<slug>.<ext>`. Used by Tasks 9 and 16.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/KeyGeneratorTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeyGeneratorTests`
Expected: FAIL — `KeyGenerator` / `NamingScheme` not defined.

- [ ] **Step 3: Implement the generator**

`Sources/QuickSnipCore/KeyGenerator.swift`:

```swift
import Foundation

public struct NamingScheme: Equatable {
    public var slugLength: Int
    public var datePrefix: Bool
    public init(slugLength: Int = 10, datePrefix: Bool = false) {
        self.slugLength = slugLength
        self.datePrefix = datePrefix
    }
}

public struct KeyGenerator {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    public let scheme: NamingScheme

    public init(scheme: NamingScheme) {
        self.scheme = scheme
    }

    public func makeKey(ext: String, date: Date = Date(), using rng: inout some RandomNumberGenerator) -> String {
        var slug = ""
        slug.reserveCapacity(scheme.slugLength)
        for _ in 0..<scheme.slugLength {
            let idx = Int.random(in: 0..<Self.alphabet.count, using: &rng)
            slug.append(Self.alphabet[idx])
        }
        let cleanExt = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let suffix = cleanExt.isEmpty ? "" : ".\(cleanExt)"
        if scheme.datePrefix {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd"
            return "\(f.string(from: date))-\(slug)\(suffix)"
        }
        return "\(slug)\(suffix)"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeyGeneratorTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/KeyGenerator.swift Tests/QuickSnipCoreTests/KeyGeneratorTests.swift
git commit -m "feat: unguessable base62 object-key generator"
```

---

## Task 6: Provider config + S3-compatible provider

**Files:**
- Create: `Sources/QuickSnipCore/ProviderConfig.swift`
- Create: `Sources/QuickSnipCore/StorageProvider.swift`
- Create: `Sources/QuickSnipCore/S3CompatProvider.swift`
- Test: `Tests/QuickSnipCoreTests/S3CompatProviderTests.swift`

**Interfaces:**
- Consumes: `SigV4Signer`, `SigV4Credentials` (Task 3).
- Produces:
  - `enum ProviderKind: String { case r2, s3, b2, minio, s3compat }`
  - `struct ProviderConfig { let id, kind, endpoint, region, bucket, pathStyle, publicBase }`
  - `protocol StorageProvider { func presignPutURL(key: String, expiresIn: Int, date: Date) throws -> URL; func publicURL(forKey key: String) -> URL }`
  - `struct S3CompatProvider: StorageProvider { init(config:credentials:); func objectURL(forKey:) -> URL }`
  - Used by Tasks 9 and 16.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/S3CompatProviderTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter S3CompatProviderTests`
Expected: FAIL — `ProviderConfig` / `S3CompatProvider` / `StorageProvider` not defined.

- [ ] **Step 3: Implement config, protocol, and provider**

`Sources/QuickSnipCore/ProviderConfig.swift`:

```swift
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
```

`Sources/QuickSnipCore/StorageProvider.swift`:

```swift
import Foundation

public protocol StorageProvider {
    /// A presigned PUT URL for uploading bytes under `key`.
    func presignPutURL(key: String, expiresIn: Int, date: Date) throws -> URL
    /// The deterministic public share URL for `key`.
    func publicURL(forKey key: String) -> URL
}
```

`Sources/QuickSnipCore/S3CompatProvider.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter S3CompatProviderTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/ProviderConfig.swift Sources/QuickSnipCore/StorageProvider.swift Sources/QuickSnipCore/S3CompatProvider.swift Tests/QuickSnipCoreTests/S3CompatProviderTests.swift
git commit -m "feat: S3-compatible provider with deterministic object/public URLs"
```

---

## Task 7: Object uploader (URLSession PUT)

**Files:**
- Create: `Sources/QuickSnipCore/ObjectUploader.swift`
- Test: `Tests/QuickSnipCoreTests/ObjectUploaderTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `protocol ObjectUploader { func put(data: Data, to url: URL, contentType: String) async throws }`
  - `struct UploadError: Error { let statusCode: Int }`
  - `struct URLSessionUploader: ObjectUploader { init(session: URLSession = .shared) }`
  - Real impl issues an HTTP PUT with the `Content-Type` header and throws `UploadError` on non-2xx. Used by Task 9 (via the protocol) and Task 16 (real impl).

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/ObjectUploaderTests.swift` — uses a `URLProtocol` stub so no network is touched:

```swift
import XCTest
@testable import QuickSnipCore

final class StubURLProtocol: URLProtocol {
    static var lastRequest: URLRequest?
    static var lastBody: Data?
    static var responseStatus = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request
        StubURLProtocol.lastBody = request.httpBody
            ?? request.httpBodyStream.map { stream in
                stream.open(); defer { stream.close() }
                var data = Data()
                let size = 4096
                var buf = [UInt8](repeating: 0, count: size)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buf, maxLength: size)
                    if read <= 0 { break }
                    data.append(buf, count: read)
                }
                return data
            }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: StubURLProtocol.responseStatus,
            httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ObjectUploaderTests: XCTestCase {
    private func makeUploader() -> URLSessionUploader {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSessionUploader(session: URLSession(configuration: config))
    }

    override func setUp() {
        StubURLProtocol.lastRequest = nil
        StubURLProtocol.lastBody = nil
        StubURLProtocol.responseStatus = 200
    }

    func testPutSendsMethodHeaderAndBody() async throws {
        let uploader = makeUploader()
        let url = URL(string: "https://example.com/k.png")!
        try await uploader.put(data: Data("hello".utf8), to: url, contentType: "image/png")

        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(
            StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "image/png"
        )
        XCTAssertEqual(StubURLProtocol.lastBody, Data("hello".utf8))
    }

    func testNon2xxThrows() async {
        StubURLProtocol.responseStatus = 403
        let uploader = makeUploader()
        do {
            try await uploader.put(data: Data("x".utf8), to: URL(string: "https://example.com/k")!, contentType: "text/plain")
            XCTFail("Expected UploadError")
        } catch let error as UploadError {
            XCTAssertEqual(error.statusCode, 403)
        } catch {
            XCTFail("Expected UploadError, got \(error)")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ObjectUploaderTests`
Expected: FAIL — `URLSessionUploader` / `ObjectUploader` / `UploadError` not defined.

- [ ] **Step 3: Implement the uploader**

`Sources/QuickSnipCore/ObjectUploader.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ObjectUploaderTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/ObjectUploader.swift Tests/QuickSnipCoreTests/ObjectUploaderTests.swift
git commit -m "feat: URLSession PUT object uploader behind a protocol"
```

---

## Task 8: Clipboard writer

**Files:**
- Create: `Sources/QuickSnipCore/ClipboardWriter.swift`
- Test: `Tests/QuickSnipCoreTests/ClipboardWriterTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `protocol ClipboardWriting { func writeURL(_ url: URL) }`
  - `struct ClipboardWriter: ClipboardWriting { init(pasteboard: NSPasteboard = .general) }`
  - Writes the URL as a `.string` and tags it with the `org.nspasteboard.TransientType` marker so clipboard-history apps ignore it (spec §15). Used by Task 9 (via protocol) and Task 16 (real impl).

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/ClipboardWriterTests.swift` — uses a uniquely named (non-general) pasteboard, so the developer's real clipboard is untouched:

```swift
import XCTest
import AppKit
@testable import QuickSnipCore

final class ClipboardWriterTests: XCTestCase {
    func testWritesURLStringAndTransientMarker() {
        let pb = NSPasteboard(name: NSPasteboard.Name("com.quicksnip.test.\(UUID().uuidString)"))
        let writer = ClipboardWriter(pasteboard: pb)

        writer.writeURL(URL(string: "https://cdn.example.com/ab12cd.png")!)

        XCTAssertEqual(pb.string(forType: .string), "https://cdn.example.com/ab12cd.png")
        let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        XCTAssertNotNil(pb.data(forType: transient), "Transient marker must be set")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClipboardWriterTests`
Expected: FAIL — `ClipboardWriter` / `ClipboardWriting` not defined.

- [ ] **Step 3: Implement the writer**

`Sources/QuickSnipCore/ClipboardWriter.swift`:

```swift
import Foundation
import AppKit

public protocol ClipboardWriting {
    func writeURL(_ url: URL)
}

public struct ClipboardWriter: ClipboardWriting {
    private let pasteboard: NSPasteboard
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func writeURL(_ url: URL) {
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        // Marker so well-behaved clipboard managers can ignore programmatic writes.
        pasteboard.setData(Data(), forType: Self.transientType)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ClipboardWriterTests`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/ClipboardWriter.swift Tests/QuickSnipCoreTests/ClipboardWriterTests.swift
git commit -m "feat: clipboard writer with transient pasteboard marker"
```

---

## Task 9: Upload pipeline + optimistic-copy policy

**Files:**
- Create: `Sources/QuickSnipCore/UploadItem.swift`
- Create: `Sources/QuickSnipCore/UploadPipeline.swift`
- Test: `Tests/QuickSnipCoreTests/UploadPipelineTests.swift`

**Interfaces:**
- Consumes: `StorageProvider` (Task 6), `ObjectUploader` (Task 7), `ClipboardWriting` (Task 8), `NamingScheme`/`KeyGenerator` (Task 5), `ContentType` (Task 4).
- Produces:
  - `enum UploadOrigin { case capture, drop, text }`
  - `struct UploadItem { let data, fileExtension, origin, isBurner }`
  - `struct UploadOutcome { let key, url, copiedOptimistically, verified }`
  - `final class UploadPipeline { init(provider:uploader:clipboard:namingScheme:optimisticThresholdBytes:); func upload(_ item: UploadItem, date: Date, using rng: inout some RandomNumberGenerator) async throws -> UploadOutcome }`
  - Policy: pre-copy if `!isBurner && data.count <= optimisticThresholdBytes` (default 5 MB), else wait for verification, then copy. The link copied is always `provider.publicURL(forKey:)`. Used by Task 16.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/UploadPipelineTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

private final class FakeProvider: StorageProvider {
    func presignPutURL(key: String, expiresIn: Int, date: Date) throws -> URL {
        URL(string: "https://put.example.com/\(key)?sig=x")!
    }
    func publicURL(forKey key: String) -> URL {
        URL(string: "https://cdn.example.com/\(key)")!
    }
}

private final class RecordingUploader: ObjectUploader {
    var putCalled = false
    var putContentType: String?
    func put(data: Data, to url: URL, contentType: String) async throws {
        putCalled = true
        putContentType = contentType
    }
}

private final class RecordingClipboard: ClipboardWriting {
    var writes: [URL] = []
    func writeURL(_ url: URL) { writes.append(url) }
}

final class UploadPipelineTests: XCTestCase {
    private func date() -> Date { Date(timeIntervalSince1970: 0) }

    func testNormalCaptureCopiesOptimisticallyBeforeUpload() async throws {
        let clipboard = RecordingClipboard()
        let pipeline = UploadPipeline(
            provider: FakeProvider(), uploader: RecordingUploader(),
            clipboard: clipboard, namingScheme: NamingScheme(slugLength: 8),
            optimisticThresholdBytes: 5 * 1024 * 1024
        )
        var rng = SeededRNG(seed: 9)
        let item = UploadItem(data: Data(count: 1000), fileExtension: "png", origin: .capture, isBurner: false)
        let outcome = try await pipeline.upload(item, date: date(), using: &rng)

        XCTAssertTrue(outcome.copiedOptimistically)
        XCTAssertTrue(outcome.verified)
        XCTAssertEqual(clipboard.writes.first, URL(string: "https://cdn.example.com/\(outcome.key)"))
    }

    func testBurnerWaitsForVerifyBeforeCopying() async throws {
        let clipboard = RecordingClipboard()
        let pipeline = UploadPipeline(
            provider: FakeProvider(), uploader: RecordingUploader(),
            clipboard: clipboard, namingScheme: NamingScheme(slugLength: 8),
            optimisticThresholdBytes: 5 * 1024 * 1024
        )
        var rng = SeededRNG(seed: 9)
        let item = UploadItem(data: Data(count: 1000), fileExtension: "png", origin: .capture, isBurner: true)
        let outcome = try await pipeline.upload(item, date: date(), using: &rng)

        XCTAssertFalse(outcome.copiedOptimistically)
        XCTAssertEqual(clipboard.writes.count, 1, "Copied exactly once, after verify")
    }

    func testLargeFileWaitsForVerify() async throws {
        let clipboard = RecordingClipboard()
        let pipeline = UploadPipeline(
            provider: FakeProvider(), uploader: RecordingUploader(),
            clipboard: clipboard, namingScheme: NamingScheme(slugLength: 8),
            optimisticThresholdBytes: 5 * 1024 * 1024
        )
        var rng = SeededRNG(seed: 9)
        let item = UploadItem(data: Data(count: 6 * 1024 * 1024), fileExtension: "zip", origin: .drop, isBurner: false)
        let outcome = try await pipeline.upload(item, date: date(), using: &rng)

        XCTAssertFalse(outcome.copiedOptimistically)
    }

    func testUsesCorrectContentType() async throws {
        let uploader = RecordingUploader()
        let pipeline = UploadPipeline(
            provider: FakeProvider(), uploader: uploader,
            clipboard: RecordingClipboard(), namingScheme: NamingScheme(slugLength: 8),
            optimisticThresholdBytes: 5 * 1024 * 1024
        )
        var rng = SeededRNG(seed: 9)
        let item = UploadItem(data: Data(count: 10), fileExtension: "png", origin: .capture, isBurner: false)
        _ = try await pipeline.upload(item, date: date(), using: &rng)

        XCTAssertTrue(uploader.putCalled)
        XCTAssertEqual(uploader.putContentType, "image/png")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter UploadPipelineTests`
Expected: FAIL — `UploadPipeline` / `UploadItem` / `UploadOutcome` not defined.

- [ ] **Step 3: Implement the models and pipeline**

`Sources/QuickSnipCore/UploadItem.swift`:

```swift
import Foundation

public enum UploadOrigin: Equatable {
    case capture, drop, text
}

public struct UploadItem {
    public let data: Data
    public let fileExtension: String
    public let origin: UploadOrigin
    public let isBurner: Bool

    public init(data: Data, fileExtension: String, origin: UploadOrigin, isBurner: Bool) {
        self.data = data
        self.fileExtension = fileExtension
        self.origin = origin
        self.isBurner = isBurner
    }
}

public struct UploadOutcome: Equatable {
    public let key: String
    public let url: URL
    public let copiedOptimistically: Bool
    public let verified: Bool
}
```

`Sources/QuickSnipCore/UploadPipeline.swift`:

```swift
import Foundation

public final class UploadPipeline {
    private let provider: StorageProvider
    private let uploader: ObjectUploader
    private let clipboard: ClipboardWriting
    private let keyGenerator: KeyGenerator
    private let optimisticThresholdBytes: Int
    private let presignTTL: Int

    public init(
        provider: StorageProvider,
        uploader: ObjectUploader,
        clipboard: ClipboardWriting,
        namingScheme: NamingScheme,
        optimisticThresholdBytes: Int = 5 * 1024 * 1024,
        presignTTL: Int = 300
    ) {
        self.provider = provider
        self.uploader = uploader
        self.clipboard = clipboard
        self.keyGenerator = KeyGenerator(scheme: namingScheme)
        self.optimisticThresholdBytes = optimisticThresholdBytes
        self.presignTTL = presignTTL
    }

    public func upload(
        _ item: UploadItem,
        date: Date = Date(),
        using rng: inout some RandomNumberGenerator
    ) async throws -> UploadOutcome {
        let key = keyGenerator.makeKey(ext: item.fileExtension, date: date, using: &rng)
        let publicURL = provider.publicURL(forKey: key)

        // Optimistic-clipboard correctness guard (spec §6): pre-copy only for
        // normal, sub-threshold, non-burner uploads.
        let preCopy = !item.isBurner && item.data.count <= optimisticThresholdBytes
        if preCopy {
            clipboard.writeURL(publicURL)
        }

        let putURL = try provider.presignPutURL(key: key, expiresIn: presignTTL, date: date)
        let contentType = ContentType.mime(forExtension: item.fileExtension)
        try await uploader.put(data: item.data, to: putURL, contentType: contentType)

        if !preCopy {
            clipboard.writeURL(publicURL)
        }

        return UploadOutcome(key: key, url: publicURL, copiedOptimistically: preCopy, verified: true)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter UploadPipelineTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/UploadItem.swift Sources/QuickSnipCore/UploadPipeline.swift Tests/QuickSnipCoreTests/UploadPipelineTests.swift
git commit -m "feat: upload pipeline with optimistic-clipboard correctness guard"
```

---

## Task 10: Keychain credential store

**Files:**
- Create: `Sources/QuickSnipCore/KeychainStore.swift`
- Test: `Tests/QuickSnipCoreTests/KeychainStoreTests.swift`

**Interfaces:**
- Consumes: `SigV4Credentials` (Task 3).
- Produces:
  - `struct KeychainStore { init(service: String); func save(_ creds: SigV4Credentials, forProvider id: String) throws; func load(forProvider id: String) throws -> SigV4Credentials?; func delete(forProvider id: String) throws }`
  - Stores access/secret as a JSON blob in a generic-password Keychain item keyed by provider id. Used by Task 16.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/KeychainStoreTests.swift` — uses a unique service name per run and cleans up, so it never collides with real credentials:

```swift
import XCTest
@testable import QuickSnipCore

final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!
    private let providerID = "test-provider"

    override func setUp() {
        store = KeychainStore(service: "com.quicksnip.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.delete(forProvider: providerID)
    }

    func testSaveThenLoadRoundTrips() throws {
        let creds = SigV4Credentials(accessKeyID: "AKID", secretAccessKey: "SECRET/value+1")
        try store.save(creds, forProvider: providerID)
        XCTAssertEqual(try store.load(forProvider: providerID), creds)
    }

    func testLoadMissingReturnsNil() throws {
        XCTAssertNil(try store.load(forProvider: "does-not-exist"))
    }

    func testSaveOverwritesExisting() throws {
        try store.save(SigV4Credentials(accessKeyID: "A1", secretAccessKey: "S1"), forProvider: providerID)
        try store.save(SigV4Credentials(accessKeyID: "A2", secretAccessKey: "S2"), forProvider: providerID)
        XCTAssertEqual(try store.load(forProvider: providerID)?.accessKeyID, "A2")
    }

    func testDeleteRemoves() throws {
        try store.save(SigV4Credentials(accessKeyID: "A", secretAccessKey: "S"), forProvider: providerID)
        try store.delete(forProvider: providerID)
        XCTAssertNil(try store.load(forProvider: providerID))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeychainStoreTests`
Expected: FAIL — `KeychainStore` not defined.

> Note for the implementer: these tests touch the real login Keychain. If the CI environment has no Keychain, mark them skipped with `try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)` at the top of each test. On a developer Mac they run normally.

- [ ] **Step 3: Implement the store**

`Sources/QuickSnipCore/KeychainStore.swift`:

```swift
import Foundation
import Security

public struct KeychainStore {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case decodeFailed
    }

    private struct StoredCredentials: Codable {
        let accessKeyID: String
        let secretAccessKey: String
    }

    private let service: String

    public init(service: String = "com.quicksnip.credentials") {
        self.service = service
    }

    public func save(_ creds: SigV4Credentials, forProvider id: String) throws {
        let payload = try JSONEncoder().encode(
            StoredCredentials(accessKeyID: creds.accessKeyID, secretAccessKey: creds.secretAccessKey)
        )
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
        SecItemDelete(query as CFDictionary) // overwrite semantics
        var attributes = query
        attributes[kSecValueData as String] = payload
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    public func load(forProvider id: String) throws -> SigV4Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data,
              let stored = try? JSONDecoder().decode(StoredCredentials.self, from: data) else {
            throw KeychainError.decodeFailed
        }
        return SigV4Credentials(accessKeyID: stored.accessKeyID, secretAccessKey: stored.secretAccessKey)
    }

    public func delete(forProvider id: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeychainStoreTests`
Expected: PASS (4 tests). On first run macOS may prompt to allow the test binary to access the Keychain — click "Always Allow".

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/KeychainStore.swift Tests/QuickSnipCoreTests/KeychainStoreTests.swift
git commit -m "feat: Keychain credential store keyed by provider id"
```

---

## Task 11: Capture command builder

**Files:**
- Create: `Sources/QuickSnipCore/CaptureCommand.swift`
- Test: `Tests/QuickSnipCoreTests/CaptureCommandTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum CaptureMode { case region, window, fullScreen }`
  - `enum CaptureCommand { static func arguments(mode: CaptureMode, outputPath: String) -> [String] }`
  - Builds the `screencapture` argument vector (pure/testable); the `Process` execution lives in Task 14's `CaptureService`. Used by Task 14.

- [ ] **Step 1: Write the failing test**

`Tests/QuickSnipCoreTests/CaptureCommandTests.swift`:

```swift
import XCTest
@testable import QuickSnipCore

final class CaptureCommandTests: XCTestCase {
    func testRegionIsInteractive() {
        let args = CaptureCommand.arguments(mode: .region, outputPath: "/tmp/a.png")
        XCTAssertEqual(args, ["-i", "-o", "/tmp/a.png"])
    }

    func testWindowIsInteractiveWindow() {
        let args = CaptureCommand.arguments(mode: .window, outputPath: "/tmp/b.png")
        XCTAssertEqual(args, ["-i", "-w", "-o", "/tmp/b.png"])
    }

    func testFullScreenHasNoInteractiveFlag() {
        let args = CaptureCommand.arguments(mode: .fullScreen, outputPath: "/tmp/c.png")
        XCTAssertEqual(args, ["/tmp/c.png"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CaptureCommandTests`
Expected: FAIL — `CaptureCommand` / `CaptureMode` not defined.

- [ ] **Step 3: Implement the builder**

`Sources/QuickSnipCore/CaptureCommand.swift`:

```swift
import Foundation

public enum CaptureMode {
    case region, window, fullScreen
}

/// Builds argument vectors for /usr/sbin/screencapture. `-i` = interactive
/// selection, `-w` = window mode, `-o` = no window shadow.
public enum CaptureCommand {
    public static func arguments(mode: CaptureMode, outputPath: String) -> [String] {
        switch mode {
        case .region:
            return ["-i", "-o", outputPath]
        case .window:
            return ["-i", "-w", "-o", outputPath]
        case .fullScreen:
            return [outputPath]
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CaptureCommandTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnipCore/CaptureCommand.swift Tests/QuickSnipCoreTests/CaptureCommandTests.swift
git commit -m "feat: screencapture argument-vector builder"
```

---

## Task 12: App entry + accessory activation

**Files:**
- Modify: `Sources/QuickSnip/main.swift`
- Create: `Sources/QuickSnip/AppDelegate.swift`

**Interfaces:**
- Consumes: nothing from Core yet (wiring lands in Task 16).
- Produces: a runnable menubar agent process with no dock icon. `AppDelegate` is the wiring point later tasks extend.

> Note: Tasks 12–16 are OS-integration shells (`NSApplication`, `NSStatusItem`, `NSPanel`, `Process`, global hotkeys). There is no meaningful pure logic to unit-test here — the testable pieces already live in Core. Each task's verification is **build + a scripted manual smoke test**, which is the honest way to validate UI/lifecycle glue.

- [ ] **Step 1: Replace `main.swift`**

`Sources/QuickSnip/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 2: Create `AppDelegate`**

`Sources/QuickSnip/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menubar agent: no dock icon, no app menu (runtime equivalent of LSUIElement).
        NSApp.setActivationPolicy(.accessory)
        NSLog("QuickSnip launched as accessory agent")
    }
}
```

- [ ] **Step 3: Build and smoke-test manually**

Run: `swift build`
Expected: build succeeds.

Run: `swift run QuickSnip` (leave it running ~3 seconds, then Ctrl-C).
Expected: no crash; no Dock icon appears for the process; the log line `QuickSnip launched as accessory agent` prints. (There is no menubar item yet — that is Task 13.)

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickSnip/main.swift Sources/QuickSnip/AppDelegate.swift
git commit -m "feat: menubar-agent app entry point with accessory activation policy"
```

---

## Task 13: Menubar status item

**Files:**
- Create: `Sources/QuickSnip/MenuBarController.swift`
- Modify: `Sources/QuickSnip/AppDelegate.swift`

**Interfaces:**
- Consumes: nothing from Core.
- Produces: `final class MenuBarController { init(); func setStatus(_ status: MenuBarController.Status) }` with `enum Status { case idle, uploading, success, error }`, and an `NSMenu` exposing capture actions (wired in Task 16) + Quit. Used by Tasks 14 and 16.

- [ ] **Step 1: Create `MenuBarController`**

`Sources/QuickSnip/MenuBarController.swift`:

```swift
import AppKit

final class MenuBarController {
    enum Status { case idle, uploading, success, error }

    private let statusItem: NSStatusItem
    let menu = NSMenu()

    /// Action handlers wired by AppDelegate in Task 16.
    var onCaptureRegion: (() -> Void)?
    var onCaptureWindow: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton(for: .idle)
        buildMenu()
        statusItem.menu = menu
    }

    func setStatus(_ status: Status) {
        configureButton(for: status)
    }

    private func configureButton(for status: Status) {
        guard let button = statusItem.button else { return }
        let symbol: String
        switch status {
        case .idle:      symbol = "camera"
        case .uploading: symbol = "arrow.up.circle"
        case .success:   symbol = "checkmark.circle"
        case .error:     symbol = "exclamationmark.triangle"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "QuickSnip")
        button.image?.isTemplate = true
    }

    private func buildMenu() {
        let region = NSMenuItem(title: "Capture Region", action: #selector(captureRegion), keyEquivalent: "")
        region.target = self
        menu.addItem(region)

        let window = NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: "")
        window.target = self
        menu.addItem(window)

        let full = NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: "")
        full.target = self
        menu.addItem(full)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickSnip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func captureRegion() { onCaptureRegion?() }
    @objc private func captureWindow() { onCaptureWindow?() }
    @objc private func captureFullScreen() { onCaptureFullScreen?() }
}
```

- [ ] **Step 2: Hold the controller in `AppDelegate`**

Replace `Sources/QuickSnip/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBar = MenuBarController()
        NSLog("QuickSnip launched as accessory agent")
    }
}
```

- [ ] **Step 3: Build and smoke-test manually**

Run: `swift build` → succeeds.
Run: `swift run QuickSnip`.
Expected: a camera icon appears in the macOS menu bar. Clicking it shows the menu with "Capture Region / Window / Full Screen", a separator, and "Quit QuickSnip". "Quit QuickSnip" terminates the app. (Capture items do nothing yet — wired in Task 16.)

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickSnip/MenuBarController.swift Sources/QuickSnip/AppDelegate.swift
git commit -m "feat: NSStatusItem menubar controller with capture menu"
```

---

## Task 14: Toast HUD + capture service

**Files:**
- Create: `Sources/QuickSnip/ToastController.swift`
- Create: `Sources/QuickSnip/CaptureService.swift`

**Interfaces:**
- Consumes: `CaptureCommand`, `CaptureMode` (Task 11).
- Produces:
  - `final class ToastController { func show(message: String, style: ToastController.Style) }` with `enum Style { case info, success, error }`.
  - `final class CaptureService { func capture(mode: CaptureMode) throws -> URL }` — runs `screencapture` to a temp PNG and returns its path; throws `CaptureService.CaptureError.cancelledOrEmpty` if the user cancels.
  - Used by Task 16.

- [ ] **Step 1: Create `ToastController`**

`Sources/QuickSnip/ToastController.swift`:

```swift
import AppKit

final class ToastController {
    enum Style { case info, success, error }

    private var panel: NSPanel?

    func show(message: String, style: Style) {
        DispatchQueue.main.async { [weak self] in
            self?.present(message: message, style: style)
        }
    }

    private func present(message: String, style: Style) {
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = Self.color(for: style).cgColor
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        let size = container.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = container

        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - size.width - 20
            let y = screen.visibleFrame.maxY - size.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak panel] in
            panel?.orderOut(nil)
        }
    }

    private static func color(for style: Style) -> NSColor {
        switch style {
        case .info:    return NSColor.black.withAlphaComponent(0.82)
        case .success: return NSColor.systemGreen.withAlphaComponent(0.92)
        case .error:   return NSColor.systemOrange.withAlphaComponent(0.92)
        }
    }
}
```

- [ ] **Step 2: Create `CaptureService`**

`Sources/QuickSnip/CaptureService.swift`:

```swift
import Foundation
import QuickSnipCore

final class CaptureService {
    enum CaptureError: Error { case cancelledOrEmpty, launchFailed }

    /// Captures to a temp PNG and returns its URL. `screencapture` writes no
    /// file when the user presses Escape, which we surface as cancelledOrEmpty.
    func capture(mode: CaptureMode) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let output = dir.appendingPathComponent("quicksnip-\(UUID().uuidString).png")
        let args = CaptureCommand.arguments(mode: mode, outputPath: output.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        do {
            try process.run()
        } catch {
            throw CaptureError.launchFailed
        }
        process.waitUntilExit()

        guard FileManager.default.fileExists(atPath: output.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: output.path),
              (attrs[.size] as? Int ?? 0) > 0 else {
            throw CaptureError.cancelledOrEmpty
        }
        return output
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: build succeeds. (These classes are exercised end-to-end in Task 16.)

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickSnip/ToastController.swift Sources/QuickSnip/CaptureService.swift
git commit -m "feat: toast HUD panel and screencapture service"
```

---

## Task 15: Global hotkeys

**Files:**
- Create: `Sources/QuickSnip/HotkeyManager.swift`

**Interfaces:**
- Consumes: `KeyboardShortcuts` package.
- Produces:
  - `extension KeyboardShortcuts.Name` with `.captureRegion`, `.captureWindow`, `.captureFullScreen` (defaults: ⌘⇧2, ⌘⇧3, ⌘⇧4).
  - `final class HotkeyManager { var onRegion/onWindow/onFullScreen: (() -> Void)?; func register() }`
  - Used by Task 16.

- [ ] **Step 1: Create `HotkeyManager`**

`Sources/QuickSnip/HotkeyManager.swift`:

```swift
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureRegion = Self("captureRegion", default: .init(.two, modifiers: [.command, .shift]))
    static let captureWindow = Self("captureWindow", default: .init(.three, modifiers: [.command, .shift]))
    static let captureFullScreen = Self("captureFullScreen", default: .init(.four, modifiers: [.command, .shift]))
}

final class HotkeyManager {
    var onRegion: (() -> Void)?
    var onWindow: (() -> Void)?
    var onFullScreen: (() -> Void)?

    func register() {
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak self] in self?.onRegion?() }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [weak self] in self?.onWindow?() }
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [weak self] in self?.onFullScreen?() }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: build succeeds (resolves `KeyboardShortcuts`). Hotkeys are activated and verified in Task 16.

- [ ] **Step 3: Commit**

```bash
git add Sources/QuickSnip/HotkeyManager.swift
git commit -m "feat: global capture hotkeys via KeyboardShortcuts"
```

---

## Task 16: End-to-end wiring + dev config

**Files:**
- Create: `Sources/QuickSnip/DevConfig.swift`
- Modify: `Sources/QuickSnip/AppDelegate.swift`

**Interfaces:**
- Consumes: `MenuBarController` (T13), `ToastController`/`CaptureService` (T14), `HotkeyManager` (T15), `UploadPipeline`/`UploadItem` (T9), `S3CompatProvider`/`ProviderConfig` (T6), `URLSessionUploader` (T7), `ClipboardWriter` (T8), `KeychainStore` (T10), `NamingScheme` (T5).
- Produces: a working capture→upload→clipboard→toast flow. `DevConfig` reads provider settings from environment variables (throwaway; replaced by the M3 wizard).

> The `DevConfig` env-var loader is deliberately minimal scaffolding so this milestone is end-to-end testable before the M3 onboarding wizard exists. It is expected to be deleted in M3.

- [ ] **Step 1: Create `DevConfig`**

`Sources/QuickSnip/DevConfig.swift`:

```swift
import Foundation
import QuickSnipCore

/// Throwaway configuration for the M0+M1 end-to-end smoke test. Reads the
/// active provider from environment variables. Replaced by the guided
/// R2 wizard in M3. Required env vars:
///   QS_ENDPOINT, QS_REGION, QS_BUCKET, QS_ACCESS_KEY, QS_SECRET_KEY
/// Optional: QS_PUBLIC_BASE, QS_PATH_STYLE (default "1"), QS_KIND (default "r2")
enum DevConfig {
    static func load() -> (config: ProviderConfig, credentials: SigV4Credentials)? {
        let env = ProcessInfo.processInfo.environment
        guard let endpoint = env["QS_ENDPOINT"].flatMap(URL.init(string:)),
              let region = env["QS_REGION"],
              let bucket = env["QS_BUCKET"],
              let access = env["QS_ACCESS_KEY"],
              let secret = env["QS_SECRET_KEY"] else {
            return nil
        }
        let config = ProviderConfig(
            id: "dev",
            kind: ProviderKind(rawValue: env["QS_KIND"] ?? "r2") ?? .r2,
            endpoint: endpoint,
            region: region,
            bucket: bucket,
            pathStyle: (env["QS_PATH_STYLE"] ?? "1") != "0",
            publicBase: env["QS_PUBLIC_BASE"].flatMap(URL.init(string:))
        )
        return (config, SigV4Credentials(accessKeyID: access, secretAccessKey: secret))
    }
}
```

- [ ] **Step 2: Wire everything in `AppDelegate`**

Replace `Sources/QuickSnip/AppDelegate.swift`:

```swift
import AppKit
import QuickSnipCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private let toast = ToastController()
    private let capture = CaptureService()
    private let hotkeys = HotkeyManager()
    private var pipeline: UploadPipeline?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let menuBar = MenuBarController()
        self.menuBar = menuBar

        configurePipeline()

        let region = { [weak self] in self?.runCapture(.region) }
        let window = { [weak self] in self?.runCapture(.window) }
        let full = { [weak self] in self?.runCapture(.fullScreen) }

        menuBar.onCaptureRegion = region
        menuBar.onCaptureWindow = window
        menuBar.onCaptureFullScreen = full

        hotkeys.onRegion = region
        hotkeys.onWindow = window
        hotkeys.onFullScreen = full
        hotkeys.register()

        NSLog("QuickSnip ready")
    }

    private func configurePipeline() {
        guard let dev = DevConfig.load() else {
            toast.show(message: "No provider configured (set QS_* env vars)", style: .error)
            return
        }
        let provider = S3CompatProvider(config: dev.config, credentials: dev.credentials)
        pipeline = UploadPipeline(
            provider: provider,
            uploader: URLSessionUploader(),
            clipboard: ClipboardWriter(),
            namingScheme: NamingScheme(slugLength: 10)
        )
    }

    private func runCapture(_ mode: CaptureMode) {
        guard let pipeline else {
            toast.show(message: "No provider configured", style: .error)
            return
        }
        let fileURL: URL
        do {
            fileURL = try capture.capture(mode: mode)
        } catch {
            return // user cancelled — silent no-op
        }

        menuBar?.setStatus(.uploading)
        toast.show(message: "Uploading…", style: .info)

        Task { @MainActor in
            do {
                let data = try Data(contentsOf: fileURL)
                let item = UploadItem(data: data, fileExtension: "png", origin: .capture, isBurner: false)
                var rng = SystemRandomNumberGenerator()
                let outcome = try await pipeline.upload(item, using: &rng)
                try? FileManager.default.removeItem(at: fileURL) // auto-delete temp
                menuBar?.setStatus(.success)
                toast.show(message: "Link copied: \(outcome.url.lastPathComponent)", style: .success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.menuBar?.setStatus(.idle)
                }
            } catch {
                menuBar?.setStatus(.error)
                toast.show(message: "Upload failed", style: .error)
            }
        }
    }
}
```

- [ ] **Step 3: Full test suite passes**

Run: `swift test`
Expected: all Core tests PASS (Tasks 1–11).

- [ ] **Step 4: End-to-end manual smoke test**

Prereq: an S3-compatible bucket (R2 recommended) with CORS allowing `PUT`, and scoped credentials. Export env vars, then run:

```bash
export QS_ENDPOINT="https://<account>.r2.cloudflarestorage.com"
export QS_REGION="auto"
export QS_BUCKET="<your-bucket>"
export QS_ACCESS_KEY="<access-key>"
export QS_SECRET_KEY="<secret-key>"
export QS_PUBLIC_BASE="https://<your-public-base>"   # optional
swift run QuickSnip
```

Then:
1. Grant Accessibility/screen-recording permission if macOS prompts (needed for `screencapture`).
2. Press ⌘⇧2 (or use the menu's "Capture Region"), drag a region.
3. Expected: an "Uploading…" toast, then a green "Link copied" toast; the menubar icon cycles idle→uploading→success→idle.
4. Paste (⌘V) into any text field — a URL like `https://<public-base>/<10-char-slug>.png` appears.
5. Open that URL in a browser — the screenshot loads.
6. Confirm the temp file is gone: `ls $TMPDIR/quicksnip-*.png` returns no matches.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSnip/DevConfig.swift Sources/QuickSnip/AppDelegate.swift
git commit -m "feat: end-to-end capture → presign → upload → optimistic clipboard → toast"
```

---

## Self-Review

**1. Spec coverage (against §51 MVP items relevant to M0+M1, and §53 milestones M0/M1):**
- Menubar agent, no dock icon (§11, §51.1) → Tasks 12–13.
- Polished toast HUD (§37, §51.1) → Task 14.
- Region/window/fullscreen capture via global hotkeys using `screencapture` (§12, §51.2) → Tasks 11, 14, 15, 16.
- One provider via S3-compat abstraction, R2 happy path (§41, §51.3) → Task 6 (the M3 wizard is explicitly out of scope here; `DevConfig` is the interim).
- Direct presigned PUT, deterministic URL, optimistic clipboard copy (§6, §16, §27, §51.4) → Tasks 3, 6, 7, 8, 9, 16.
- Hand-rolled SigV4 (§9, §27, user decision) → Task 3.
- Unguessable random keys (§18, §29) → Task 5.
- Keychain credentials (§9, §21) → Task 10.
- Optimistic-clipboard correctness guard for burner/large files (§6) → Task 9.
- Auto-delete local capture after upload (§51.8) → Task 16.
- Success/fail toasts + menubar status states (§11, §37) → Tasks 13, 14, 16.

*Deferred deliberately (documented in Global Constraints):* SQLite history, offline queue/retry, drag-drop, config validator, lifecycle expiry, the R2 wizard — all M2/M3. The `StorageProvider` protocol omits `deleteObject`/`validateConfig` (added in M2/M3) to avoid placeholders now.

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N" left. Every code step shows complete, compilable Swift. The only intentional scaffolding (`DevConfig`) is fully implemented and labeled for removal in M3.

**3. Type consistency:** Cross-task names verified — `SigV4Credentials`, `SigV4Signer.presign(method:url:expiresIn:date:)`, `ProviderConfig`, `S3CompatProvider.objectURL/publicURL/presignPutURL`, `ObjectUploader.put(data:to:contentType:)`, `ClipboardWriting.writeURL(_:)`, `NamingScheme`/`KeyGenerator.makeKey(ext:date:using:)`, `ContentType.mime(forExtension:)`, `UploadItem`/`UploadOutcome`, `UploadPipeline.upload(_:date:using:)`, `CaptureCommand.arguments(mode:outputPath:)`/`CaptureMode`, `KeychainStore.save/load/delete(forProvider:)`, `MenuBarController.Status`, `ToastController.Style`, `KeyboardShortcuts.Name` extensions — all consumers match producers. The `SeededRNG` test helper defined in Task 5 is reused by Task 9 (same target).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-26-quicksnip-foundation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
