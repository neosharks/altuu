import AppKit

// Renders the Altuu app icon: a rounded "squircle" with a blue→indigo
// gradient and three overlapping window cards (the switcher stack motif).

func drawIcon(size s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    // Leave a small margin so the squircle isn't clipped.
    let inset = s * 0.06
    let body = rect.insetBy(dx: inset, dy: inset)
    let corner = body.width * 0.225   // macOS-ish continuous corner

    // Background gradient.
    let clip = NSBezierPath(roundedRect: body, xRadius: corner, yRadius: corner)
    clip.addClip()
    let grad = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.42, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.46, green: 0.28, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.62, green: 0.24, blue: 0.86, alpha: 1)
    ])!
    grad.draw(in: body, angle: -60)

    // Soft top sheen.
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.22),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    sheen.draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: 90)

    // Three overlapping window cards, back-to-front.
    func card(_ r: NSRect, alpha: CGFloat) {
        let cr = r.width * 0.12
        let path = NSBezierPath(roundedRect: r, xRadius: cr, yRadius: cr)
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
        // Title bar dots.
        let dot = r.width * 0.05
        let cy = r.maxY - r.height * 0.14
        for i in 0..<3 {
            let cx = r.minX + r.width * 0.12 + CGFloat(i) * dot * 2.4
            let dpath = NSBezierPath(ovalIn: NSRect(x: cx, y: cy, width: dot, height: dot))
            NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.85, alpha: alpha).setFill()
            dpath.fill()
        }
    }

    let cw = body.width * 0.46
    let ch = body.height * 0.40
    let cx = body.midX - cw / 2
    let cy = body.midY - ch / 2
    let off = body.width * 0.07
    card(NSRect(x: cx - off * 1.4, y: cy + off * 1.4, width: cw, height: ch), alpha: 0.35)
    card(NSRect(x: cx + off * 0.2, y: cy + off * 0.2, width: cw, height: ch), alpha: 0.6)
    card(NSRect(x: cx + off * 1.6, y: cy - off * 1.2, width: cw, height: ch), alpha: 1.0)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
// (name, pixel size) pairs for a .iconset.
let specs: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    writePNG(drawIcon(size: px), to: "\(outDir)/\(name).png")
}
print("icon pngs written to \(outDir)")
