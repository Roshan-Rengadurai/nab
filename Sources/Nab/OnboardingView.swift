import SwiftUI
import AppKit

// MARK: - Overlay window (borderless, key-capable)

/// Borderless window that can still become key so the gesture-guide card's
/// button and its local key monitor receive events.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Welcome splash (transient, click-through, full-screen)

/// A short "Welcome to Nab" moment: a frosted card that fades in gradually
/// with the snipping mark, holds, fades out, then hands off to the windowed
/// onboarding. The hosting window ignores mouse events, so this can never
/// block clicks, typing, or the permission dialogs that follow.
struct WelcomeSplash: View {
    var onDone: () -> Void

    @State private var appeared = false
    @State private var exiting = false

    var body: some View {
        VStack(spacing: 18) {
            SnipMark()
            Text("Welcome to Nab").font(.mono(30, weight: .bold)).foregroundColor(Gruv.fg0)
            Text("Nab it. It's already on your clipboard.")
                .font(.system(size: 14)).foregroundColor(Gruv.orange)
        }
        .padding(.horizontal, 56).padding(.vertical, 44)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Gruv.bg0.opacity(0.86))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 36, y: 14)
        .scaleEffect(exiting ? 1.04 : (appeared ? 1 : 0.92))
        .blur(radius: appeared ? 0 : 8)
        .opacity(exiting ? 0 : (appeared ? 1 : 0))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            // Gradual entrance, a slow settle, not a pop.
            NSSound(named: "Submarine")?.play() // low hum to accompany the fade-in
            withAnimation(.easeOut(duration: 1.2)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeIn(duration: 0.5)) { exiting = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { onDone() }
            }
        }
    }
}

// MARK: - Gesture guide (frosted overlay, after permissions)

/// The interactive shortcut walkthrough as a clean frosted card, same look
/// as the welcome splash, but key-capable so the practice taps register.
/// One big liquid-glass keycap in the middle per gesture (⌘ first, then ⌃):
/// a single tap surfaces "one more time…", a double tap turns the cap green
/// with confetti and advances. Hosted in a card-sized floating window, so the
/// rest of the screen stays clickable while the user builds muscle memory.
struct GestureGuideView: View {
    @EnvironmentObject var settings: AppSettings
    var onDone: () -> Void

    @State private var appeared = false
    @State private var exiting = false

    /// 0 = ⌘ practice, 1 = ⌃ practice.
    @State private var stage = 0
    @State private var cmdDone = false
    @State private var ctrlDone = false
    @State private var oneMoreTime = false
    @State private var hintGeneration = 0
    @State private var confetti = 0
    @State private var monitor: Any?
    @State private var wasDown = false
    @State private var lastTap = Date.distantPast

    private var bothDone: Bool { cmdDone && ctrlDone }
    private var stageDone: Bool { stage == 0 ? cmdDone : ctrlDone }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                practice
                ConfettiBurst().id(confetti)
            }
            .padding(.horizontal, 40).padding(.top, 32).padding(.bottom, 24)
            HStack {
                Text("hold ⇧ while you tap for a raw share")
                    .font(.system(size: 11)).foregroundColor(Gruv.gray)
                Spacer()
                Button(bothDone ? "Done" : "Skip") { finish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(bothDone ? Gruv.bg0h : Gruv.fg3)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 9)
                        .fill(bothDone ? Gruv.green : Gruv.bg2))
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: bothDone)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(Gruv.bg0h.opacity(0.6))
        }
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Gruv.bg0.opacity(0.86))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 36, y: 14)
        .scaleEffect(exiting ? 1.03 : (appeared ? 1 : 0.94))
        .blur(radius: appeared ? 0 : 6)
        .opacity(exiting ? 0 : (appeared ? 1 : 0))
        .padding(40) // room for the shadow inside the borderless window
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            startMonitor()
        }
        .onDisappear(perform: stopMonitor)
        .onExitCommand { finish() }
    }

    // MARK: The practice stage, one big keycap, a line of text above it.

    private var practice: some View {
        VStack(spacing: 22) {
            Text(stage == 0 ? "Tap ⌘ twice quickly to capture a region"
                            : "Now tap ⌃ twice to share your selected text")
                .font(.system(size: 13, weight: .medium)).foregroundColor(Gruv.fg3)
                .id("hint-\(stage)")
                .transition(.opacity)

            GlassKeyCap(symbol: stage == 0 ? "command" : "control", done: stageDone)

            // "one more time…" surfaces after a single tap, then fades.
            Text(stageDone ? "got it" : "one more time…")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(stageDone ? Gruv.green : Gruv.orange)
                .opacity(stageDone || oneMoreTime ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: oneMoreTime)
                .animation(.easeInOut(duration: 0.2), value: stageDone)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: stage)
    }

    // MARK: Tap detection (current stage's modifier only)

    private func startMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handle(event); return event
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard !stageDone, !exiting else { return }
        let target: NSEvent.ModifierFlags = stage == 0 ? .command : .control
        let down = event.modifierFlags.contains(target)
        let gap = max(0.18, settings.doubleCmdGap / 1000)

        if down && !wasDown {
            let now = Date()
            if now.timeIntervalSince(lastTap) <= gap {
                completeStage()
            } else {
                showOneMoreTime(gap: gap)
            }
            lastTap = now
        }
        wasDown = down
    }

    /// First tap of the pair: nudge the user, then fade the nudge if the
    /// double-tap window lapses.
    private func showOneMoreTime(gap: TimeInterval) {
        hintGeneration += 1
        let generation = hintGeneration
        oneMoreTime = true
        DispatchQueue.main.asyncAfter(deadline: .now() + gap + 0.6) {
            if hintGeneration == generation { oneMoreTime = false }
        }
    }

    private func completeStage() {
        oneMoreTime = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if stage == 0 { cmdDone = true } else { ctrlDone = true }
        }
        confetti += 1
        NSSound(named: bothDone ? "Hero" : "Pop")?.play()
        // Let the green + confetti land, then bring in the next keycap.
        if stage == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    stage = 1
                    wasDown = false
                    lastTap = .distantPast
                }
            }
        }
    }

    private func finish() {
        guard !exiting else { return }
        stopMonitor()
        withAnimation(.easeIn(duration: 0.35)) { exiting = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone() }
    }
}

