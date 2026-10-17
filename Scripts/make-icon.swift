import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func drawIcon(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 186, yRadius: 186)
    NSGradient(starting: color(15, 34, 42), ending: color(41, 79, 83))!.draw(in: tile, angle: 65)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let inset = NSBezierPath(roundedRect: NSRect(x: 102, y: 102, width: 820, height: 820), xRadius: 180, yRadius: 180)
    inset.lineWidth = 2; inset.stroke()
    color(248, 241, 225).setFill()
    for shift in [CGFloat(0), CGFloat(220)] {
        let quote = NSBezierPath()
        quote.move(to: NSPoint(x: 292 + shift, y: 672))
        quote.line(to: NSPoint(x: 432 + shift, y: 672))
        quote.line(to: NSPoint(x: 432 + shift, y: 528))
        quote.curve(to: NSPoint(x: 346 + shift, y: 390), controlPoint1: NSPoint(x: 432 + shift, y: 464), controlPoint2: NSPoint(x: 403 + shift, y: 417))
        quote.line(to: NSPoint(x: 320 + shift, y: 438))
        quote.curve(to: NSPoint(x: 374 + shift, y: 510), controlPoint1: NSPoint(x: 354 + shift, y: 457), controlPoint2: NSPoint(x: 374 + shift, y: 483))
        quote.line(to: NSPoint(x: 292 + shift, y: 510))
        quote.close(); quote.fill()
    }
    color(229, 184, 139).setFill()
    NSBezierPath(roundedRect: NSRect(x: 292, y: 296, width: 360, height: 28), xRadius: 14, yRadius: 14).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for (name, pixels) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
] {
    try drawIcon(pixels: pixels).write(to: destination.appendingPathComponent(name + ".png"))
}
if CommandLine.arguments.count > 2 {
    try drawIcon(pixels: 512).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
if CommandLine.arguments.count > 3 {
    func bigEndian(_ value: Int) -> Data {
        var number = UInt32(value).bigEndian
        return withUnsafeBytes(of: &number) { Data($0) }
    }
    var chunks = Data()
    for (type, pixels) in [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
                           ("ic08", 256), ("ic09", 512), ("ic10", 1024),
                           ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)] {
        let png = drawIcon(pixels: pixels)
        chunks.append(Data(type.utf8)); chunks.append(bigEndian(png.count + 8)); chunks.append(png)
    }
    var icon = Data("icns".utf8)
    icon.append(bigEndian(chunks.count + 8)); icon.append(chunks)
    try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
    guard let loaded = NSImage(contentsOfFile: CommandLine.arguments[3]), loaded.representations.count >= 8 else {
        fatalError("Generated icon cannot be decoded by AppKit")
    }
}
