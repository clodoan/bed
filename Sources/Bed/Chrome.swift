import SwiftUI

enum BedPalette {
    static let phosphor = Color(red: 0.52, green: 1.0, blue: 0.46)
    static let phosphorDim = Color(red: 0.16, green: 0.42, blue: 0.18)
    static let well = Color(red: 0.015, green: 0.055, blue: 0.02)
    static let amber = Color(red: 1.0, green: 0.70, blue: 0.22)
    static let steelHi = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let steelMid = Color(red: 0.62, green: 0.63, blue: 0.66)
    static let steelLo = Color(red: 0.28, green: 0.29, blue: 0.32)
}

struct ChassisBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                Color(red: 0.16, green: 0.17, blue: 0.19)
            } else {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.black.opacity(0.12),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            Pinstripes()
                .opacity(reduceTransparency ? 0.16 : 0.32)

            LinearGradient(
                colors: [Color.white.opacity(0.22), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxHeight: 16)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }
}

private struct Pinstripes: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0.5
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 1)
                y += 2
            }
        }
        .allowsHitTesting(false)
    }
}

enum ChromeShape {
    case circle
    case capsule
    case rounded
}

struct ChromeButtonStyle: ButtonStyle {
    var shape: ChromeShape = .capsule
    var isOn: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ChromeButtonBody(
            configuration: configuration,
            shape: shape,
            isOn: isOn,
            compact: compact,
            pressed: configuration.isPressed
        )
    }
}

private struct ChromeButtonBody: View {
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
            .font(.system(size: compact ? 10 : 12, weight: .bold, design: .rounded))
            .foregroundStyle(labelColor)
            .shadow(color: .white.opacity(latched ? 0.08 : 0.28), radius: 0, y: 0.5)
            .shadow(color: .black.opacity(latched ? 0.35 : 0.5), radius: 0, y: latched ? 0 : -0.4)
            .padding(.horizontal, shape == .circle || shape == .rounded ? 0 : (compact ? 10 : 14))
            .frame(
                minWidth: shape == .rounded ? 32 : 0,
                minHeight: compact ? 22 : 32
            )
            .background {
                ChromeSurface(shape: shape, pressed: latched)
            }
            .scaleEffect(pressed ? 0.97 : hovered ? 1.01 : 1)
            .offset(y: pressed ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.1), value: pressed)
            .animation(.easeOut(duration: 0.16), value: hovered)
            .onHover { hovered = $0 }
    }

    private var labelColor: Color {
        Color(red: 0.12, green: 0.12, blue: 0.14).opacity(latched ? 0.62 : 0.86)
    }
}

private struct ChromeSurface: View {
    var shape: ChromeShape
    var pressed: Bool