// MARK: - Liquid-glass keycap

/// A big glassy key cap: frosted material with a specular sheen and hairline
/// gradient stroke; turns green with a checkmark once its gesture lands.
private struct GlassKeyCap: View {
    let symbol: String
    let done: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(done ? AnyShapeStyle(Gruv.green) : AnyShapeStyle(.ultraThinMaterial))
            // Specular highlight across the top half.
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(done ? 0.28 : 0.16), .clear],
                                     startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            Image(systemName: done ? "checkmark" : symbol)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(done ? Gruv.bg0h : Gruv.fg0)
                .id(done) // deploys back to macOS 13: swap glyphs with a transition
                .transition(.scale.combined(with: .opacity))
        }
        .frame(width: 160, height: 160)
        .shadow(color: done ? Gruv.green.opacity(0.35) : .black.opacity(0.35), radius: 18, y: 10)
        .scaleEffect(done ? 1.06 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: done)
    }
}

// MARK: - Onboarding (windowed permissions step)

struct OnboardingView: View {
    /// Continue → the gesture-guide overlay takes over.
    var onContinue: () -> Void
    /// Skip → onboarding ends entirely.
    var onSkip: () -> Void

    @State private var screenOK = false
    @State private var axOK = false
    @State private var listenOK = false

    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                permissions
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(30)
                footer
            }
        }
        .frame(minWidth: 560, minHeight: 560)
        .preferredColorScheme(.dark)
        .onAppear(perform: refreshPermissions)
        .onReceive(poll) { _ in refreshPermissions() }
        .onExitCommand { onSkip() } // Esc skips
    }

    // MARK: Steps

    private var permissions: some View {
        let allOK = screenOK && axOK && listenOK
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions").font(.mono(20, weight: .bold)).foregroundColor(Gruv.fg0)
                Text("Three macOS permissions. Grant them here, the status updates live.")
                    .font(.system(size: 13)).foregroundColor(Gruv.fg3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PermissionRow(icon: "keyboard", tint: Gruv.orange, title: "Input Monitoring",
                          subtitle: "For the gestures, toggle Nab on in the list.",
                          granted: listenOK, action: SystemPermissions.requestInputMonitoring)
            PermissionRow(icon: "camera.viewfinder", tint: Gruv.aqua, title: "Screen Recording",
                          subtitle: "To capture a screen region.",
                          granted: screenOK, action: SystemPermissions.requestScreenRecording)
            PermissionRow(icon: "hand.tap.fill", tint: Gruv.yellow, title: "Accessibility",
                          subtitle: "To read your selected text for sharing.",
                          granted: axOK, action: SystemPermissions.requestAccessibility)
            Text(allOK
                 ? "All granted, you're ready for the gestures."
                 : "You can grant later too; capture still works from the menubar.")
                .font(.system(size: 11)).foregroundColor(allOK ? Gruv.green : Gruv.gray)
                .animation(.easeInOut, value: allOK)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Skip") { onSkip() }
                .buttonStyle(.plain).foregroundColor(Gruv.gray).font(.system(size: 13))
                .padding(.horizontal, 12)
            Button("Continue") { onContinue() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Gruv.bg0h)
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9).fill(Gruv.orange))
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Gruv.bg0h.opacity(0.6))
    }

    // MARK: Permissions

    private func refreshPermissions() {
        let s = SystemPermissions.screenRecording
        let a = SystemPermissions.accessibility
        let l = SystemPermissions.inputMonitoring
        guard s != screenOK || a != axOK || l != listenOK else { return }
        // A little audible feedback when a permission flips green, and a
        // brighter chime when the last one lands.
        let newlyGranted = (s && !screenOK) || (a && !axOK) || (l && !listenOK)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            screenOK = s; axOK = a; listenOK = l
        }
        if newlyGranted {
            NSSound(named: s && a && l ? "Glass" : "Tink")?.play()
        }
    }
}

