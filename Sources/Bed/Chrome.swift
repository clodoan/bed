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
    static let glow = Color(red: 0.78, green: 0.88, blue: 0.94)
    static let amber = Color(red: 0.92, green: 0.58, blue: 0.28)
    static let outline = Color(red: 0.06, green: 0.04, blue: 0.03)

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

struct ChassisBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            BedPalette.night
            if !reduceTransparency {
                LampDust()
                    .opacity(0.4)
            }
            LinearGradient(
                colors: [BedPalette.lamp.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxHeight: 18)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }
}

private struct LampDust: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 0xBED_5A15)
            for _ in 0..<28 {
                let x = CGFloat(rng.next()) * size.width
                let y = CGFloat(rng.next()) * size.height
                let warm = rng.next() > 0.45
                let color = warm
                    ? BedPalette.lamp.opacity(0.12 + rng.next() * 0.22)
                    : BedPalette.cream.opacity(0.08 + rng.next() * 0.16)
                context.fill(Path(CGRect(x: x.rounded(), y: y.rounded(), width: 1, height: 1)), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

enum ChromeShape {
    case circle
    case capsule
}

struct ChromeButtonStyle: ButtonStyle {
    var shape: ChromeShape = .capsule
    var isOn: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PixelButtonBody(
            configuration: configuration,
            shape: shape,
            isOn: isOn,
            compact: compact,
            pressed: configuration.isPressed
        )
    }
}

private struct PixelButtonBody: View {
    var configuration: ButtonStyle.Configuration
    var shape: ChromeShape
    var isOn: Bool
    var compact: Bool
    var pressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    private var latched: Bool { pressed || isOn }

    var body: some View {
        configuration.label
            .font(PixelFont.ui(compact ? 7 : 9))
            .foregroundStyle(BedPalette.ink)
            .padding(.horizontal, shape == .circle ? 0 : (compact ? 8 : 10))
            .frame(minHeight: compact ? 22 : 30)
            .background {
                PixelBevel(latched: latched, fill: fill)
            }
            .offset(x: latched ? 1 : 0, y: latched ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.42)
            .animation(.easeOut(duration: 0.08), value: pressed)
            .onHover { hovered = $0 }
    }

    private var fill: Color {
        if isOn { return BedPalette.lamp }
        if hovered && !latched { return BedPalette.cream }
        return BedPalette.walnut
    }
}

private struct PixelBevel: View {
    var latched: Bool
    var fill: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(BedPalette.outline)
                .offset(x: latched ? 0 : 2, y: latched ? 0 : 2)
            Rectangle().fill(fill)
            Rectangle().stroke(BedPalette.outline, lineWidth: 2)
            Rectangle()
                .fill(BedPalette.cream.opacity(latched ? 0.08 : 0.22))
                .frame(height: 2)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 2)
                .padding(.top, 2)
            Rectangle()
                .fill(Color.black.opacity(latched ? 0.18 : 0.22))
                .frame(height: 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
        }
    }
}

struct ModeTab: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    init(_ title: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .textCase(.uppercase)
                .frame(minWidth: 72)
        }
        .buttonStyle(ChromeButtonStyle(isOn: selected, compact: true))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct LCDPanel<Content: View>: View {
    var lit: Bool
    var snow: Double
    var backdrop: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background { well }
            .overlay { frame }
    }

    private var well: some View {
        ZStack {
            Rectangle().fill(BedPalette.outline)
            if let backdrop {
                SceneBackdrop(name: backdrop, dim: lit ? 0.08 : 0.18)
                    .padding(3)
                    .clipped()
            } else {
                Rectangle()
                    .fill(BedPalette.well)
                    .padding(3)
                if lit {
                    Rectangle()
                        .fill(BedPalette.glow.opacity(0.08))
                        .padding(3)
                }
            }
            if snow > 0 {
                PixelSnow()
                    .opacity(snow)
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
    }

    private var frame: some View {
        ZStack {
            Rectangle()
                .stroke(BedPalette.outline, lineWidth: 3)
            Rectangle()
                .stroke(BedPalette.walnutDeep.opacity(0.95), lineWidth: 2)
                .padding(3)
            Rectangle()
                .stroke(BedPalette.lamp.opacity(0.22), lineWidth: 1)
                .padding(5)
                .mask(alignment: .topLeading) {
                    Rectangle().padding(.bottom, 28).padding(.trailing, 40)
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
        HStack(spacing: 5) {
            Text("VIA")
            ForEach(sources) { source in
                if source.id != sources.first?.id {
                    Text("/")
                        .foregroundStyle(BedPalette.cream.opacity(0.18))
                }
                Button(source.name.uppercased()) {
                    openURL(source.supportURL ?? source.homeURL)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BedPalette.cream.opacity(source.id == current.id ? 0.55 : 0.28))
                .accessibilityLabel(accessName(source))
                .accessibilityHint(source.blurb)
            }
        }
        .font(PixelFont.ui(6))
        .foregroundStyle(BedPalette.cream.opacity(0.28))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sources")
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
