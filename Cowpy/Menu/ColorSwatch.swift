import AppKit

/// Recognises CSS-style colour strings so the menu can show what `#ff8800` looks like.
nonisolated enum ColorParser {
    struct RGBA: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double = 1

        var nsColor: NSColor {
            NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }

    /// Accepts `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb(…)` and `rgba(…)`.
    ///
    /// Bare hex without `#` is deliberately not accepted: six-digit numbers are
    /// far more often one-time codes than colours.
    static func parse(_ text: String) -> RGBA? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...40).contains(trimmed.count) else { return nil }

        if trimmed.hasPrefix("#") {
            return parseHex(trimmed.dropFirst())
        }
        return parseFunctional(trimmed.lowercased())
    }

    private static func parseHex(_ digits: Substring) -> RGBA? {
        guard [3, 4, 6, 8].contains(digits.count) else { return nil }
        let values = digits.compactMap(\.hexDigitValue)
        guard values.count == digits.count else { return nil }

        let channels: [Double]
        if digits.count <= 4 {
            // Shorthand: each digit is doubled (#f80 == #ff8800).
            channels = values.map { Double($0 * 17) / 255 }
        } else {
            channels = stride(from: 0, to: values.count, by: 2).map {
                Double(values[$0] * 16 + values[$0 + 1]) / 255
            }
        }
        return RGBA(red: channels[0], green: channels[1], blue: channels[2], alpha: channels.count == 4 ? channels[3] : 1)
    }

    private static func parseFunctional(_ text: String) -> RGBA? {
        guard text.hasSuffix(")") else { return nil }
        let body: Substring
        if text.hasPrefix("rgba(") {
            body = text.dropFirst(5).dropLast()
        } else if text.hasPrefix("rgb(") {
            body = text.dropFirst(4).dropLast()
        } else {
            return nil
        }

        let parts = body.split(whereSeparator: { $0 == "," || $0 == "/" || $0 == " " })
        guard parts.count == 3 || parts.count == 4 else { return nil }

        var channels: [Double] = []
        for part in parts.prefix(3) {
            guard let value = Int(part), (0...255).contains(value) else { return nil }
            channels.append(Double(value) / 255)
        }

        var alpha = 1.0
        if parts.count == 4 {
            let part = parts[3]
            if part.hasSuffix("%"), let percent = Double(part.dropLast()) {
                alpha = percent / 100
            } else if let value = Double(part) {
                alpha = value
            } else {
                return nil
            }
            guard (0...1).contains(alpha) else { return nil }
        }
        return RGBA(red: channels[0], green: channels[1], blue: channels[2], alpha: alpha)
    }
}

nonisolated enum ColorSwatch {
    static func image(for color: ColorParser.RGBA, side: CGFloat = 14) -> NSImage {
        let fill = color.nsColor
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            fill.setFill()
            path.fill()
            // A hairline keeps white and near-background colours visible.
            NSColor.labelColor.withAlphaComponent(0.35).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
    }
}
