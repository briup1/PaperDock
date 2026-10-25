import AppKit

// Match paperdock-icon.svg; vector paths keep every exported size crisp.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}
func draw(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "PaperDockIcon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }
    let transform = AffineTransform(m11: CGFloat(size) / 1024, m12: 0, m21: 0,
        m22: -CGFloat(size) / 1024, tX: 0, tY: CGFloat(size))
    (transform as NSAffineTransform).concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
    guard let gradient = NSGradient(starting: color(67, 139, 250), ending: color(24, 86, 206)) else {
        throw NSError(domain: "PaperDockIcon", code: 2)
    }
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    gradient.draw(from: NSPoint(x: 64, y: 64), to: NSPoint(x: 960, y: 960), options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
    NSGraphicsContext.restoreGraphicsState()
    let p = NSBezierPath()
    p.windingRule = .evenOdd
    p.move(to: NSPoint(x: 330, y: 774))
    p.line(to: NSPoint(x: 330, y: 286))
    p.curve(to: NSPoint(x: 366, y: 250), controlPoint1: NSPoint(x: 330, y: 262), controlPoint2: NSPoint(x: 342, y: 250))
    p.line(to: NSPoint(x: 590, y: 250)); p.line(to: NSPoint(x: 700, y: 360)); p.line(to: NSPoint(x: 700, y: 414))
    p.curve(to: NSPoint(x: 536, y: 578), controlPoint1: NSPoint(x: 700, y: 523), controlPoint2: NSPoint(x: 645, y: 578))
    p.line(to: NSPoint(x: 434, y: 578)); p.line(to: NSPoint(x: 434, y: 774))
    p.curve(to: NSPoint(x: 418, y: 790), controlPoint1: NSPoint(x: 434, y: 785), controlPoint2: NSPoint(x: 429, y: 790))
    p.line(to: NSPoint(x: 346, y: 790))
    p.curve(to: NSPoint(x: 330, y: 774), controlPoint1: NSPoint(x: 335, y: 790), controlPoint2: NSPoint(x: 330, y: 785)); p.close()
    p.move(to: NSPoint(x: 434, y: 354)); p.line(to: NSPoint(x: 434, y: 474)); p.line(to: NSPoint(x: 532, y: 474))
    p.curve(to: NSPoint(x: 596, y: 414), controlPoint1: NSPoint(x: 575, y: 474), controlPoint2: NSPoint(x: 596, y: 454))
    p.curve(to: NSPoint(x: 532, y: 354), controlPoint1: NSPoint(x: 596, y: 374), controlPoint2: NSPoint(x: 575, y: 354)); p.close()
    NSColor.white.setFill(); p.fill()
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 590, y: 250)); fold.line(to: NSPoint(x: 590, y: 328))
    fold.curve(to: NSPoint(x: 622, y: 360), controlPoint1: NSPoint(x: 590, y: 349), controlPoint2: NSPoint(x: 601, y: 360))
    fold.line(to: NSPoint(x: 700, y: 360)); fold.close()
    color(169, 213, 255).setFill(); fold.fill()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PaperDockIcon", code: 3)
    }
    try png.write(to: url, options: .atomic)
}
let iconset = root.appendingPathComponent("PaperDock.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try draw(size: 1024, to: root.appendingPathComponent("paperdock-icon-1024.png"))
for points in [16, 32, 128, 256, 512] {
    try draw(size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try draw(size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
print("Rendered 1024px preview and macOS iconset at \(root.path)")
