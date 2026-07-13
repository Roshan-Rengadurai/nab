import AppKit
import SwiftUI
import Combine
import ApplicationServices
import NabCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    /// Frosted card overlay for the interactive gesture walkthrough.
    private var gestureGuideWindow: NSWindow?
    /// Transient full-screen "Welcome to Nab" splash shown before the windowed
    /// onboarding. Click-through and never key, so it can't block anything.
    private var splashWindow: NSWindow?
    /// While onboarding is up, global gestures are suppressed so the
    /// interactive "try it" step can practice locally without screencapture /
    /// Settings stealing focus.
    private var isOnboarding = false
    let settings = AppSettings()
    let history = UploadHistory()

    private let toast = ToastController()
    private let hotkey = HotkeyMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var axPollTimer: Timer?
    /// One guidance toast per launch about the (unpromptable) Input Monitoring permission.
    private var toldUserAboutInputMonitoring = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Access stored credentials (nab.credentials) up front on every launch.
        KeychainStore.shared.prime()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Nab")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let capture = NSMenuItem(title: "Capture Region", action: #selector(captureRegion), keyEquivalent: "2")
        capture.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(capture)
        menu.addItem(NSMenuItem(title: "Share Selected Text", action: #selector(shareText as () -> Void), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Onboarding…", action: #selector(showOnboardingMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Nab", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        // Gestures.
        hotkey.gapProvider = { [weak self] in (self?.settings.doubleCmdGap ?? 300) / 1000 }
        hotkey.onCommandDouble = { [weak self] shiftHeld in
            guard let self, !self.isOnboarding, self.settings.shortcutEnabled,
                  self.gestureAllowedInFrontmostApp() else { return }
            self.capture(shift: shiftHeld)
        }
        hotkey.onControlDouble = { [weak self] shiftHeld in
            guard let self, !self.isOnboarding, self.settings.textShareEnabled,
                  self.gestureAllowedInFrontmostApp() else { return }
            // ⇧ rides along to skip the styled window — when the setting allows it.
            let raw = shiftHeld && self.settings.shiftRawShare
            self.shareText(raw: raw)
        }
        hotkey.onCommandControlDouble = { [weak self] in
            guard let self, !self.isOnboarding, self.settings.cmdCtrlCopyImage,
                  self.gestureAllowedInFrontmostApp() else { return }
            self.captureToClipboard()
        }
        Publishers.CombineLatest3(settings.$shortcutEnabled, settings.$textShareEnabled, settings.$cmdCtrlCopyImage)
            .sink { [weak self] _, _, _ in self?.applyHotkeys() }
            .store(in: &cancellables)

        // Launch at login.
        settings.$launchAtLogin
            .dropFirst()
            .sink { LoginItem.set($0) }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self, selector: #selector(previewToast), name: .nabPreviewToast, object: nil)

        if settings.hasOnboarded {
            // Only surface Settings when the active mode genuinely can't upload
            // yet — hosted users with a license key shouldn't see it at launch.
            if !settings.isReadyToUpload { openSettings() }
        } else {
            showOnboarding()
        }
    }

    // MARK: - Hotkey / Accessibility

    /// Apply the Settings app filter (all / blacklist / whitelist) against
    /// whatever app is frontmost at gesture time. Nab itself is always allowed
    /// so the menubar/Settings never lock the user out of their own gestures.
    private func gestureAllowedInFrontmostApp() -> Bool {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if front == Bundle.main.bundleIdentifier { return true }
        return settings.gestureAllowed(inApp: front)
    }

    private func applyHotkeys() {
        let wantTap = settings.shortcutEnabled || settings.textShareEnabled || settings.cmdCtrlCopyImage
        guard wantTap else { hotkey.stop(); axPollTimer?.invalidate(); axPollTimer = nil; return }

        // Input Monitoring — not tap creation, not Accessibility — is the real
        // gate for a `.listenOnly` keyboard CGEventTap ("listen" needs Input
        // Monitoring; "modify" needs Accessibility). The tap is created
        // successfully even without it, but then only sees Nab's own events, so
        // gestures fire only while Nab is frontmost. Start the tap only once
        // granted; otherwise prompt and poll until the user grants it.
        // (Accessibility is still requested separately for the AX-based
        // selection reader used by text share.)
        if CGPreflightListenEventAccess() {
            axPollTimer?.invalidate(); axPollTimer = nil
            hotkey.start()
            return
        }
        // Onboarding drives its own permission flow (and suppresses gestures), so
        // don't nag alongside it — dismissOnboarding() re-invokes applyHotkeys().
        guard !isOnboarding else { return }
        // macOS does NOT show a dialog for Input Monitoring ("service does not
        // allow prompting") — this call only registers Nab in the System
        // Settings list with its toggle off. Tell the user where to flip it,
        // once per launch, and poll until they do.
        _ = CGRequestListenEventAccess()
        if !toldUserAboutInputMonitoring {
            toldUserAboutInputMonitoring = true
            showToast(.error, "Gestures need Input Monitoring — enable Nab in System Settings → Privacy & Security")
        }
        axPollTimer?.invalidate()
        axPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard CGPreflightListenEventAccess() else { return }
            self.hotkey.stop()   // recreate the tap now that it's trusted
            self.hotkey.start()
            timer.invalidate()
            self.axPollTimer = nil
        }
    }

    // MARK: - Windows

    @objc private func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(
                rootView: SettingsView().environmentObject(settings).environmentObject(history))
            let window = NSWindow(contentViewController: host)
            window.title = "Nab Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 700, height: 620))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Onboarding is two acts: a transient, click-through "Welcome to Nab"
    /// splash (a gradual fade — it can't block clicks, keys, or the permission
    /// dialogs it leads to), then a regular titled window with the real steps.
    private func showOnboarding() {
        if let existing = onboardingWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        guard splashWindow == nil else { return } // splash already playing
        isOnboarding = true

        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let host = NSHostingController(rootView: WelcomeSplash { [weak self] in
            self?.showOnboardingWindow()
        })
        host.view.frame = frame
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = .clear // no white flash before SwiftUI paints

        let window = NSWindow(contentRect: frame, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.contentViewController = host
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true // pure decoration — never blocks the user
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.setFrame(frame, display: true)
        splashWindow = window
        window.orderFrontRegardless() // show without stealing focus
    }

    /// Second act: the permissions step in a normal, movable, closable window
    /// — so macOS permission dialogs and the rest of the screen stay reachable
    /// while it's up.
    private func showOnboardingWindow() {
        splashWindow?.orderOut(nil)
        splashWindow?.close()
        splashWindow = nil

        let host = NSHostingController(
            rootView: OnboardingView(
                onContinue: { [weak self] in self?.showGestureGuide() },
                onSkip: { [weak self] in self?.completeOnboarding() }
            ).environmentObject(settings))
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Nab"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 560))
        window.center()
        window.delegate = self
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Third act: the interactive gesture walkthrough in a frosted, card-sized
    /// floating overlay (key-capable so the practice taps register; the rest
    /// of the screen stays clickable).
    private func showGestureGuide() {
        let host = NSHostingController(
            rootView: GestureGuideView { [weak self] in
                self?.completeOnboarding()
            }.environmentObject(settings))
        let window = OverlayWindow(contentViewController: host)
        window.styleMask = .borderless
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false // the card draws its own
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.center()
        window.delegate = self
        gestureGuideWindow = window // set BEFORE closing the permissions window,
                                    // so windowWillClose sees the flow continuing
        onboardingWindow?.orderOut(nil)
        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Onboarding is over (finished or skipped): tear down whatever act is up,
    /// mark it done, and bring the global gestures online.
    private func completeOnboarding() {
        settings.hasOnboarded = true
        for window in [onboardingWindow, gestureGuideWindow] {
            window?.orderOut(nil)
            window?.close()
        }
        onboardingWindow = nil
        gestureGuideWindow = nil
        isOnboarding = false
        applyHotkeys()  // start the tap (or begin prompting) now onboarding is done
    }

    /// Catches the onboarding window closing by any route (Finish or the
    /// titlebar close button) so global gestures aren't left suppressed.
    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        if closing === onboardingWindow || closing === gestureGuideWindow {
            if closing === onboardingWindow { onboardingWindow = nil }
            if closing === gestureGuideWindow { gestureGuideWindow = nil }
            // Only end onboarding when nothing else in the flow is still up
            // (Continue closes the permissions window while the guide opens).
            if onboardingWindow == nil && gestureGuideWindow == nil && isOnboarding {
                isOnboarding = false
                applyHotkeys()  // resume global gestures once the flow ends
            }
        }
    }

    @objc private func showOnboardingMenu() { showOnboarding() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func previewToast() {
        showToast(.success, "Screenshot link successfully copied to your clipboard")
    }

    // MARK: - Capture → upload

    @objc private func captureRegion() { capture(shift: false) }

    /// Capture a region and copy the image directly to the clipboard — no upload.
    private func captureToClipboard() {
        let fmt = settings.captureFormat == "jpg" ? "jpg" : "png"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("nab-\(UUID().uuidString).\(fmt)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-i", "-t", fmt, "-o", tmp.path]
        do { try proc.run(); proc.waitUntilExit() } catch {
            showToast(.error, "Capture failed — \(error.localizedDescription)")
            return
        }
        guard let data = try? Data(contentsOf: tmp), !data.isEmpty else { return }
        defer { try? FileManager.default.removeItem(at: tmp) }

        guard let image = NSImage(data: data) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        if settings.soundOnSuccess { NSSound(named: "Glass")?.play() }
        showToast(.success, "Image copied to clipboard")
    }

    /// Capture a region and upload. Holding ⇧ — during the gesture *or* at any
    /// point while selecting the region — copies the raw image link (embeds
    /// inline in Discord); without ⇧ you get the preview-card page link.
    /// (Self-host has a single link, so ⇧ is a no-op there.)
    private func capture(shift: Bool) {
        // Hosting needs only a license key; self-host needs full provider config.
        if !settings.useNabHosting, settings.makeProvider() == nil { openSettings(); return }
        let fmt = settings.captureFormat == "jpg" ? "jpg" : "png"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("nab-\(UUID().uuidString).\(fmt)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-i", "-t", fmt, "-o", tmp.path]
        do { try proc.run(); proc.waitUntilExit() } catch {
            showToast(.error, "Capture failed — \(error.localizedDescription)")
            return
        }
        guard let data = try? Data(contentsOf: tmp), !data.isEmpty else { return } // cancelled

        // Re-sample ⇧ now that the interactive capture is done. The gesture-time
        // flag alone misses the natural habit of holding ⇧ while dragging the
        // region, so honor either. Query the HID state directly — the main run
        // loop was blocked in waitUntilExit(), so NSEvent's cache may be stale.
        let shiftNow = CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
        let raw = shift || shiftNow

        upload(data: data, ext: fmt, origin: .capture, kindLabel: "Screenshot", rawImage: raw) { [weak self] in
            if self?.settings.autoDeleteAfterUpload == true { try? FileManager.default.removeItem(at: tmp) }
        }
    }

    // MARK: - Text highlight share

    @objc private func shareText() { shareText(raw: false) }

    /// Share the current selection. Hosted shares upload the raw text and let
    /// the viewer page render it in a single styled window (selectable, with
    /// syntax highlighting) — no baked-in chrome, so the page doesn't show a
    /// window inside a window. `raw` (⇧ + double-⌃) copies the direct .txt
    /// link instead of the viewer page. Self-host has no viewer page, so it
    /// keeps the styled window image (or plain text when raw).
    private func shareText(raw: Bool) {
        if !settings.useNabHosting, settings.makeProvider() == nil { openSettings(); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let selected = SelectionReader.currentSelectedText()
            DispatchQueue.main.async {
                guard let self else { return }
                guard let text = selected,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.showToast(.error, "No text selected")
                    return
                }
                if self.settings.useNabHosting {
                    self.upload(data: Data(text.utf8), ext: "txt", origin: .text,
                                kindLabel: "Text", rawImage: raw)
                } else if !raw, let png = SnippetImage.renderPNG(text: text) {
                    self.upload(data: png, ext: "png", origin: .text, kindLabel: "Text")
                } else {
                    self.upload(data: Data(text.utf8), ext: "txt", origin: .text, kindLabel: "Text")
                }
            }
        }
    }

    // MARK: - Shared upload path

    private func upload(data: Data, ext: String, origin: UploadOrigin, kindLabel: String,
                        rawImage: Bool = false, onSuccess: (() -> Void)? = nil) {
        if settings.useNabHosting {
            uploadHosted(data: data, ext: ext, origin: origin, kindLabel: kindLabel,
                         rawImage: rawImage, onSuccess: onSuccess)
            return
        }
        guard let provider = settings.makeProvider() else { openSettings(); return }
        let pipeline = UploadPipeline(
            provider: provider,
            uploader: URLSessionUploader(),
            clipboard: ClipboardWriter(),
            namingScheme: settings.namingScheme,
            optimisticThresholdBytes: settings.optimisticCopy ? 5 * 1024 * 1024 : 0
        )
        let item = UploadItem(data: data, fileExtension: ext, origin: origin, isBurner: settings.defaultBurner)
        Task { @MainActor in
            do {
                var rng = SystemRandomNumberGenerator()
                let outcome = try await pipeline.upload(item, using: &rng)
                history.add(url: outcome.url.absoluteString, key: outcome.key,
                            byteSize: data.count, origin: originString(origin))
                if settings.soundOnSuccess { NSSound(named: "Glass")?.play() }
                onSuccess?()
                showToast(.success, "\(kindLabel) link successfully copied to your clipboard")
            } catch {
                NSSound.beep()
                showToast(.error, "Upload failed — \(Self.describe(error))")
            }
        }
    }

    /// Hosted upload path: POST bytes to the Nab web app, copy the returned
    /// share link. Server assigns the unguessable slug and per-link expiry.
    private func uploadHosted(data: Data, ext: String, origin: UploadOrigin, kindLabel: String,
                              rawImage: Bool, onSuccess: (() -> Void)? = nil) {
        guard !settings.nabLicenseKey.isEmpty, let base = URL(string: settings.nabApiBase) else {
            openSettings(); return
        }
        let uploader = NabHostedUploader(apiBase: base)
        let contentType = ContentType.mime(forExtension: ext)
        Task { @MainActor in
            do {
                let outcome = try await uploader.upload(
                    data: data,
                    contentType: contentType,
                    ttlSeconds: settings.nabExpirySeconds,
                    licenseKey: settings.nabLicenseKey
                )
                // ⇧ → raw image link (inline); default → preview-card page link.
                let link = rawImage ? outcome.imageURL : outcome.pageURL
                ClipboardWriter().writeURL(link)
                history.add(url: link.absoluteString, key: outcome.slug,
                            byteSize: data.count, origin: originString(origin))
                if settings.soundOnSuccess { NSSound(named: "Glass")?.play() }
                onSuccess?()
                showToast(.success, "\(kindLabel) link successfully copied to your clipboard")
            } catch {
                NSSound.beep()
                showToast(.error, "Upload failed — \(Self.describe(error))")
            }
        }
    }

    private func originString(_ o: UploadOrigin) -> String {
        switch o { case .capture: return "capture"; case .text: return "text"; case .drop: return "drop" }
    }

    private func showToast(_ kind: ToastKind, _ message: String) {
        let position = ToastPosition(rawValue: settings.toastPosition) ?? .topTrailing
        let cursor = settings.toastFollowCursor ? NSEvent.mouseLocation : nil
        toast.show(kind: kind, message: message, position: position,
                   duration: settings.toastDuration, cursor: cursor)
    }

    private static func describe(_ error: Error) -> String {
        if let e = error as? UploadError { return "server returned HTTP \(e.statusCode)" }
        if let e = error as? URLError {
            switch e.code {
            case .notConnectedToInternet: return "no internet connection"
            case .timedOut: return "the request timed out"
            case .cannotConnectToHost, .cannotFindHost: return "can't reach the storage host"
            default: return e.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
