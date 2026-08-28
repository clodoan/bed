import AppKit
import CoreText
import SwiftUI

enum BedPalette {
    static let ink = Color(red: 0.10, green: 0.07, blue: 0.05)
    static let night = Color(red: 0.12, green: 0.10, blue: 0.09)
    static let well = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let cream = Color(red: 0.93, green: 0.86, blue: 0.72)
    static let creamDim = Color(red: 0.93, green: 0.86, blue: 0.72).opacity(0.48)
    static let walnut = Color(red: 0.52, green: 0.40, blue: 0.30)
    static let walnutDeep = Color(red: 0.32, green: 0.24, blue: 0.18)
    static let lamp = Color(red: 0.88, green: 0.64, blue: 0.32)
    static let glow = cream
    static let amber = Color(red: 0.92, green: 0.58, blue: 0.28)
    static let outline = Color(red: 0.06, green: 0.04, blue: 0.03)

    static let face = night
    static let faceEdge = Color(red: 0.55, green: 0.48, blue: 0.38)

    static let phosphor = cream
    static let phosphorDim = creamDim
}

enum PixelFont {
    static func register() {
        let names = ["PressStart2P-Regular"]
        for name in names {
            if let url = PixelAsset.url(name, ext: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    static func ui(_ size: CGFloat) -> Font {
        .custom("Press Start 2P", size: size)
    }
}

enum PixelAsset {
    static func url(_ name: String, ext: String = "png") -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        let file = "\(name).\(ext)"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(file),
            Bundle.main.resourceURL?.appendingPathComponent("dancer/\(file)"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/\(file)"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/dancer/\(file)"),
        ]
        return candidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    static func nsImage(_ name: String) -> NSImage? {
        url(name).flatMap { NSImage(contentsOf: $0) }
    }
}

struct LCDPanel<Content: View>: View {
    var lit: Bool
    var snow: Double
    var backdrop: String? = nil
    @ViewBuilder var content: () -> Content

    private let lip: CGFloat = 7

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background { well }
            .overlay { bezel }
    }

    private var well: some View {
        ZStack {
            Rectangle().fill(BedPalette.well)
            glass
                .padding(lip)
                .clipped()
        }
    }

    private var glass: some View {
        ZStack {
            if let backdrop {
                SceneBackdrop(name: backdrop, dim: lit ? 0.10 : 0.22)
            } else {
                Rectangle().fill(BedPalette.outline)
            }
            RetroScreen(lit: lit)
            if snow > 0 {
                PixelSnow()
                    .opacity(snow)
            }
        }
        .allowsHitTesting(false)
    }

    private var bezel: some View {
        ZStack {
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            Rectangle()
                .stroke(BedPalette.outline.opacity(0.9), lineWidth: 1)
                .padding(lip)
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .padding(lip - 1)
        }
        .allowsHitTesting(false)
    }
}

private struct RetroScreen: View {
    var lit: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(BedPalette.cream.opacity(lit ? 0.07 : 0.03))
                .blendMode(.softLight)
            Scanlines()
                .opacity(lit ? 0.55 : 0.38)
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(lit ? 0.10 : 0.05), location: 0),
                    .init(color: Color.white.opacity(0.02), location: 0.16),
                    .init(color: .clear, location: 0.38),
                    .init(color: Color.black.opacity(0.28), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.22)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 220
            )
        }
        .allowsHitTesting(false)
    }
}

private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 2
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(BedPalette.outline.opacity(0.28))
                )
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PixelSnow: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 16)) { timeline in
            Canvas { context, size in
                var generator = SeededRandom(seed: UInt64(timeline.date.timeIntervalSinceReferenceDate * 32))
                for _ in 0..<80 {
                    let x = (CGFloat(generator.next()) * size.width).rounded()
                    let y = (CGFloat(generator.next()) * size.height).rounded()
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(BedPalette.lamp.opacity(0.16 + generator.next() * 0.38))
                    )
                }
            }
        }
    }
}