    var body: some View {
        Group {
            switch shape {
            case .circle:
                layers(Circle())
            case .capsule:
                layers(Capsule())
            case .rounded:
                layers(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .shadow(color: .white.opacity(pressed ? 0 : 0.18), radius: 0, y: 0.6)
        .shadow(color: .black.opacity(pressed ? 0.28 : 0.5), radius: pressed ? 0.6 : 2.2, y: pressed ? 0.6 : 2)
    }

    private func layers<S: InsettableShape>(_ metal: S) -> some View {
        let rim = pressed ? 1.8 : 2.3
        return ZStack {
            metal.fill(chamferGradient)

            metal
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(pressed ? 0.35 : 0.9),
                            Color.black.opacity(pressed ? 0.2 : 0.45),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )

            metal
                .fill(faceGradient)
                .padding(rim)
                .overlay {
                    metal
                        .strokeBorder(innerWell, lineWidth: 0.8)
                        .padding(rim)
                }

            metal
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(pressed ? 0.1 : 0.5), location: 0),
                            .init(color: .white.opacity(0.08), location: 0.32),
                            .init(color: .clear, location: 0.5),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(rim + 0.5)
                .mask(alignment: .top) {
                    metal.padding(.bottom, shape == .circle ? 18 : 16)
                }

            BrushedGrain()
                .opacity(pressed ? 0.16 : 0.24)
                .padding(rim)
                .clipShape(metal)

            metal.stroke(Color.black.opacity(0.62), lineWidth: 0.7)
        }
    }

    private var faceGradient: LinearGradient {
        LinearGradient(
            stops: pressed
                ? [
                    .init(color: Color(red: 0.58, green: 0.59, blue: 0.62), location: 0),
                    .init(color: Color(red: 0.48, green: 0.49, blue: 0.52), location: 0.36),
                    .init(color: Color(red: 0.62, green: 0.63, blue: 0.66), location: 0.7),
                    .init(color: Color(red: 0.74, green: 0.75, blue: 0.78), location: 1),
                ]
                : [
                    .init(color: BedPalette.steelHi, location: 0),
                    .init(color: Color(red: 0.70, green: 0.71, blue: 0.74), location: 0.34),
                    .init(color: BedPalette.steelMid, location: 0.72),
                    .init(color: BedPalette.steelLo, location: 1),
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var chamferGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(pressed ? 0.55 : 1),
                Color(red: 0.72, green: 0.73, blue: 0.76),
                Color(red: 0.22, green: 0.23, blue: 0.26),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var innerWell: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(pressed ? 0.28 : 0.55),
                Color.white.opacity(pressed ? 0.18 : 0.1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct BrushedGrain: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0.5
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                let shade = y.truncatingRemainder(dividingBy: 3) < 1 ? 0.07 : 0.03
                context.stroke(path, with: .color(.white.opacity(shade)), lineWidth: 0.6)
                y += 1
            }
        }
        .allowsHitTesting(false)
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
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
                .textCase(.uppercase)
                .frame(minWidth: 64)
        }
        .buttonStyle(ChromeButtonStyle(isOn: selected, compact: true))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct LCDPanel<Content: View>: View {
    var lit: Bool
    var snow: Double
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background { well }
            .overlay { glass }
            .shadow(color: BedPalette.phosphor.opacity(lit ? 0.18 : 0.04), radius: lit ? 10 : 2)
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(BedPalette.well)
            .overlay {
                if lit {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BedPalette.phosphor.opacity(0.06))
                        .blur(radius: 6)
                }
            }
    }

    private var glass: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            if snow > 0 {
                LCDSnow()
                    .opacity(snow)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            }

            Scanlines()
                .opacity(0.08)
                .clipShape(shape)
                .allowsHitTesting(false)

            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), .clear, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)

            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.75),
                        Color.white.opacity(0.08),
                        Color.black.opacity(0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )

            shape
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
                .blur(radius: 0.6)
                .mask(shape.padding(-1))
                .allowsHitTesting(false)
        }
    }
}

private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 1)
                y += 2
            }
        }
    }
}

private struct LCDSnow: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            Canvas { context, size in
                var generator = SeededRandom(seed: UInt64(timeline.date.timeIntervalSinceReferenceDate * 48))
                for _ in 0..<220 {
                    let x = CGFloat(generator.next()) * size.width
                    let y = CGFloat(generator.next()) * size.height
                    let bright = generator.next()
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                        with: .color(BedPalette.phosphor.opacity(0.15 + bright * 0.55))
                    )
                }
            }
        }
    }
}

