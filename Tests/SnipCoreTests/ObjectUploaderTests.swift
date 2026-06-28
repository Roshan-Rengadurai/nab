import XCTest
@testable import SnipCore

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