// MARK: - Vsync-animated aurora background

/// Soft drifting color blobs, recomputed every display frame via
/// TimelineView(.animation), i.e. updated at the screen's refresh rate (vsync).
private struct AuroraBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    Gruv.bg0h
                    blob(Gruv.orange, w, h, phase: t * 0.18, ox: 0.30, oy: 0.28, r: 0.55)
                    blob(Gruv.aqua,   w, h, phase: t * 0.13 + 2, ox: 0.72, oy: 0.34, r: 0.50)
                    blob(Gruv.yellow, w, h, phase: t * 0.21 + 4, ox: 0.55, oy: 0.74, r: 0.48)
                    blob(Gruv.red,    w, h, phase: t * 0.11 + 1, ox: 0.22, oy: 0.70, r: 0.42)
                }
                .blur(radius: 90)
                .overlay(Color.black.opacity(0.18)) // settle contrast under the card
            }
        }
        .drawingGroup() // composite the blur once per frame on the GPU
    }

    private func blob(_ color: Color, _ w: CGFloat, _ h: CGFloat,
                      phase: Double, ox: CGFloat, oy: CGFloat, r: CGFloat) -> some View {
        let dx = CGFloat(sin(phase)) * w * 0.10
        let dy = CGFloat(cos(phase * 1.2)) * h * 0.10
        let size = min(w, h) * r
        return Circle()
            .fill(color.opacity(0.38))
            .frame(width: size, height: size)
            .position(x: w * ox + dx, y: h * oy + dy)
    }
}

// MARK: - Animated logo (scissors snipping a dashed line)

private struct SnipMark: View {
    @State private var snip = false
    @State private var pop = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                dashes.opacity(snip ? 0.25 : 1)
                Spacer().frame(width: 76)
                dashes.opacity(snip ? 1 : 0.25)
            }
            .frame(width: 220)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Gruv.orange)
                .frame(width: 76, height: 76)
                .overlay(
                    Image(systemName: "scissors")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Gruv.bg0h)
                        .rotationEffect(.degrees(snip ? -8 : 8)))
                .scaleEffect(pop ? 1 : 0.4)
                .rotationEffect(.degrees(pop ? 0 : -12))
                .shadow(color: Gruv.orange.opacity(0.45), radius: snip ? 18 : 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { pop = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.4)) { snip = true }
        }
    }

    private var dashes: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { _ in
                Capsule().fill(Gruv.bg3).frame(width: 9, height: 3)
            }
        }
    }
}

// MARK: - Confetti

private struct ConfettiBurst: View {
    var count = 26
    @State private var fired = false
    @State private var pieces: [Piece] = []

    private struct Piece: Identifiable {
        let id = UUID()
        let dx: CGFloat, dy: CGFloat, size: CGFloat, rotation: Double, color: Color
    }
    private let palette = [Gruv.orange, Gruv.yellow, Gruv.green, Gruv.aqua, Gruv.blue, Gruv.red]

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.55)
                    .rotationEffect(.degrees(fired ? p.rotation : 0))
                    .offset(x: fired ? p.dx : 0, y: fired ? p.dy : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            pieces = (0..<count).map { _ in
                let angle = Double.random(in: 0..<(2 * .pi))
                let dist = CGFloat.random(in: 70...190)
                return Piece(
                    dx: cos(angle) * dist,
                    dy: sin(angle) * dist - 30,
                    size: .random(in: 6...11),
                    rotation: .random(in: -300...300),
                    color: palette.randomElement()!)
            }
            withAnimation(.easeOut(duration: 0.95)) { fired = true }
        }
    }
}
