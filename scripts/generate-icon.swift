#!/usr/bin/env swift
// Draws the Cowpy app icon and writes every size the asset catalog needs.
//
//   swift scripts/generate-icon.swift            # writes into Cowpy/Assets.xcassets/AppIcon.appiconset
//   swift scripts/generate-icon.swift /some/dir  # writes there instead (for previewing)
//
// The icon is drawn on a 1024 × 1024 canvas following the macOS icon grid: an
// 824 pt rounded square centred on the canvas, with a soft drop shadow.

import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func oval(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat, rotation: CGFloat = 0) -> NSBezierPath {
    let path = NSBezierPath(ovalIn: NSRect(x: -width / 2, y: -height / 2, width: width, height: height))
    var transform = AffineTransform(translationByX: centerX, byY: centerY)
    transform.rotate(byDegrees: rotation)
    path.transform(using: transform)
    return path
}

func drawIcon(in context: CGContext) {
    let outline = color(0x2A2320)
    let outlineWidth: CGFloat = 14

    // MARK: Background tile
    let tileRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: 186, yRadius: 186)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.32).cgColor)
    color(0x7CC7F2).setFill()
    tile.fill()
    context.restoreGState()

    context.saveGState()
    tile.addClip()
    NSGradient(colors: [color(0xBDE6FB), color(0x63B8EE)])?.draw(in: tileRect, angle: 90)
    // Pasture: two rolling hills.
    color(0x6BCB77).setFill()
    oval(centerX: 300, centerY: 60, width: 1100, height: 560).fill()
    color(0x4FB55F).setFill()
    oval(centerX: 800, centerY: 20, width: 1000, height: 520).fill()
    context.restoreGState()

    // MARK: Horns
    color(0xF3E3C3).setFill()
    outline.setStroke()
    for side: CGFloat in [-1, 1] {
        let horn = NSBezierPath()
        horn.move(to: NSPoint(x: 512 + side * 120, y: 735))
        horn.curve(to: NSPoint(x: 512 + side * 235, y: 870),
                   controlPoint1: NSPoint(x: 512 + side * 205, y: 745),
                   controlPoint2: NSPoint(x: 512 + side * 250, y: 800))
        horn.curve(to: NSPoint(x: 512 + side * 185, y: 700),
                   controlPoint1: NSPoint(x: 512 + side * 285, y: 790),
                   controlPoint2: NSPoint(x: 512 + side * 270, y: 700))
        horn.close()
        horn.lineWidth = outlineWidth
        horn.lineJoinStyle = .round
        horn.fill()
        horn.stroke()
    }

    // MARK: Ears
    for side: CGFloat in [-1, 1] {
        let ear = oval(centerX: 512 + side * 262, centerY: 640, width: 210, height: 118, rotation: side * -22)
        (side < 0 ? outline : NSColor.white).setFill()
        ear.lineWidth = outlineWidth
        ear.fill()
        ear.stroke()
        color(0xF6A9B8).setFill()
        oval(centerX: 512 + side * 268, centerY: 638, width: 120, height: 56, rotation: side * -22).fill()
    }

    // MARK: Head
    let headRect = NSRect(x: 300, y: 290, width: 424, height: 480)
    let head = NSBezierPath(roundedRect: headRect, xRadius: 200, yRadius: 200)
    NSColor.white.setFill()
    head.fill()

    // Spots, clipped to the head.
    context.saveGState()
    head.addClip()
    outline.setFill()
    oval(centerX: 335, centerY: 720, width: 250, height: 250, rotation: 20).fill()
    oval(centerX: 715, centerY: 470, width: 150, height: 190, rotation: -15).fill()
    context.restoreGState()

    head.lineWidth = outlineWidth
    head.stroke()

    // MARK: Eyes
    for side: CGFloat in [-1, 1] {
        outline.setFill()
        oval(centerX: 512 + side * 88, centerY: 590, width: 58, height: 70).fill()
        NSColor.white.setFill()
        oval(centerX: 512 + side * 88 + 10, centerY: 606, width: 20, height: 22).fill()
    }

    // Blush
    color(0xF6A9B8, alpha: 0.55).setFill()
    oval(centerX: 372, centerY: 520, width: 70, height: 44).fill()
    oval(centerX: 652, centerY: 520, width: 70, height: 44).fill()

    // MARK: Muzzle
    let muzzle = oval(centerX: 512, centerY: 380, width: 390, height: 250)
    color(0xF9C2CD).setFill()
    muzzle.fill()
    muzzle.lineWidth = outlineWidth
    muzzle.stroke()

    color(0xC9657C).setFill()
    oval(centerX: 442, centerY: 405, width: 46, height: 62, rotation: 12).fill()
    oval(centerX: 582, centerY: 405, width: 46, height: 62, rotation: -12).fill()

    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 452, y: 322))
    smile.curve(to: NSPoint(x: 572, y: 322), controlPoint1: NSPoint(x: 482, y: 288), controlPoint2: NSPoint(x: 542, y: 288))
    smile.lineWidth = 11
    smile.lineCapStyle = .round
    color(0xA8495F).setStroke()
    smile.stroke()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let graphicsContext = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    context.interpolationQuality = .high
    drawIcon(in: context)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let defaultOutput = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Cowpy/Assets.xcassets/AppIcon.appiconset")
let output = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1]) : defaultOutput
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let slots: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for slot in slots {
    let name = "icon_\(slot.points)x\(slot.points)\(slot.scale == 2 ? "@2x" : "").png"
    try render(pixels: slot.points * slot.scale).write(to: output.appendingPathComponent(name))
    images.append([
        "filename": name,
        "idiom": "mac",
        "scale": "\(slot.scale)x",
        "size": "\(slot.points)x\(slot.points)",
    ])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(slots.count) icon sizes to \(output.path)")
