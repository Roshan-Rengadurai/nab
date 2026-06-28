import AppKit

/// Global "tap a modifier twice" gestures via a passive CGEventTap:
/// double-⌘ (capture) and double-⌃ (text share). Requires Accessibility
/// permission. Listen-only — never swallows the user's events.
final class HotkeyMonitor {
    var onCommandDouble: (() -> Void)?
    var onControlDouble: (() -> Void)?
    /// Max seconds between the two taps (read live from settings).
    var gapProvider: () -> TimeInterval = { 0.3 }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private struct ModState { var wasDown = false; var armed = false; var last: CFAbsoluteTime = 0 }
    private var cmd = ModState()
    private var ctrl = ModState()

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false // not trusted yet
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        cmd = ModState()
        ctrl = ModState()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if type == .keyDown {
            cmd.armed = false
            ctrl.armed = false
            return
        }
        guard type == .flagsChanged else { return }

        let flags = event.flags
        process(modifier: .maskCommand, others: [.maskShift, .maskControl, .maskAlternate],
                flags: flags, state: &cmd, fire: onCommandDouble)
        process(modifier: .maskControl, others: [.maskShift, .maskCommand, .maskAlternate],
                flags: flags, state: &ctrl, fire: onControlDouble)
    }

    private func process(modifier: CGEventFlags, others: CGEventFlags,
                         flags: CGEventFlags, state: inout ModState, fire: (() -> Void)?) {
        let down = flags.contains(modifier)
        let only = flags.intersection(others).isEmpty
        if down && !state.wasDown {
            let now = CFAbsoluteTimeGetCurrent()
            if state.armed, only, now - state.last <= gapProvider() {
                state.armed = false
                DispatchQueue.main.async { fire?() }
            } else {
                state.armed = only
            }
            state.last = now
        }
        if !only { state.armed = false }
        state.wasDown = down
    }
}
