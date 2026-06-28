import AppKit
import SwiftUI

enum ToastKind {
    case success, error
    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    var color: Color {
        switch self {
        case .success: return Gruv.green
        case .error: return Gruv.red
        }
    }
}

enum ToastPosition: String, CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

private struct ToastView: View {
    let kind: ToastKind
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(kind.color)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Gruv.fg0)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: 300, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Gruv.bg1))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(kind.color.opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 5)
        .padding(10) // breathing room inside the borderless panel for the shadow
    }
}

/// Borderless, non-activating floating toast in the gruvbox theme.
/// Always invoked from the main thread (capture/preview paths).
final class ToastController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    /// If `cursor` is non-nil the toast follows the pointer; otherwise it pins to `position`.
    func show(kind: ToastKind, message: String, position: ToastPosition,
              duration: TimeInterval, cursor: NSPoint? = nil) {
        let host = NSHostingView(rootView: ToastView(kind: kind, message: message))
        host.frame.size = host.fittingSize

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        if let cursor { placeNearCursor(panel, cursor) } else { place(panel, at: position) }

        dismissWork?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.22; panel.animator().alphaValue = 0 },
                                                 completionHandler: { panel.orderOut(nil) })
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // SwiftUI draws the shadow
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    private func place(_ panel: NSPanel, at position: ToastPosition) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let s = panel.frame.size
        let m: CGFloat = 12
        let x: CGFloat
        let y: CGFloat
        switch position {
        case .topLeading:     x = vf.minX + m;            y = vf.maxY - s.height - m
        case .topTrailing:    x = vf.maxX - s.width - m;  y = vf.maxY - s.height - m
        case .bottomLeading:  x = vf.minX + m;            y = vf.minY + m
        case .bottomTrailing: x = vf.maxX - s.width - m;  y = vf.minY + m
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func placeNearCursor(_ panel: NSPanel, _ cursor: NSPoint) {
        let s = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main
        let vf = screen?.visibleFrame ?? .zero
        // Default below-right of the pointer, then clamp inside the screen.
        var x = cursor.x + 16
        var y = cursor.y - s.height - 16
        x = min(max(x, vf.minX + 8), vf.maxX - s.width - 8)
        y = min(max(y, vf.minY + 8), vf.maxY - s.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
