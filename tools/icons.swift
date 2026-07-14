// Generates the menu bar glyph, app icon, and README icon for MAC Address.
// The five connected nodes suggest a network identity without borrowing a logo.
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: icons <resourcesDir> <iconsetDir> [githubDir]\n".utf8))
    exit(1)
}

let resources = URL(fileURLWithPath: args[1])
let iconset = URL(fileURLWithPath: args[2])
let github = args.count >= 4 ? URL(fileURLWithPath: args[3]) : nil
let fm = FileManager.default
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
if let github { try fm.createDirectory(at: github, withIntermediateDirectories: true) }

let nodes: [(CGFloat, CGFloat)] = [(5, 5), (19, 5), (12, 12), (5, 19), (19, 19)]
let edges: [(Int, Int)] = [(0, 2), (1, 2), (2, 3), (2, 4)]

func drawGlyph(size: CGFloat, color: NSColor, fraction: CGFloat) {
    let box = size * fraction
    let origin = (size - box) / 2
    func point(_ node: (CGFloat, CGFloat)) -> NSPoint {
        NSPoint(x: origin + node.0 / 24 * box,
                y: origin + (24 - node.1) / 24 * box)
    }

    let lines = NSBezierPath()
    for edge in edges {
        lines.move(to: point(nodes[edge.0]))
        lines.line(to: point(nodes[edge.1]))
    }
    lines.lineWidth = (1.8 / 24) * box
    lines.lineCapStyle = .round
    color.setStroke()
    lines.stroke()

    let radius = (2.15 / 24) * box
    color.setFill()
    for node in nodes {
        let center = point(node)
        NSBezierPath(ovalIn: NSRect(x: center.x - radius,
                                    y: center.y - radius,
                                    width: radius * 2,
                                    height: radius * 2)).fill()
    }
}

func png(_ image: NSImage) -> Data {
    let width = max(1, Int(image.size.width.rounded()))
    let height = max(1, Int(image.size.height.rounded()))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: width,
                               pixelsHigh: height,
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)!
    rep.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: image.size).fill()
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func menuBarIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    drawGlyph(size: size, color: .black, fraction: 0.94)
    image.unlockFocus()
    return image
}

try png(menuBarIcon(size: 18)).write(to: resources.appendingPathComponent("menubar.png"))
try png(menuBarIcon(size: 36)).write(to: resources.appendingPathComponent("menubar@2x.png"))

func appIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext

    let inset = size * 0.092
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let shape = NSBezierPath(roundedRect: rect,
                             xRadius: rect.width * 0.2237,
                             yRadius: rect.width * 0.2237)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                      blur: size * 0.03,
                      color: NSColor(white: 0, alpha: 0.30).cgColor)
    NSColor.black.setFill()
    shape.fill()
    context.restoreGState()

    NSGradient(colors: [NSColor(white: 0.16, alpha: 1),
                        NSColor(white: 0.04, alpha: 1)])!
        .draw(in: shape, angle: -90)

    context.saveGState()
    shape.addClip()
    NSGradient(colors: [NSColor(white: 1, alpha: 0.10),
                        NSColor(white: 1, alpha: 0)])!
        .draw(in: CGRect(x: rect.minX,
                         y: rect.midY,
                         width: rect.width,
                         height: rect.height / 2), angle: -90)
    context.restoreGState()

    drawGlyph(size: size, color: .white, fraction: 0.60)
    image.unlockFocus()
    return image
}

let variants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, size) in variants {
    try png(appIcon(size: size)).write(to: iconset.appendingPathComponent(name))
}
if let github {
    try png(appIcon(size: 1024)).write(to: github.appendingPathComponent("app-icon.png"))
}

print("icons: menubar.png/@2x + \(variants.count) app-icon variants")
