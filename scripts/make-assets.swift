#!/usr/bin/env swift
// Generates packaging art from the Nab scissors mark, using only AppKit.
//   swift make-assets.swift icon <out.png>        -> 1024x1024 app-icon master
//   swift make-assets.swift background <out.png>   -> 1320x800 DMG background (@2x of a 660x400 window)
//
// Colors are gruvbox (VS Code "Gruvbox Dark Hard"), matching the app + site.

import AppKit

// gruvbox
let orange = NSColor(srgbRed: 0xfe / 255.0, green: 0x80 / 255.0, blue: 0x19 / 255.0, alpha: 1)
let dark = NSColor(srgbRed: 0x1d / 255.0, green: 0x20 / 255.0, blue: 0x21 / 255.0, alpha: 1)
let fg = NSColor(srgbRed: 0xeb / 255.0, green: 0xdb / 255.0, blue: 0xb2 / 255.0, alpha: 1)
let gray = NSColor(srgbRed: 0x92 / 255.0, green: 0x83 / 255.0, blue: 0x74 / 255.0, alpha: 1)

// Render `draw` into an exact `w`x`h` pixel bitmap (independent of screen scale) and write PNG.
func render(_ w: Int, _ h: Int, to path: String, _ draw: () -> Void) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
        FileHandle.standardError.write("failed to alloc bitmap\n".data(using: .utf8)!); exit(1)
    }
    rep.size = NSSize(width: w, height: h) // 1 point == 1 pixel
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    draw()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!); exit(1)
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

// Slightly lighter/warmer orange for the top of the background gradient.
let orangeLight = NSColor(srgbRed: 0xff / 255.0, green: 0x9f / 255.0, blue: 0x40 / 255.0, alpha: 1)

// A superellipse ("squircle") path — the smooth continuous corner Apple uses for
// app icons, rather than a plain circular-corner rounded rect.
func squircle(in rect: NSRect, n: CGFloat = 5) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2 / n), st)
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

// Tint a monochrome/template symbol image to a solid color.
func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    color.set()
    let r = NSRect(origin: .zero, size: image.size)
    image.draw(in: r)
    r.fill(using: .sourceAtop)
    out.unlockFocus()
    out.isTemplate = false
    return out
}

// App icon: an orange squircle carrying the same SF Symbol scissors shown in the
// menu bar — cream, centered, with a soft drop shadow for a modern lift.
func makeIcon(_ path: String) {
    let side = 1024
    render(side, side, to: path) {
        let rect = NSRect(x: 0, y: 0, width: side, height: side)
        let bg = squircle(in: rect)
        NSGradient(colors: [orange, orangeLight])!.draw(in: bg, angle: 90) // base at bottom → lighter at top

        guard let base = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Nab")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 560, weight: .regular)) else {
            FileHandle.standardError.write("scissors symbol unavailable\n".data(using: .utf8)!); exit(1)
        }
        let mark = tinted(base, fg)
        let maxDim = CGFloat(side) * 0.56
        let scale = maxDim / max(mark.size.width, mark.size.height)
        let w = mark.size.width * scale, h = mark.size.height * scale
        let markRect = NSRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(side) * 0.012) // fall downward
        shadow.shadowBlurRadius = CGFloat(side) * 0.02
        shadow.set()
        mark.draw(in: markRect)
    }
}

func makeBackground(_ path: String) {
    // @2x of a 660x400 Finder window.
    let W: CGFloat = 1320, H: CGFloat = 800, s: CGFloat = 2
    render(Int(W), Int(H), to: path) {
        // Work in flipped (top-left origin) space to match Finder layout math.
        let t = NSAffineTransform()
        t.translateX(by: 0, yBy: H)
        t.scaleX(by: 1, yBy: -1)
        t.concat()

        dark.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: H)).fill()

        // Icon centers in 660x400 window coords: app at (165,205), Applications at (495,205).
        let appC = NSPoint(x: 165 * s, y: 205 * s)
        let appsC = NSPoint(x: 495 * s, y: 205 * s)

        // Arrow between the two icons.
        let gap: CGFloat = 78 * s // clear of 128pt icons
        let ax0 = appC.x + gap, ax1 = appsC.x - gap, ay = appC.y
        orange.setStroke()
        let arrow = NSBezierPath()
        arrow.lineWidth = 6 * s
        arrow.lineCapStyle = .round
        arrow.move(to: NSPoint(x: ax0, y: ay))
        arrow.line(to: NSPoint(x: ax1, y: ay))
        arrow.stroke()
        let head = NSBezierPath()
        head.lineWidth = 6 * s
        head.lineCapStyle = .round
        head.lineJoinStyle = .round
        let hl: CGFloat = 16 * s
        head.move(to: NSPoint(x: ax1 - hl, y: ay - hl))
        head.line(to: NSPoint(x: ax1, y: ay))
        head.line(to: NSPoint(x: ax1 - hl, y: ay + hl))
        head.stroke()

        func draw(_ str: String, _ font: NSFont, _ color: NSColor, centerX: CGFloat, top: CGFloat) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let a = NSAttributedString(string: str, attributes: attrs)
            let sz = a.size()
            let ctx = NSGraphicsContext.current!
            ctx.saveGraphicsState()
            // Counter-flip locally so glyphs render upright.
            let f = NSAffineTransform()
            f.translateX(by: 0, yBy: top + sz.height)
            f.scaleX(by: 1, yBy: -1)
            f.concat()
            a.draw(at: NSPoint(x: centerX - sz.width / 2, y: 0))
            ctx.restoreGraphicsState()
        }

        draw("Install Nab", NSFont.systemFont(ofSize: 34 * s, weight: .semibold), fg,
             centerX: W / 2, top: 70 * s)
        draw("Drag the scissors onto Applications", NSFont.systemFont(ofSize: 17 * s, weight: .regular), gray,
             centerX: W / 2, top: 118 * s)
    }
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-assets.swift <icon|background> <out.png>\n".data(using: .utf8)!)
    exit(2)
}
switch args[1] {
case "icon": makeIcon(args[2])
case "background": makeBackground(args[2])
default:
    FileHandle.standardError.write("unknown mode: \(args[1])\n".data(using: .utf8)!)
    exit(2)
}
