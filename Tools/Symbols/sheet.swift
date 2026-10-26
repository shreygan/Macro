import AppKit

let args = CommandLine.arguments
let bundle = Bundle(path: args[1])!
let output = args[2]
let zoom = args[3] == "zoom"
let names = Array(args.dropFirst(4))

let rows: [(CGFloat, NSFont.Weight)] = [(zoom ? 220 : 100, .regular), (34, .ultraLight), (34, .regular), (34, .black), (17, .regular)]
let colW: CGFloat = zoom ? 320 : 150
let W = Int(colW * CGFloat(names.count) + 40), H = zoom ? 640 : 470
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W * 2, pixelsHigh: H * 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

var y = CGFloat(H) - 20
for (pt, weight) in rows {
    y -= pt * 1.5
    let baseline = y + pt * 0.3
    NSColor(white: 0.88, alpha: 1).setFill()
    NSRect(x: 10, y: baseline, width: CGFloat(W) - 20, height: 0.5).fill()
    for (i, n) in names.enumerated() {
        let custom = NSImage(symbolName: n, bundle: bundle, variableValue: 0)
        let base = custom ?? NSImage(systemSymbolName: n, accessibilityDescription: nil)
        let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: weight)
            .applying(.init(paletteColors: [custom != nil ? .systemBlue : .black]))
        guard let img = base?.withSymbolConfiguration(cfg) else {
            print("missing symbol: \(n)")
            continue
        }
        let x = 20 + CGFloat(i) * colW + (colW - img.size.width) / 2
        img.draw(in: NSRect(x: x, y: baseline - img.alignmentRect.origin.y, width: img.size.width, height: img.size.height))
    }
    y -= 8
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print(output)
