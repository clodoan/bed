import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("usage: make-icns <AppIcon.png> <AppIcon.icns>\n", stderr)
    exit(1)
}

let src = URL(fileURLWithPath: args[1])
let icns = URL(fileURLWithPath: args[2])
guard let image = NSImage(contentsOf: src) else {
    fputs("could not read \(src.path)\n", stderr)
    exit(1)
}

let sizes: [(pixels: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let rasterize = { (pixels: Int) -> Data in
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else {
        fatalError("bitmap")
    }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("context")
    }
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("png")
    }
    return png
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("LofiHouse-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for size in sizes {
    try rasterize(size.pixels).write(to: iconset.appendingPathComponent(size.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