struct SpectrumView: View {
    var frame: SpectrumFrame
    var composing: Bool
    var time: TimeInterval
    var reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            if composing {
                drawTuner(context: context, size: size)
                return
            }
            drawWave(context: context, size: size)
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }

    private func drawTuner(context: GraphicsContext, size: CGSize) {
        let x: CGFloat
        if reduceMotion {
            x = size.width * 0.5
        } else {
            let cycle = (sin(time * .pi * 1.4) + 1) * 0.5
            x = 6 + cycle * max(0, size.width - 12)
        }
        var sweep = Path()
        sweep.addRoundedRect(
            in: CGRect(x: x - 4, y: size.height * 0.28, width: 8, height: size.height * 0.44),
            cornerSize: CGSize(width: 2, height: 2)
        )
        context.fill(
            sweep,
            with: .linearGradient(
                Gradient(colors: [
                    BedPalette.phosphor.opacity(0.04),
                    BedPalette.phosphor.opacity(0.7),
                    BedPalette.phosphor.opacity(0.04),
                ]),
                startPoint: CGPoint(x: x - 7, y: 0),
                endPoint: CGPoint(x: x + 7, y: 0)
            )
        )
    }

    private func drawWave(context: GraphicsContext, size: CGSize) {
        let samples = smoothed(frame.wave)
        guard samples.count > 1, frame.hasEnergy else { return }

        let mid = size.height * 0.5
        var hairline = Path()
        hairline.move(to: CGPoint(x: 0, y: mid))
        hairline.addLine(to: CGPoint(x: size.width, y: mid))
        context.stroke(hairline, with: .color(BedPalette.phosphor.opacity(0.1)), lineWidth: 0.5)

        let path = wavePath(samples, size: size)
        var fill = path
        fill.addLine(to: CGPoint(x: size.width, y: mid))
        fill.addLine(to: CGPoint(x: 0, y: mid))
        fill.closeSubpath()
        context.fill(fill, with: .color(BedPalette.phosphor.opacity(0.07)))
        context.stroke(path, with: .color(BedPalette.phosphor.opacity(0.58)), lineWidth: 1)
    }

    private func smoothed(_ wave: [Float]) -> [Float] {
        guard wave.count > 2 else { return wave }
        var out = [Float](repeating: 0, count: wave.count)
        out[0] = wave[0]
        out[wave.count - 1] = wave[wave.count - 1]
        for i in 1..<(wave.count - 1) {
            out[i] = (wave[i - 1] + wave[i] * 2 + wave[i + 1]) * 0.25
        }
        return out
    }

    private func wavePath(_ samples: [Float], size: CGSize) -> Path {
        let mid = size.height * 0.5
        let peak = max(0.14, samples.map { abs($0) }.max() ?? 0.14)
        let amp = size.height * 0.4
        let last = samples.count - 1
        let points: [CGPoint] = samples.enumerated().map { index, sample in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(last),
                y: mid - CGFloat(sample / peak) * amp
            )
        }

        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            let midPoint = CGPoint(
                x: (points[i - 1].x + points[i].x) * 0.5,
                y: (points[i - 1].y + points[i].y) * 0.5
            )
            if i == 1 {
                path.addLine(to: midPoint)
            } else {
                path.addQuadCurve(to: midPoint, control: points[i - 1])
            }
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}

struct MarqueeText: View {
    var text: String
    var running: Bool
    var reduceMotion: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(BedPalette.phosphor)
            .shadow(color: BedPalette.phosphor.opacity(0.35), radius: 3)
            .lineLimit(1)
            .minimumScaleFactor(reduceMotion || !running ? 0.75 : 1)
            .modifier(MarqueeShift(text: text, running: running && !reduceMotion))
    }
}

private struct MarqueeShift: ViewModifier {
    var text: String
    var running: Bool

    func body(content: Content) -> some View {
        if !running || text.count < 18 {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let width = CGFloat(text.count) * 8.2
                let travel = max(40, width)
                let period = max(6, Double(text.count) * 0.28)
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                content
                    .offset(x: -CGFloat(t) * travel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            }
        }
    }
}

struct SourceFooter: View {
    var sources: [Source]
    var current: Source

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 5) {
            Text("via")
            ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                if index > 0 {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.16))
                }
                Button(source.name) {
                    openURL(source.supportURL ?? source.homeURL)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(source.id == current.id ? 0.4 : 0.26))
                .accessibilityLabel(accessName(source))
                .accessibilityHint(source.blurb)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.26))
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
