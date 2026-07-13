import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices

enum Pane: String, CaseIterable, Identifiable {
    case general, storage, capture, sharing, notifications, history, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .storage: return "Storage"
        case .capture: return "Capture"
        case .sharing: return "Sharing"
        case .notifications: return "Notifications"
        case .history: return "History"
        case .about: return "About"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .storage: return "internaldrive.fill"
        case .capture: return "camera.viewfinder"
        case .sharing: return "link"
        case .notifications: return "bell.fill"
        case .history: return "clock.arrow.circlepath"
        case .about: return "info.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .general: return Gruv.gray
        case .storage: return Gruv.orange
        case .capture: return Gruv.aqua
        case .sharing: return Gruv.yellow
        case .notifications: return Gruv.green
        case .history: return Gruv.blue
        case .about: return Gruv.fg3
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selection: Pane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 212)
            Rectangle().fill(Gruv.bg2).frame(width: 1)
            detail
        }
        .frame(minWidth: 660, minHeight: 580)
        .background(Gruv.bg0)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Gruv.orange)
                    .frame(width: 24, height: 24)
                    .overlay(Image(systemName: "scissors")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Gruv.bg0h))
                Text("Nab").font(.mono(14, weight: .semibold)).foregroundColor(Gruv.fg0)
                Spacer()
            }
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 8) {
                GroupLabel(text: "Capture & Upload")
                ForEach([Pane.general, .storage, .capture, .sharing, .notifications]) { item($0) }
            }
            VStack(alignment: .leading, spacing: 8) {
                GroupLabel(text: "App")
                item(.history)
                item(.about)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Gruv.bg0h)
    }

    private func item(_ pane: Pane) -> some View {
        let selected = selection == pane
        return Button {
            selection = pane
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(pane.tint)
                    .frame(width: 22, height: 22)
                    .overlay(Image(systemName: pane.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Gruv.bg0h))
                Text(pane.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? Gruv.fg0 : Gruv.fg1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Gruv.bg2 : .clear))
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(symbol: selection.symbol, title: selection.title, tint: selection.tint)
                    .padding(.bottom, 2)
                switch selection {
                case .general: GeneralPane()
                case .storage: StoragePane()
                case .capture: CapturePane()
                case .sharing: SharingPane()
                case .notifications: NotificationsPane()
                case .history: HistoryPane()
                case .about: AboutPane()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Gruv.bg0)
    }
}

// MARK: - Panes

struct GeneralPane: View {
    @EnvironmentObject var settings: AppSettings
    @State private var screenOK = false
    @State private var axOK = false
    @State private var listenOK = false
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToggleRow(title: "Launch at login",
                      subtitle: "Start Nab when you log in",
                      isOn: $settings.launchAtLogin)
            ToggleRow(title: "Optimistic clipboard",
                      subtitle: "Copy the link before the upload finishes",
                      isOn: $settings.optimisticCopy)
            ToggleRow(title: "Sound on success",
                      subtitle: "Play a chime when a link is copied",
                      isOn: $settings.soundOnSuccess)

            GroupLabel(text: "Permissions").padding(.top, 4)
            PermissionRow(icon: "keyboard", tint: Gruv.orange, title: "Input Monitoring",
                          subtitle: "Global gestures — toggle Nab on in the system list.",
                          granted: listenOK, action: requestListen)
            PermissionRow(icon: "hand.tap.fill", tint: Gruv.yellow, title: "Accessibility",
                          subtitle: "Required to read your selected text for sharing.",
                          granted: axOK, action: requestAX)
            PermissionRow(icon: "camera.viewfinder", tint: Gruv.aqua, title: "Screen Recording",
                          subtitle: "Required to capture a screen region.",
                          granted: screenOK, action: requestScreen)

            GroupLabel(text: "Shortcuts").padding(.top, 4)
            ToggleRow(title: "Tap ⌘ twice to capture",
                      subtitle: "Global gesture — needs Input Monitoring permission",
                      isOn: $settings.shortcutEnabled)
            ToggleRow(title: "Tap ⌃ twice to share text",
                      subtitle: "Upload the current text selection as a link",
                      isOn: $settings.textShareEnabled)
            ToggleRow(title: "Hold ⇧ for a raw share",
                      subtitle: "⇧ + ⌃⌃ copies the direct file link instead of the preview page",
                      isOn: $settings.shiftRawShare)
            ToggleRow(title: "Tap ⌘⌃ twice to copy image",
                      subtitle: "Copies the captured image directly — no upload, no link",
                      isOn: $settings.cmdCtrlCopyImage)
            SliderRow(title: "Max gap between taps", value: $settings.doubleCmdGap,
                      range: 150...600, step: 25, valueLabel: "\(Int(settings.doubleCmdGap)) ms")

