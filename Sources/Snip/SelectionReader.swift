import AppKit
import ApplicationServices

/// Reads the currently selected text. Prefers the Accessibility API (clean, no
/// clipboard mutation); falls back to synthetic ⌘C + pasteboard read (spec §14).
enum SelectionReader {
    static func currentSelectedText() -> String? {
        if let ax = axSelectedText(), !ax.isEmpty { return ax }
        return clipboardFallback()
    }

    private static func axSelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String else { return nil }
        return text
    }

    /// Save the pasteboard string, synthesize ⌘C, read it back, then restore.
    /// (Rich/multi-type restoration is intentionally out of scope for v0.)
    private static func clipboardFallback() -> String? {
        let pb = NSPasteboard.general
        let savedString = pb.string(forType: .string)
        let changeCount = pb.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 0x08 // 'c'
        let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        var result: String?
        let deadline = Date().addingTimeInterval(0.3)
        while Date() < deadline {
            if pb.changeCount != changeCount {
                result = pb.string(forType: .string)
                break
            }
            usleep(15_000)
        }

        // Restore the user's clipboard, tagged transient so history apps ignore it.
        pb.clearContents()
        if let savedString { pb.setString(savedString, forType: .string) }
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        return result
    }
}
