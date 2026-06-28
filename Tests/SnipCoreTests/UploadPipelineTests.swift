import XCTest
@testable import SnipCore

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
