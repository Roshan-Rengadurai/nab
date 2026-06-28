import AppKit

enum SnippetKind { case terminal, code, prose }

/// Renders shared text into a gruvbox "window" PNG sized to its content.
/// Code/terminal get monospaced VSCode-Gruvbox-hard syntax highlighting (with
/// bold/italic); prose gets clean wrapped text. Every image has mac window chrome.
enum SnippetImage {

    private static let padding: CGFloat = 22
    private static let headerH: CGFloat = 40
    private static let minWidth: CGFloat = 320
    private static let maxWidth: CGFloat = 940

    static func renderPNG(text: String) -> Data? {
        let kind = classify(text)
        let isCode = kind != .prose

        let bodyFont = isCode
            ? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            : NSFont.systemFont(ofSize: 15)
        let body = isCode ? highlighted(text, font: bodyFont) : prose(text, font: bodyFont)

        // Size the card to the content: natural width (clamped), then height.
        let maxContentWidth = maxWidth - padding * 2
        let natural = body.boundingRect(
            with: NSSize(width: maxContentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        let contentWidth = min(maxContentWidth, max(ceil(natural.width), minWidth - padding * 2))
        let measured = body.boundingRect(
            with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        let contentH = max(ceil(measured.height), 20)

        let width = contentWidth + padding * 2
        let height = headerH + padding + contentH + padding
        let size = NSSize(width: width, height: height)

        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = size // must be set BEFORE deriving the context, else drawing uses the wrong space
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        (kind == .terminal ? GruvNS.bg0h : GruvNS.bg0).setFill()
        path.fill()
        GruvNS.bg2.setStroke(); path.lineWidth = 1; path.stroke()
        path.addClip()

        GruvNS.bg1.setFill()
        NSRect(x: 0, y: height - headerH, width: width, height: headerH).fill()
        GruvNS.bg2.setFill()
        NSRect(x: 0, y: height - headerH, width: width, height: 1).fill()

        let cy = height - headerH / 2
        for (i, c) in [GruvNS.tlRed, GruvNS.tlYellow, GruvNS.tlGreen].enumerated() {
            c.setFill()
            NSBezierPath(ovalIn: NSRect(x: padding + CGFloat(i) * 20, y: cy - 6, width: 12, height: 12)).fill()
        }

        let title = kind == .terminal ? "zsh" : (kind == .code ? "snippet" : "note")
        let titleAttr = NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: GruvNS.gray])
        let ts = titleAttr.size()
        titleAttr.draw(at: NSPoint(x: (width - ts.width) / 2, y: cy - ts.height / 2))

        body.draw(with: NSRect(x: padding, y: padding, width: contentWidth, height: contentH),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])

        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Classification

    static func classify(_ s: String) -> SnippetKind {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        var codeScore = 0
        var termScore = 0
        let codeTokens = ["{", "}", ";", "=>", "->", "::", "</", "/>", "def ", "func ",
                          "class ", "import ", "const ", "let ", "var ", "function ",
                          "return ", "#include", "public ", "private ", "=="]
        let shellCmds = ["sudo ", "brew ", "npm ", "npx ", "git ", "cd ", "ls ", "echo ",
                         "curl ", "mkdir ", "rm ", "export ", "cat ", "grep ", "mc ", "minio "]
        for raw in lines {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if ["$ ", "% ", "# ", "> "].contains(where: trimmed.hasPrefix) { termScore += 2 }
            if line.hasPrefix("  ") || line.hasPrefix("\t") { codeScore += 1 }
            for t in codeTokens where line.contains(t) { codeScore += 1 }
            for c in shellCmds where trimmed.hasPrefix(c) { termScore += 1 }
        }
        if termScore >= 2 && termScore >= codeScore { return .terminal }
        if codeScore >= 3 { return .code }
        let punct = s.filter { "{}[]();=<>/*&|".contains($0) }.count
        if !s.isEmpty && Double(punct) / Double(s.count) > 0.06 { return .code }
        return .prose
    }

    // MARK: - Body builders

    private static func prose(_ s: String, font: NSFont) -> NSAttributedString {
        let p = NSMutableParagraphStyle(); p.lineSpacing = 5
        return NSAttributedString(string: s, attributes: [
            .font: font, .foregroundColor: GruvNS.fg1, .paragraphStyle: p])
    }

    /// VSCode Gruvbox-hard inspired highlighting with bold keywords/functions and italic comments.
    private static func highlighted(_ text: String, font: NSFont) -> NSAttributedString {
        let bold = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

        let p = NSMutableParagraphStyle(); p.lineSpacing = 3
        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: GruvNS.fg1, .paragraphStyle: p])
        let full = NSRange(text.startIndex..., in: text)

        func color(_ pattern: String, _ c: NSColor, group: Int = 0, font: NSFont? = nil) {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return }
            re.enumerateMatches(in: text, range: full) { m, _, _ in
                guard let m = m else { return }
                let r = m.range(at: group)
                if r.location == NSNotFound { return }
                attr.addAttribute(.foregroundColor, value: c, range: r)
                if let font { attr.addAttribute(.font, value: font, range: r) }
            }
        }

        // Types (Capitalized identifiers) → yellow
        color("\\b[A-Z][A-Za-z0-9_]*\\b", GruvNS.yellow)
        // Function calls → blue, bold
        color("\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()", GruvNS.blue, group: 1, font: bold)
        // Control keywords → red, bold
        color("\\b(if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|await|async|yield|in|of)\\b", GruvNS.red, font: bold)
        // Declaration / storage keywords → orange
        color("\\b(let|const|var|func|function|def|class|struct|enum|interface|type|import|export|from|as|public|private|protected|static|extends|implements|new|namespace|package)\\b", GruvNS.orange, font: bold)
        // Shell builtins → aqua
        color("\\b(echo|cd|sudo|npm|npx|yarn|git|ls|cat|grep|export|brew|curl|mkdir|rm|cp|mv|mc|minio)\\b", GruvNS.aqua)
        // Constants / booleans → purple
        color("\\b(true|false|null|nil|None|undefined|this|self|super)\\b", GruvNS.purple)
        // Numbers → purple
        color("\\b\\d+(?:\\.\\d+)?\\b", GruvNS.purple)
        // Operators → orange
        color("(=>|===|!==|==|!=|<=|>=|&&|\\|\\||[=+\\-*/%])", GruvNS.orange)

        // Markup (JSX/HTML) — only when it looks like markup
        if text.range(of: "</?[A-Za-z][\\w.-]*[\\s/>]", options: .regularExpression) != nil {
            color("</?([A-Za-z][\\w.-]*)", GruvNS.aqua, group: 1)              // tag name
            color("\\b([A-Za-z_:][\\w:-]*)(?=\\s*=)", GruvNS.yellow, group: 1) // attribute name
        }

        // Strings → green (override tokens inside)
        color("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'|`(?:[^`\\\\]|\\\\.)*`", GruvNS.green)
        // Comments → gray italic (override everything inside)
        color("(?m)(//[^\\n]*|#[^\\n]*)$", GruvNS.gray, font: italic)
        return attr
    }
}