            GroupLabel(text: "Active in").padding(.top, 4)
            AppFilterSection()
        }
        .onAppear(perform: refreshPermissions)
        .onReceive(poll) { _ in refreshPermissions() }
        // Re-check immediately whenever the Settings window regains key status
        // (e.g. coming back from System Settings after flipping a toggle).
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        let s = CGPreflightScreenCaptureAccess()
        let a = AXIsProcessTrusted()
        let l = CGPreflightListenEventAccess()
        if s != screenOK { screenOK = s }
        if a != axOK { axOK = a }
        if l != listenOK { listenOK = l }
    }

    private func requestListen() {
        // macOS never shows a dialog for Input Monitoring — the request only
        // registers Nab in the list, so always take the user to the pane.
        _ = CGRequestListenEventAccess()
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    private func requestAX() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            NSWorkspace.shared.open(URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    private func requestScreen() {
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
}

/// Where the double-tap gestures fire: everywhere, everywhere-except, or
/// only-in a list of apps. Apps are stored by bundle ID; rows resolve the
/// icon + display name from the installed app when available.
struct AppFilterSection: View {
    @EnvironmentObject var settings: AppSettings

    private let modes = [
        CardOption(id: "all", symbol: "globe", label: "All apps"),
        CardOption(id: "blacklist", symbol: "hand.raised.fill", label: "Exclude list"),
        CardOption(id: "whitelist", symbol: "checklist", label: "Only list"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SegmentedCards(options: modes, selection: $settings.appFilterMode)

            if settings.appFilterMode != "all" {
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        if settings.appFilterList.isEmpty {
                            Text(settings.appFilterMode == "blacklist"
                                 ? "No apps excluded — gestures fire everywhere."
                                 : "No apps listed — gestures fire nowhere. Add one.")
                                .font(.system(size: 11)).foregroundColor(Gruv.gray)
                                .padding(.vertical, 6)
                        }
                        ForEach(settings.appFilterList, id: \.self) { id in
                            appRow(id)
                            if id != settings.appFilterList.last {
                                Rectangle().fill(Gruv.bg2).frame(height: 1)
                            }
                        }
                        Button(action: addApp) {
                            Label("Add App…", systemImage: "plus")
                                .font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.orange)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Gruv.orange.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, settings.appFilterList.isEmpty ? 4 : 10)
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.appFilterMode)
    }

    private func appRow(_ bundleID: String) -> some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
        let icon: NSImage? = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
        return HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 22, height: 22)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 15)).foregroundColor(Gruv.gray)
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.fg1)
                Text(bundleID).font(.mono(10)).foregroundColor(Gruv.gray)
            }
            Spacer()
            Button {
                settings.appFilterList.removeAll { $0 == bundleID }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13)).foregroundColor(Gruv.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Applications"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            if !settings.appFilterList.contains(id) { settings.appFilterList.append(id) }
        }
    }
}

