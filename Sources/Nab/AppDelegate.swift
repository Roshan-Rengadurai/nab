import AppKit
import SwiftUI
import Combine
import ApplicationServices
import NabCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    /// While the onboarding window is up, global gestures are suppressed so the
    /// interactive "try it" step can practice locally without screencapture /
    /// Settings stealing focus.
    private var isOnboarding = false
    let settings = AppSettings()
    let history = UploadHistory()

    private let toast = ToastController()
    private let hotkey = HotkeyMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var axPollTimer: Timer?

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
            guard let self, !self.isOnboarding, self.settings.shortcutEnabled else { return }
            self.capture(shift: shiftHeld)
        }
        hotkey.onControlDouble = { [weak self] shiftHeld in
            guard let self, !self.isOnboarding, self.settings.textShareEnabled else { return }
            // ⇧ rides along to skip the styled window — when the setting allows it.
            let raw = shiftHeld && self.settings.shiftRawShare
            self.shareText(raw: raw)
        }
        hotkey.onCommandControlDouble = { [weak self] in
            guard let self, !self.isOnboarding, self.settings.cmdCtrlCopyImage else { return }
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
            if !settings.isConfigured { openSettings() }
        } else {
            showOnboarding()
        }
    }

    // MARK: - Hotkey / Accessibility

    private func applyHotkeys() {
        let wantTap = settings.shortcutEnabled || settings.textShareEnabled || settings.cmdCtrlCopyImage
        guard wantTap else { hotkey.stop(); axPollTimer?.invalidate(); return }
        if hotkey.start() { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        axPollTimer?.invalidate()
        axPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.hotkey.start() { timer.invalidate() }
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

    private func showOnboarding() {
        if let existing = onboardingWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let host = NSHostingController(
            rootView: OnboardingView(onFinish: { [weak self] in
                self?.dismissOnboarding()
            }).environmentObject(settings))
        host.view.frame = frame
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = .clear // no white flash before SwiftUI paints

        // Borderless full-screen overlay (not the settings GUI). The SwiftUI
        // content paints its own aurora + frosted card; the window is just a
        // transparent, key-capable canvas floating above everything — including
        // the menu bar — so the whole process reads as an overlay, not a window.
        let window = OverlayWindow(contentRect: frame, styleMask: .borderless,
                                   backing: .buffered, defer: false)
        window.contentViewController = host
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.delegate = self
        window.setFrame(frame, display: true)
        onboardingWindow = window
        isOnboarding = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func dismissOnboarding() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow?.close()
        onboardingWindow = nil
        isOnboarding = false
    }

    /// Catches the onboarding window closing by any route (Finish or the
    /// titlebar close button) so global gestures aren't left suppressed.
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === onboardingWindow {
            onboardingWindow = nil
            isOnboarding = false
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

    /// Capture a region and upload. Holding ⇧ during the gesture copies the raw
    /// image link (embeds inline in Discord); without ⇧ you get the preview-card
    /// page link. (Self-host has a single link, so ⇧ is a no-op there.)
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

        upload(data: data, ext: fmt, origin: .capture, kindLabel: "Screenshot", rawImage: shift) { [weak self] in
            if self?.settings.autoDeleteAfterUpload == true { try? FileManager.default.removeItem(at: tmp) }
        }
    }

    // MARK: - Text highlight share

    @objc private func shareText() { shareText(raw: false) }

    /// Share the current selection. `raw` skips the styled window image and
    /// uploads the plain text instead (⇧ + double-⌃).
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
                // Render the selection as a styled window image (code/terminal vs prose),
                // unless the user asked for a raw share by holding ⇧.
                if !raw, let png = SnippetImage.renderPNG(text: text) {
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
