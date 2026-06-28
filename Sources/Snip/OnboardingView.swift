import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    var onFinish: () -> Void
    @State private var step = 0

    private let lastStep = 3

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            footer
        }
        .frame(width: 520, height: 560)
        .background(Gruv.bg0)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: welcome
        case 1: permissions
        case 2: storage
        default: done
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Gruv.orange)
                .frame(width: 76, height: 76)
                .overlay(Image(systemName: "scissors").font(.system(size: 36, weight: .bold)).foregroundColor(Gruv.bg0h))
            Text("Snip").font(.mono(28, weight: .bold)).foregroundColor(Gruv.fg0)
            Text("Snip it. It's already on your clipboard.")
                .font(.system(size: 14)).foregroundColor(Gruv.orange)
            Text("A menubar capture tool that drops a clean link onto your clipboard — to your own bucket. Let's get you set up.")
                .font(.system(size: 13)).foregroundColor(Gruv.fg3)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
            Spacer()
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Permissions", "Snip needs two macOS permissions to work.")
            permissionCard(
                icon: "camera.viewfinder", tint: Gruv.aqua, title: "Screen Recording",
                desc: "To capture a screen region.",
                button: "Open Settings", url: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            permissionCard(
                icon: "hand.tap.fill", tint: Gruv.yellow, title: "Accessibility",
                desc: "For the global double-⌘ / double-⌃ gestures.",
                button: "Open Settings", url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            Text("You can grant these now or later — capture still works from the menubar without the gestures.")
                .font(.system(size: 11)).foregroundColor(Gruv.gray)
            Spacer()
        }
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Connect storage", "Point Snip at a bucket. Use the local dev target to try it instantly, or add your own R2 / S3 bucket in Settings.")
            Button { settings.loadLocalDevConfig() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 12, weight: .semibold))
                    Text("Load local dev config (MinIO)").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("localhost:9000").font(.mono(10)).foregroundColor(Gruv.gray)
                }
                .foregroundColor(Gruv.orange)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Gruv.orange.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Gruv.orange.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Card {
                HStack(spacing: 10) {
                    Circle().fill(settings.isConfigured ? Gruv.green : Gruv.red).frame(width: 9, height: 9)
                    Text(settings.isConfigured ? "Storage ready" : "Not configured yet")
                        .font(.system(size: 12)).foregroundColor(settings.isConfigured ? Gruv.fg1 : Gruv.fg3)
                    Spacer()
                }
            }
            Spacer()
        }
    }

    private var done: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundColor(Gruv.green)
            Text("You're all set").font(.mono(22, weight: .bold)).foregroundColor(Gruv.fg0)
            VStack(alignment: .leading, spacing: 8) {
                tip("Tap ⌘ twice", "capture a region → link copied")
                tip("Tap ⌃ twice", "share selected text → link copied")
                tip("Menubar ✂", "actions + Settings anytime")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Gruv.bg1))
            Spacer()
        }
    }

    // MARK: Pieces

    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.mono(20, weight: .bold)).foregroundColor(Gruv.fg0)
            Text(subtitle).font(.system(size: 13)).foregroundColor(Gruv.fg3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionCard(icon: String, tint: Color, title: String, desc: String, button: String, url: String) -> some View {
        Card {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint).frame(width: 30, height: 30)
                    .overlay(Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(Gruv.bg0h))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Gruv.fg1)
                    Text(desc).font(.system(size: 11)).foregroundColor(Gruv.gray)
                }
                Spacer()
                Button { NSWorkspace.shared.open(URL(string: url)!) } label: {
                    Text(button).font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.orange)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Gruv.orange.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tip(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 10) {
            Text(key).font(.mono(11, weight: .semibold)).foregroundColor(Gruv.fg0)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Gruv.bg2))
            Text(desc).font(.system(size: 12)).foregroundColor(Gruv.fg3)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0...lastStep, id: \.self) { i in
                    Circle().fill(i == step ? Gruv.orange : Gruv.bg3).frame(width: 7, height: 7)
                }
            }
            Spacer()
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain).foregroundColor(Gruv.fg3).font(.system(size: 13))
                    .padding(.horizontal, 12)
            }
            Button(step == lastStep ? "Finish" : "Continue") {
                if step == lastStep { settings.hasOnboarded = true; onFinish() }
                else { step += 1 }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold)).foregroundColor(Gruv.bg0h)
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 9).fill(Gruv.orange))
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Gruv.bg0h)
    }
}
