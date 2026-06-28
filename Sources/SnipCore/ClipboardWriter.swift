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
