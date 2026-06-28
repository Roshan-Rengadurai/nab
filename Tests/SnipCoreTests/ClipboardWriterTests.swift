import XCTest
import AppKit
@testable import SnipCore

final class ClipboardWriterTests: XCTestCase {
    func testWritesURLStringAndTransientMarker() {
        let pb = NSPasteboard(name: NSPasteboard.Name("com.snip.test.\(UUID().uuidString)"))
        let writer = ClipboardWriter(pasteboard: pb)

        writer.writeURL(URL(string: "https://cdn.example.com/ab12cd.png")!)

        XCTAssertEqual(pb.string(forType: .string), "https://cdn.example.com/ab12cd.png")
        let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        XCTAssertNotNil(pb.data(forType: transient), "Transient marker must be set")
    }
}
