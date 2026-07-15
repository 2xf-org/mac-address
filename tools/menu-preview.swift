// Draws the compact README menu preview with synthetic data only.
// Privacy invariant: this tool must never read from a live network interface.
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: menu-preview <output.png>\n".utf8))
    exit(1)
}

let size = NSSize(width: 598, height: 520)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(x: 14, y: 14, width: 570, height: 492)
let panel = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 0, height: -6)
shadow.set()
NSColor(white: 0.98, alpha: 0.98).setFill()
panel.fill()
NSGraphicsContext.restoreGraphicsState()

NSColor(white: 0.72, alpha: 0.75).setStroke()
panel.lineWidth = 1
panel.stroke()

let primary = NSColor(white: 0.12, alpha: 1)
let secondary = NSColor(white: 0.66, alpha: 1)
let separator = NSColor(white: 0.84, alpha: 1)
let font = NSFont.systemFont(ofSize: 25, weight: .regular)
let boldFont = NSFont.systemFont(ofSize: 25, weight: .semibold)
let detailFont = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .regular)
let exampleAddress = "02:00:00:00:00:01"

func draw(_ text: String,
          x: CGFloat,
          centerY: CGFloat,
          color: NSColor = primary,
          font: NSFont = font,
          alignment: NSTextAlignment = .left,
          width: CGFloat = 460) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    let height = ceil(font.ascender - font.descender)
    NSString(string: text).draw(in: NSRect(x: x,
                                           y: centerY - height / 2 - 1,
                                           width: width,
                                           height: height + 4),
                                withAttributes: attributes)
}

func line(_ y: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 46, y: y))
    path.line(to: NSPoint(x: 552, y: y))
    path.lineWidth = 1.5
    separator.setStroke()
    path.stroke()
}

draw("Wi-Fi (en0)", x: 48, centerY: 466)
draw("›", x: 526, centerY: 466, font: NSFont.systemFont(ofSize: 32, weight: .regular),
     alignment: .right, width: 26)

draw("Current", x: 48, centerY: 414, color: secondary)
draw(exampleAddress, x: 252, centerY: 414, color: secondary,
     font: detailFont, alignment: .right, width: 300)

line(378)

draw("Randomize Address", x: 48, centerY: 344)
draw("Set Address…", x: 48, centerY: 294)
draw("⌘ E", x: 472, centerY: 294, color: secondary, alignment: .right, width: 80)
draw("Profiles", x: 48, centerY: 244)
draw("›", x: 526, centerY: 244, font: NSFont.systemFont(ofSize: 32, weight: .regular),
     alignment: .right, width: 26)
draw("Restore Hardware Address", x: 48, centerY: 194)
draw("Private Wi-Fi Settings…", x: 48, centerY: 144)

line(108)

if let symbol = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil) {
    let configured = symbol.withSymbolConfiguration(.init(pointSize: 20, weight: .semibold)) ?? symbol
    configured.isTemplate = true
    primary.set()
    configured.draw(in: NSRect(x: 48, y: 48, width: 24, height: 24))
}
draw("Quit MAC Address", x: 84, centerY: 61, font: boldFont)
draw("⌘ Q", x: 472, centerY: 61, color: secondary, alignment: .right, width: 80)

image.unlockFocus()

let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                           pixelsWide: Int(size.width),
                           pixelsHigh: Int(size.height),
                           bitsPerSample: 8,
                           samplesPerPixel: 4,
                           hasAlpha: true,
                           isPlanar: false,
                           colorSpaceName: .deviceRGB,
                           bytesPerRow: 0,
                           bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()
image.draw(in: NSRect(origin: .zero, size: size))
NSGraphicsContext.restoreGraphicsState()

let output = URL(fileURLWithPath: args[1])
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try rep.representation(using: .png, properties: [:])!.write(to: output)
print("menu preview: \(output.path)")
