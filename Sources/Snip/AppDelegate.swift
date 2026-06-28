import AppKit
import SwiftUI
import Combine
import ApplicationServices
import SnipCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    let settings = AppSettings()
    let history = UploadHistory()

    private let toast = ToastController()
    private let hotkey = HotkeyMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var axPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Snip")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let capture = NSMenuItem(title: "Capture Region", action: #selector(captureRegion), keyEquivalent: "2")
        capture.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(capture)
        menu.addItem(NSMenuItem(title: "Share Selected Text", action: #selector(shareText), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Onboarding…", action: #selector(showOnboardingMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Snip", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        // Gestures.
        hotkey.gapProvider = { [weak self] in (self?.settings.doubleCmdGap ?? 300) / 1000 }
        hotkey.onCommandDouble = { [weak self] in
            guard self?.settings.shortcutEnabled == true else { return }
            self?.captureRegion()
        }
        hotkey.onControlDouble = { [weak self] in
            guard self?.settings.textShareEnabled == true else { return }
            self?.shareText()
        }
        Publishers.CombineLatest(settings.$shortcutEnabled, settings.$textShareEnabled)
            .sink { [weak self] _, _ in self?.applyHotkeys() }
            .store(in: &cancellables)

        // Launch at login.
        settings.$launchAtLogin
            .dropFirst()
            .sink { LoginItem.set($0) }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self, selector: #selector(previewToast), name: .snipPreviewToast, object: nil)

        if settings.hasOnboarded {
            if !settings.isConfigured { openSettings() }
        } else {
            showOnboarding()
        }
    }

    // MARK: - Hotkey / Accessibility

    private func applyHotkeys() {
        let wantTap = settings.shortcutEnabled || settings.textShareEnabled
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
            window.title = "Snip Settings"
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
        let host = NSHostingController(
            rootView: OnboardingView(onFinish: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }).environmentObject(settings))
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Snip"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func showOnboardingMenu() { showOnboarding() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func previewToast() {
        showToast(.success, "Screenshot link successfully copied to your clipboard")
    }

    // MARK: - Capture → upload

    @objc private func captureRegion() {
        guard let provider = settings.makeProvider() else { openSettings(); return }
        let fmt = settings.captureFormat == "jpg" ? "jpg" : "png"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("snip-\(UUID().uuidString).\(fmt)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-i", "-t", fmt, "-o", tmp.path]
        do { try proc.run(); proc.waitUntilExit() } catch {
            showToast(.error, "Capture failed — \(error.localizedDescription)")
            return
        }
        guard let data = try? Data(contentsOf: tmp), !data.isEmpty else { return } // cancelled

        upload(data: data, ext: fmt, origin: .capture, kindLabel: "Screenshot") { [weak self] in
            if self?.settings.autoDeleteAfterUpload == true { try? FileManager.default.removeItem(at: tmp) }
        }
    }

    // MARK: - Text highlight share

    @objc private func shareText() {
        guard let provider = settings.makeProvider() else { openSettings(); return }
        _ = provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let selected = SelectionReader.currentSelectedText()
            DispatchQueue.main.async {
                guard let self else { return }
                guard let text = selected,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.showToast(.error, "No text selected")
                    return
                }
                // Render the selection as a styled window image (code/terminal vs prose).
                if let png = SnippetImage.renderPNG(text: text) {
                    self.upload(data: png, ext: "png", origin: .text, kindLabel: "Text")
                } else {
                    self.upload(data: Data(text.utf8), ext: "txt", origin: .text, kindLabel: "Text")
                }
            }
        }
    }

    // MARK: - Shared upload path

    private func upload(data: Data, ext: String, origin: UploadOrigin, kindLabel: String,
                        onSuccess: (() -> Void)? = nil) {
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
