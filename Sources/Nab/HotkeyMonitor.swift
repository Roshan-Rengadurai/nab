import AppKit

/// Global "tap a modifier twice" gestures via a passive CGEventTap:
/// double-⌘ (capture) and double-⌃ (text share). Requires Input Monitoring
/// permission. Listen-only — never swallows the user's events.
///
/// Shift is allowed to ride along on the gesture: the fire callbacks receive
/// whether Shift was held on the triggering tap, so callers can offer a
/// "raw" variant (skip the styled window). Control / Option still disqualify.
final class HotkeyMonitor {
    /// Fired on double-⌘. Bool = was Shift held on the second tap.
    var onCommandDouble: ((Bool) -> Void)?
    /// Fired on double-⌃. Bool = was Shift held on the second tap.
    var onControlDouble: ((Bool) -> Void)?
    /// Fired on double-tap of ⌘+⌃ chord held simultaneously.
    var onCommandControlDouble: (() -> Void)?
    /// Max seconds between the two taps (read live from settings).
    var gapProvider: () -> TimeInterval = { 0.3 }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private struct ModState { var wasDown = false; var armed = false; var last: CFAbsoluteTime = 0 }
    private var cmd = ModState()
    private var ctrl = ModState()
    private var cmdCtrl = ModState()

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
            // tapCreate failed outright. Note: a `.listenOnly` tap is created
            // successfully even when untrusted for Accessibility (it just won't
            // see other apps' events), so callers must check AXIsProcessTrusted()
            // separately — a `true` return here does not imply trust.
            return false
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
        cmdCtrl = ModState()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if type == .keyDown {
            cmd.armed = false
            ctrl.armed = false
            cmdCtrl.armed = false
            return
        }
        guard type == .flagsChanged else { return }

        let flags = event.flags
        // Shift is intentionally NOT a disqualifier — it rides along as the "raw" modifier.
        process(modifier: .maskCommand, others: [.maskControl, .maskAlternate],
                flags: flags, state: &cmd, fire: onCommandDouble)
        process(modifier: .maskControl, others: [.maskCommand, .maskAlternate],
                flags: flags, state: &ctrl, fire: onControlDouble)
        processChord(flags: flags, state: &cmdCtrl, fire: onCommandControlDouble)
    }

    /// Fires when Cmd+Ctrl are held together (no Option) and that chord is
    /// pressed twice within the gap window.
    private func processChord(flags: CGEventFlags, state: inout ModState, fire: (() -> Void)?) {
        let chordDown = flags.contains(.maskCommand) && flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
        if chordDown && !state.wasDown {
            let now = CFAbsoluteTimeGetCurrent()
            if state.armed, now - state.last <= gapProvider() {
                state.armed = false
                DispatchQueue.main.async { fire?() }
            } else {
                state.armed = true
            }
            state.last = now
        }
        if flags.contains(.maskAlternate) { state.armed = false }
        state.wasDown = chordDown
    }

    private func process(modifier: CGEventFlags, others: CGEventFlags,
                         flags: CGEventFlags, state: inout ModState, fire: ((Bool) -> Void)?) {
        let down = flags.contains(modifier)
        let shift = flags.contains(.maskShift)
        let only = flags.intersection(others).isEmpty
        if down && !state.wasDown {
            let now = CFAbsoluteTimeGetCurrent()
            if state.armed, only, now - state.last <= gapProvider() {
                state.armed = false
                DispatchQueue.main.async { fire?(shift) }
            } else {
                state.armed = only
            }
            state.last = now
        }
        if !only { state.armed = false }
        state.wasDown = down
    }
}
