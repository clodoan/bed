import AppKit
import SwiftUI

enum Snapshot {
    static var requested: Bool {
        CommandLine.arguments.contains("--snapshot")
    }

    @MainActor
    static func write() async {
        PixelFont.register()
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/readme")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let model = BedModel()
        model.play()
        try? await Task.sleep(for: .seconds(2))

        render(face: .desk, model: model, to: root.appendingPathComponent("desk.png"))
        render(face: .dancer, model: model, to: root.appendingPathComponent("girl.png"))
        print("Wrote \(root.path)")
    }

    @MainActor
    private static func render(face: Face, model: BedModel, to url: URL) {
        UserDefaults.standard.set(face.rawValue, forKey: "lcdFace")
        let view = ContentView(model: model, reduceMotion: true)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            fputs("snapshot failed: \(url.lastPathComponent)\n", stderr)
            return
        }
        let size = image.size
        guard size.width > 1, size.height > 1 else {
            fputs("snapshot empty: \(url.lastPathComponent)\n", stderr)
            return
        }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )
        guard let rep else { return }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            image.draw(in: NSRect(origin: .zero, size: size))
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { return }
        try? png.write(to: url)
        print("  \(url.lastPathComponent) \(Int(size.width))x\(Int(size.height))")
    }
}