struct NotificationsPane: View {
    @EnvironmentObject var settings: AppSettings
    private let positions = [
        CardOption(id: "topLeading", symbol: "arrow.up.left", label: "Top L"),
        CardOption(id: "topTrailing", symbol: "arrow.up.right", label: "Top R"),
        CardOption(id: "bottomLeading", symbol: "arrow.down.left", label: "Bot L"),
        CardOption(id: "bottomTrailing", symbol: "arrow.down.right", label: "Bot R"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToggleRow(title: "Follow cursor",
                      subtitle: "Show the toast next to the pointer instead of a fixed corner",
                      isOn: $settings.toastFollowCursor)
            GroupLabel(text: "Toast position")
            SegmentedCards(options: positions, selection: $settings.toastPosition)
                .opacity(settings.toastFollowCursor ? 0.4 : 1)
                .disabled(settings.toastFollowCursor)
            SliderRow(title: "Duration", value: $settings.toastDuration,
                      range: 1...4, step: 0.1,
                      valueLabel: String(format: "%.1f s", settings.toastDuration))
            Button {
                NotificationCenter.default.post(name: .nabPreviewToast, object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill").font(.system(size: 11, weight: .semibold))
                    Text("Preview toast").font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundColor(Gruv.green)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Gruv.green.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Gruv.green.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

struct StoragePane: View {
    @EnvironmentObject var settings: AppSettings
    private let kinds = [
        CardOption(id: "r2", symbol: "cloud.fill", label: "R2"),
        CardOption(id: "s3", symbol: "externaldrive.fill", label: "S3"),
        CardOption(id: "b2", symbol: "shippingbox.fill", label: "B2"),
        CardOption(id: "minio", symbol: "server.rack", label: "MinIO"),
    ]
    private let expiries = [
        CardOption(id: "1h", symbol: "clock", label: "1 hour"),
        CardOption(id: "1d", symbol: "clock.fill", label: "1 day"),
        CardOption(id: "7d", symbol: "calendar", label: "7 days"),
        CardOption(id: "30d", symbol: "calendar.circle", label: "30 days"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupLabel(text: "Hosting")
            ToggleRow(title: "Use Nab hosting",
                      subtitle: "Upload to Nab — no bucket setup. Links preview in Discord & Slack.",
                      isOn: $settings.useNabHosting)

            if settings.useNabHosting {
                FieldRow(title: "License key", placeholder: "NB-XXXX-XXXX-XXXX", text: $settings.nabLicenseKey)
                GroupLabel(text: "Link expiry")
                SegmentedCards(options: expiries, selection: $settings.nabExpiry)
                nabStatusCard
            } else {
                GroupLabel(text: "Provider")
                SegmentedCards(options: kinds, selection: $settings.providerKind)

                FieldRow(title: "Endpoint", placeholder: "https://acct.r2.cloudflarestorage.com", text: $settings.endpoint)
                HStack(spacing: 12) {
                    FieldRow(title: "Bucket", placeholder: "shots", text: $settings.bucket)
                    FieldRow(title: "Region", placeholder: "auto", text: $settings.region)
                }
                FieldRow(title: "Access Key ID", placeholder: "AKID…", text: $settings.accessKey)
                FieldRow(title: "Secret Access Key", placeholder: "••••••", secure: true, text: $settings.secretKey)
                FieldRow(title: "Public base (optional)", placeholder: "https://cdn.example.com", text: $settings.publicBase)
                ToggleRow(title: "Path-style addressing",
                          subtitle: "On for R2 / MinIO / B2, off for AWS S3",
                          isOn: $settings.pathStyle)

                statusCard
                devConfigButton
            }
        }
    }

    private var nabStatusCard: some View {
        Card {
            HStack(spacing: 10) {
                Circle().fill(settings.nabLicenseKey.isEmpty ? Gruv.red : Gruv.green).frame(width: 9, height: 9)
                Text(settings.nabLicenseKey.isEmpty
                     ? "Enter your license key to enable hosting"
                     : "Ready — hosted uploads on")
                    .font(.system(size: 12)).foregroundColor(settings.nabLicenseKey.isEmpty ? Gruv.fg3 : Gruv.fg1)
                Spacer()
            }
        }
    }

    private var devConfigButton: some View {
        Button {
            settings.loadLocalDevConfig()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Load local dev config (MinIO)")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("localhost:9000").font(.mono(10)).foregroundColor(Gruv.gray)
            }
            .foregroundColor(Gruv.orange)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Gruv.orange.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Gruv.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var statusCard: some View {
        Card {
            HStack(spacing: 10) {
                Circle().fill(settings.isConfigured ? Gruv.green : Gruv.red).frame(width: 9, height: 9)
                Text(settings.isConfigured ? "Ready to upload" : "Incomplete — fill in endpoint, bucket, and credentials")
                    .font(.system(size: 12)).foregroundColor(settings.isConfigured ? Gruv.fg1 : Gruv.fg3)
                Spacer()
            }
        }
    }
}

struct CapturePane: View {
    @EnvironmentObject var settings: AppSettings
    private let formats = [
        CardOption(id: "png", symbol: "photo.fill", label: "PNG"),
        CardOption(id: "jpg", symbol: "photo", label: "JPEG"),
        CardOption(id: "heic", symbol: "camera.fill", label: "HEIC"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupLabel(text: "Format")
            SegmentedCards(options: formats, selection: $settings.captureFormat)
            ToggleRow(title: "Delete local file after upload",
                      subtitle: "Remove the temp capture once the link is live",
                      isOn: $settings.autoDeleteAfterUpload)
            ToggleRow(title: "Downscale retina @2x → @1x",
                      subtitle: "Smaller files; off keeps exact pixels",
                      isOn: $settings.retinaDownscale)
        }
    }
}

struct SharingPane: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SliderRow(title: "Slug length", value: $settings.slugLength,
                      range: 4...16, step: 1, valueLabel: "\(Int(settings.slugLength)) chars")
            ToggleRow(title: "Date prefix",
                      subtitle: "Prepend yyyy-MM-dd to object keys",
                      isOn: $settings.datePrefix)
            ToggleRow(title: "Burner by default",
                      subtitle: "New shares wait for verify before copying",
                      isOn: $settings.defaultBurner)
        }
    }
}

struct AboutPane: View {
    /// Version from the app bundle (stamped by scripts/package-dmg.sh), so the
    /// About pane can never drift from the shipped build. Dev runs without a
    /// bundle fall back to a recognizable marker.
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(v ?? "dev")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nab").font(.mono(20, weight: .bold)).foregroundColor(Gruv.fg0)
                    Text(version).font(.mono(12)).foregroundColor(Gruv.orange)
                    Text("Nab it. It's already on your clipboard. A menubar capture tool — hosted, or self-hosted to your own bucket.")
                        .font(.system(size: 12)).foregroundColor(Gruv.fg3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Card {
                HStack {
                    Text("We host nothing on the self-host path — bytes go bucket-direct.")
                        .font(.system(size: 11)).foregroundColor(Gruv.gray)
                    Spacer()
                }
            }
        }
    }
}

struct HistoryPane: View {
    @EnvironmentObject var history: UploadHistory

    private static let sizeFmt: ByteCountFormatter = {
        let f = ByteCountFormatter(); f.countStyle = .file; return f
    }()
    private static let dateFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if history.records.isEmpty {
                Card {
                    HStack {
                        Image(systemName: "tray").foregroundColor(Gruv.gray)
                        Text("No uploads yet — your shares will appear here.")
                            .font(.system(size: 12)).foregroundColor(Gruv.fg3)
                        Spacer()
                    }
                }
            } else {
                HStack {
                    GroupLabel(text: "\(history.records.count) item\(history.records.count == 1 ? "" : "s") · stored locally")
                    Spacer()
                    Button { history.clear() } label: {
                        Text("Clear all").font(.system(size: 11, weight: .medium)).foregroundColor(Gruv.red)
                    }.buttonStyle(.plain)
                }
                ForEach(history.records) { row($0) }
            }
        }
    }

