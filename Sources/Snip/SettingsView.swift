import SwiftUI
import AppKit

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
                Text("Snip").font(.mono(14, weight: .semibold)).foregroundColor(Gruv.fg0)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToggleRow(title: "Launch at login",
                      subtitle: "Start Snip when you log in",
                      isOn: $settings.launchAtLogin)
            ToggleRow(title: "Optimistic clipboard",
                      subtitle: "Copy the link before the upload finishes",
                      isOn: $settings.optimisticCopy)
            ToggleRow(title: "Sound on success",
                      subtitle: "Play a chime when a link is copied",
                      isOn: $settings.soundOnSuccess)

            GroupLabel(text: "Shortcuts").padding(.top, 4)
            ToggleRow(title: "Tap ⌘ twice to capture",
                      subtitle: "Global gesture — needs Accessibility permission",
                      isOn: $settings.shortcutEnabled)
            ToggleRow(title: "Tap ⌃ twice to share text",
                      subtitle: "Upload the current text selection as a link",
                      isOn: $settings.textShareEnabled)
            SliderRow(title: "Max gap between taps", value: $settings.doubleCmdGap,
                      range: 150...600, step: 25, valueLabel: "\(Int(settings.doubleCmdGap)) ms")
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
                NotificationCenter.default.post(name: .snipPreviewToast, object: nil)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snip").font(.mono(20, weight: .bold)).foregroundColor(Gruv.fg0)
                    Text("v0.1.0").font(.mono(12)).foregroundColor(Gruv.orange)
                    Text("Snip it. It's already on your clipboard. A menubar capture tool — hosted, or self-hosted to your own bucket.")
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
