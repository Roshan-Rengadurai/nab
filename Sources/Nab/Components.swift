import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices

// MARK: - System permissions

/// The three macOS permissions Nab needs, with live status + a request that
/// falls back to opening the right Privacy pane. Shared by onboarding and
/// Settings so the logic and deep-links live in exactly one place.
enum SystemPermissions {
    static var inputMonitoring: Bool { CGPreflightListenEventAccess() }
    static var accessibility: Bool { AXIsProcessTrusted() }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    private static func openPane(_ anchor: String) {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }

    /// macOS never shows a dialog for Input Monitoring, the request only
    /// registers Nab in the list, so always take the user to the pane.
    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openPane("Privacy_ListenEvent")
    }

    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) { openPane("Privacy_Accessibility") }
    }

    static func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() { openPane("Privacy_ScreenCapture") }
    }
}

// MARK: - Detail pane header (icon chip + title)

struct PaneHeader: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Gruv.bg0h)
                )
            Text(title)
                .font(.mono(17, weight: .semibold))
                .foregroundColor(Gruv.fg0)
            Spacer()
        }
    }
}

// MARK: - Card container

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Gruv.bg1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Gruv.bg2, lineWidth: 1)
            )
    }
}

// MARK: - Toggle row

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Gruv.fg1)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundColor(Gruv.gray)
                    }
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Gruv.orange)
            }
        }
    }
}

// MARK: - Text field row

struct FieldRow: View {
    let title: String
    var placeholder: String = ""
    var secure: Bool = false
    @Binding var text: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.fg3)
                Group {
                    if secure { SecureField(placeholder, text: $text) }
                    else { TextField(placeholder, text: $text) }
                }
                .textFieldStyle(.plain)
                .font(.mono(12))
                .foregroundColor(Gruv.fg0)
                .padding(.vertical, 7)
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: 7).fill(Gruv.bg0h))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Gruv.bg2, lineWidth: 1))
            }
        }
    }
}

// MARK: - Folder picker row

/// A card showing the currently chosen folder with a button that opens an
/// NSOpenPanel. Selecting the folder in the panel is also what grants Nab
/// access to it, so protected locations (Desktop, Documents) work without a
/// separate permission prompt.
struct FolderRow: View {
    let title: String
    var subtitle: String? = nil
    let path: String
    let onPick: (URL) -> Void

    var body: some View {
        Card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Gruv.fg1)
                    Text(path).font(.mono(11)).foregroundColor(Gruv.fg3)
                        .lineLimit(1).truncationMode(.head)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundColor(Gruv.gray)
                    }
                }
                Spacer(minLength: 8)
                Button(action: pick) {
                    Text("Choose…").font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.orange)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Gruv.orange.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.title = "Choose Save Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onPick(url)
    }
}

// MARK: - Segmented card picker (the White / Accent / Decibel style)

struct CardOption: Identifiable, Equatable {
    let id: String
    let symbol: String
    let label: String
}

struct SegmentedCards: View {
    let options: [CardOption]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { opt in
                let selected = opt.id == selection
                Button {
                    selection = opt.id
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: opt.symbol)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selected ? Gruv.orange : Gruv.fg3)
                        Text(opt.label)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .foregroundColor(selected ? Gruv.fg0 : Gruv.fg3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? Gruv.orange.opacity(0.12) : Gruv.bg1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selected ? Gruv.orange : Gruv.bg2, lineWidth: selected ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Slider row with value chip (the Duration style)

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Gruv.fg1)
                    Spacer()
                    Text(valueLabel)
                        .font(.mono(11, weight: .medium))
                        .foregroundColor(Gruv.fg0)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Gruv.bg0h))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Gruv.bg2, lineWidth: 1))
                }
                Slider(value: $value, in: range, step: step)
                    .tint(Gruv.orange)
            }
        }
    }
}

// MARK: - Permission status row (live Accessibility / Screen Recording state)

/// A card that reflects a macOS permission's live state: an icon chip, title,
/// and either a green "Granted" badge or a "Grant" button. Shared by onboarding
/// and Settings so both render identically.
struct PermissionRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Card {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(granted ? Gruv.green : tint)
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: granted ? "checkmark" : icon)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Gruv.bg0h))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Gruv.fg1)
                    Text(granted ? "Granted" : subtitle)
                        .font(.system(size: 11)).foregroundColor(granted ? Gruv.green : Gruv.gray)
                }
                Spacer()
                if granted {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Gruv.green).font(.system(size: 18))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button(action: action) {
                        Text("Grant").font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.orange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Gruv.orange.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(granted ? Gruv.green.opacity(0.5) : .clear, lineWidth: 1.5))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: granted)
    }
}

// MARK: - Section label above a group of cards

struct GroupLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(Gruv.gray)
            .padding(.leading, 2)
    }
}