    private func row(_ r: UploadRecord) -> some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: symbol(r.origin))
                    .font(.system(size: 13)).foregroundColor(Gruv.blue).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.url).font(.mono(11)).foregroundColor(Gruv.fg0)
                        .lineLimit(1).truncationMode(.middle)
                    Text("\(Self.sizeFmt.string(fromByteCount: Int64(r.byteSize))) · \(Self.dateFmt.localizedString(for: r.createdAt, relativeTo: Date()))")
                        .font(.system(size: 10)).foregroundColor(Gruv.gray)
                }
                Spacer(minLength: 6)
                iconButton("doc.on.doc", Gruv.fg3) {
                    let pb = NSPasteboard.general; pb.clearContents(); pb.setString(r.url, forType: .string)
                }
                iconButton("arrow.up.right.square", Gruv.aqua) {
                    if let u = URL(string: r.url) { NSWorkspace.shared.open(u) }
                }
                iconButton("trash", Gruv.red) { history.delete(r) }
            }
        }
    }

    private func iconButton(_ symbol: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundColor(color)
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Gruv.bg0h))
        }.buttonStyle(.plain)
    }

    private func symbol(_ origin: String) -> String {
        switch origin {
        case "capture": return "camera.viewfinder"
        case "text": return "text.alignleft"
        default: return "doc"
        }
    }
}
