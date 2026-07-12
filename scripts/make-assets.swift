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

// Draw the scissors, authored in the 32x32 SVG viewBox, at the given scale (points == pixels here).
func drawScissors(scale s: CGFloat) {
    func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }
    dark.setStroke()
    for (a, b) in [((8.0, 5.0), (24.0, 27.0)), ((24.0, 5.0), (8.0, 27.0))] {
        let path = NSBezierPath()
        path.lineWidth = 2.8 * s
        path.lineCapStyle = .round
        path.move(to: P(a.0, a.1))
        path.line(to: P(b.0, b.1))
        path.stroke()
    }
    for c in [(24.0, 27.0), (8.0, 27.0)] {
        let r = 3.8 * s
        let ring = NSBezierPath(ovalIn: NSRect(x: c.0 * s - r, y: c.1 * s - r, width: r * 2, height: r * 2))
        ring.lineWidth = 2.2 * s
        ring.stroke()
    }
    let pr = 2.5 * s
    orange.setFill()
    NSBezierPath(ovalIn: NSRect(x: 16 * s - pr, y: 16 * s - pr, width: pr * 2, height: pr * 2)).fill()
}

func makeIcon(_ path: String) {
    let side = 1024
    render(side, side, to: path) {
        let radius = CGFloat(side) * 7.0 / 32.0
        orange.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
                    xRadius: radius, yRadius: radius).fill()
        // flip so SVG (y-down) coords draw upright
        let t = NSAffineTransform()
        t.translateX(by: 0, yBy: CGFloat(side))
        t.scaleX(by: 1, yBy: -1)
        t.concat()
        drawScissors(scale: CGFloat(side) / 32.0)
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
