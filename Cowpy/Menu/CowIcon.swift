import AppKit

/// The menu-bar glyph: a cow's face, drawn in code so it stays crisp at any
/// scale and needs no image assets. It is a template image, so macOS tints it
/// for light/dark menu bars.
nonisolated enum CowIcon {
    /// Designed on an 18 × 18 point canvas, the standard menu-bar glyph size.
    static let designSize: CGFloat = 18

    static func image(pointSize: CGFloat = designSize) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Cowpy"
        return image
    }

    static func draw(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / designSize, y: rect.height / designSize)

        NSColor.black.set()

        // Horns
        let horns = NSBezierPath()
        horns.lineWidth = 1.5
        horns.lineCapStyle = .round
        horns.move(to: NSPoint(x: 5.6, y: 13.6))
        horns.curve(to: NSPoint(x: 3.6, y: 16.6), controlPoint1: NSPoint(x: 4.2, y: 14.0), controlPoint2: NSPoint(x: 3.5, y: 15.2))
        horns.move(to: NSPoint(x: 12.4, y: 13.6))
        horns.curve(to: NSPoint(x: 14.4, y: 16.6), controlPoint1: NSPoint(x: 13.8, y: 14.0), controlPoint2: NSPoint(x: 14.5, y: 15.2))
        horns.stroke()

        // Ears
        for (center, angle) in [(NSPoint(x: 2.9, y: 10.9), CGFloat(-25)), (NSPoint(x: 15.1, y: 10.9), CGFloat(25))] {
            let ear = NSBezierPath(ovalIn: NSRect(x: -2.4, y: -1.3, width: 4.8, height: 2.6))
            var transform = AffineTransform(translationByX: center.x, byY: center.y)
            transform.rotate(byDegrees: angle)
            ear.transform(using: transform)
            ear.fill()
        }

        // Head
        NSBezierPath(roundedRect: NSRect(x: 3.8, y: 3.2, width: 10.4, height: 11.4), xRadius: 4.6, yRadius: 4.6).fill()

        // Eyes, punched out of the head
        context.setBlendMode(.destinationOut)
        NSBezierPath(ovalIn: NSRect(x: 5.9, y: 9.4, width: 1.9, height: 2.2)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10.2, y: 9.4, width: 1.9, height: 2.2)).fill()

        // Muzzle: punch a gap around it so it reads as a separate shape
        NSBezierPath(ovalIn: NSRect(x: 3.4, y: 0.6, width: 11.2, height: 7.6)).fill()
        context.setBlendMode(.normal)
        NSBezierPath(ovalIn: NSRect(x: 4.3, y: 1.4, width: 9.4, height: 5.8)).fill()

        // Nostrils
        context.setBlendMode(.destinationOut)
        NSBezierPath(ovalIn: NSRect(x: 6.3, y: 3.5, width: 1.6, height: 1.9)).fill()
        NSBezierPath(ovalIn: NSRect(x: 10.1, y: 3.5, width: 1.6, height: 1.9)).fill()
        context.setBlendMode(.normal)
    }
}