/// Original pajama sprite. Proportions follow the Life Be pixel-art character tutorial
/// (equal head and body height, 3/4 view, 1px outline):
/// https://lifebe.com.au/artistic/pixel-art-tutorial-new-female-character-part-1/
struct DancerView: View {
    var playing: Bool
    var making: Bool
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 5.0, paused: reduceMotion || (!playing && !making))) { context in
            ZStack {
                Ellipse()
                    .fill(BedPalette.outline.opacity(0.35))
                    .frame(width: 72, height: 10)
                    .offset(y: 62)
                PixelImage(frameName(at: context.date))
                    .frame(height: 148)
            }
            .frame(maxWidth: .infinity, minHeight: 156)
        }
        .accessibilityLabel(playing ? "Character dancing" : (making ? "Character waiting" : "Character idle"))
    }

    private func frameName(at date: Date) -> String {
        if reduceMotion {
            return playing || making ? "dance-01" : "idle"
        }
        if making {
            return Int(date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? "idle" : "dance-03"
        }
        if playing {
            let frames = (1...16).map { String(format: "dance-%02d", $0) }
            let index = Int(date.timeIntervalSinceReferenceDate * 5) % frames.count
            return frames[index]
        }
        return "idle"
    }
}

struct PixelImage: View {
    var name: String

    init(_ name: String) {
        self.name = name
    }

    var body: some View {
        if let image = PixelAsset.nsImage(name) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Text("🛏️")
                .font(.system(size: 44))
        }
    }
}

private struct SceneBackdrop: View {
    var name: String
    var dim: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = PixelAsset.nsImage(name) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height,
                            alignment: .trailing
                        )
                        .clipped()
                } else {
                    Rectangle().fill(BedPalette.well)
                }
                Rectangle()
                    .fill(Color.black.opacity(dim))
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.28), location: 0),
                        .init(color: .clear, location: 0.24),
                        .init(color: .clear, location: 0.62),
                        .init(color: .black.opacity(0.32), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct MarqueeText: View {
    var text: String
    var running: Bool
    var reduceMotion: Bool

    var body: some View {
        Text(text)
            .font(PixelFont.ui(9))
            .foregroundStyle(BedPalette.cream)
            .lineLimit(1)
            .minimumScaleFactor(reduceMotion || !running ? 0.7 : 1)
            .modifier(MarqueeShift(text: text, running: running && !reduceMotion))
    }
}

private struct MarqueeShift: ViewModifier {
    var text: String
    var running: Bool

    func body(content: Content) -> some View {
        if !running || text.isEmpty {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    content
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset(at: timeline.date, container: geo.size.width))
                        .frame(width: geo.size.width, alignment: .leading)
                }
            }
            .clipped()
        }
    }

    private func offset(at date: Date, container: CGFloat) -> CGFloat {
        let textWidth = measuredWidth()
        let hold = 1.4
        let leave = textWidth + 12
        let enter = container + 12
        let travel = max(80, leave + enter)
        let moveDuration = Double(travel) / 34
        let period = hold + moveDuration
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        if elapsed < hold {
            return 0
        }
        let distance = CGFloat((elapsed - hold) / moveDuration) * travel
        if distance <= leave {
            return -distance
        }
        return enter - (distance - leave)
    }

    private func measuredWidth() -> CGFloat {
        let font = NSFont(name: "Press Start 2P", size: 9)
            ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

struct SourceFooter: View {
    var sources: [Source]
    var current: Source

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    Text("VIA")
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        if index > 0 {
                            Text("/")
                                .foregroundStyle(BedPalette.cream.opacity(0.18))
                        }
                        Button(source.name.uppercased()) {
                            openURL(source.supportURL ?? source.homeURL)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BedPalette.cream.opacity(source.id == current.id ? 0.62 : 0.28))
                        .accessibilityLabel(accessName(source))
                        .accessibilityHint(source.blurb)
                        .id(source.id)
                    }
                }
                .font(PixelFont.ui(6))
                .foregroundStyle(BedPalette.cream.opacity(0.28))
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 28)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .onAppear { scroll(to: current.id, in: proxy) }
            .onChange(of: current.id) { _, id in
                scroll(to: id, in: proxy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sources")
    }

    private func scroll(to id: String, in proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.28)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func accessName(_ source: Source) -> String {
        if source.supportURL != nil {
            return "\(source.supportLabel) to \(source.name)"
        }
        return "Open \(source.name)"
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z % 10_000) / 10_000
    }
}
