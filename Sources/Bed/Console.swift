import SwiftUI

// The popover is a portable clamshell arcade console, opened flat: a wooden case
// holding an ivory lid (screen, speaker grille, tuning dial) hinged above an ivory
// deck (joystick, arcade buttons, power lamp). Everything here is the hardware; the
// screen contents and station model live in ContentView.

/// Outer wooden case: grain, edge bevel, brass corner screws, and a strap tab.
struct WoodenCase<Content: View>: View {
    var lit: Bool
    @ViewBuilder var content: () -> Content

    private let radius: CGFloat = 16

    var body: some View {
        content()
            .padding(14)
            .background { grain }
            .overlay { edge }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { screws }
            .overlay(alignment: .top) { StrapTab().offset(y: 4) }
    }

    private var grain: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BedPalette.caseWoodLit,
                        BedPalette.caseWood,
                        BedPalette.caseWoodDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                WoodGrain()
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .opacity(0.5)
            }
    }

    private var edge: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(BedPalette.caseWoodDark, lineWidth: 2)
            .overlay {
                RoundedRectangle(cornerRadius: radius - 2, style: .continuous)
                    .strokeBorder(BedPalette.caseWoodLit.opacity(0.5), lineWidth: 1)
                    .padding(2)
            }
            .allowsHitTesting(false)
    }

    private var screws: some View {
        ZStack {
            BrassScrew(lit: lit).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            BrassScrew(lit: lit).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            BrassScrew(lit: lit).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            BrassScrew(lit: lit).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(7)
        .allowsHitTesting(false)
    }
}

private struct WoodGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 0xB0A_2D)
            let lines = Int(size.width / 5)
            for _ in 0..<lines {
                let x = (CGFloat(rng.next()) * size.width).rounded()
                let width = 1 + CGFloat(rng.next()) * 1.5
                let wobble = CGFloat(rng.next()) * 6 - 3
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: x + wobble, y: size.height),
                    control: CGPoint(x: x + wobble * 2, y: size.height * 0.5)
                )
                let dark = rng.next() > 0.5
                let color = dark
                    ? BedPalette.caseWoodDark.opacity(0.10 + rng.next() * 0.18)
                    : BedPalette.caseWoodLit.opacity(0.06 + rng.next() * 0.12)
                context.stroke(path, with: .color(color), lineWidth: width)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BrassScrew: View {
    var lit: Bool

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [lit ? BedPalette.brassLit : BedPalette.brass, BedPalette.brassDeep],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: 6
                )
            )
            .frame(width: 9, height: 9)
            .overlay {
                Rectangle()
                    .fill(BedPalette.brassDeep)
                    .frame(width: 5, height: 1.4)
                    .rotationEffect(.degrees(35))
            }
            .overlay(Circle().strokeBorder(BedPalette.caseWoodDark.opacity(0.6), lineWidth: 0.75))
    }
}

private struct StrapTab: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BedPalette.brass, BedPalette.brassDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 34, height: 7)
            .overlay {
                Capsule()
                    .fill(BedPalette.caseWoodDark.opacity(0.7))
                    .frame(width: 12, height: 2.5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(BedPalette.brassDeep.opacity(0.7), lineWidth: 0.75)
            )
    }
}

/// Ivory face plate. Used for both the lid and the deck.
struct FacePanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BedPalette.face, BedPalette.faceShade],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(BedPalette.faceEdge, lineWidth: 1)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.4))
                            .frame(height: 1)
                            .padding(.horizontal, 6)
                            .padding(.top, 1)
                    }
                    .allowsHitTesting(false)
            }
    }
}

/// Dot-matrix speaker grille punched into the face.
struct SpeakerGrille: View {
    var columns: Int = 6
    var rows: Int = 8

    var body: some View {
        Canvas { context, size in
            let gapX = size.width / CGFloat(columns)
            let gapY = size.height / CGFloat(rows)
            let dot: CGFloat = min(gapX, gapY) * 0.5
            for row in 0..<rows {
                for col in 0..<columns {
                    let x = gapX * (CGFloat(col) + 0.5) - dot / 2
                    let y = gapY * (CGFloat(row) + 0.5) - dot / 2
                    let rect = CGRect(x: x, y: y, width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(BedPalette.faceEdge.opacity(0.85)))
                    context.fill(
                        Path(ellipseIn: rect.insetBy(dx: dot * 0.28, dy: dot * 0.28)),
                        with: .color(BedPalette.outline.opacity(0.85))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Tuning knob whose pointer rotates to the current station, with a tick ring.
struct TuningDial: View {
    var index: Int
    var count: Int
    var lit: Bool

    private var angle: Angle {
        guard count > 1 else { return .degrees(-135) }
        let span = 270.0
        let step = span / Double(count - 1)
        return .degrees(-135 + step * Double(index))
    }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? (lit ? BedPalette.brassLit : BedPalette.brass) : BedPalette.faceEdge)
                    .frame(width: 1.6, height: 4)
                    .offset(y: -17)
                    .rotationEffect(tick(i))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [BedPalette.face, BedPalette.faceShade],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(BedPalette.faceEdge, lineWidth: 1))
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(lit ? BedPalette.brassLit : BedPalette.brassDeep)
                        .frame(width: 2.4, height: 9)
                        .padding(.top, 2)
                }
                .rotationEffect(angle)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: index)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private func tick(_ i: Int) -> Angle {
        guard count > 1 else { return .degrees(0) }
        let span = 270.0
        return .degrees(-135 + span / Double(count - 1) * Double(i))
    }
}

/// Brass hinge line between the two halves — the "it opens" tell.
struct HingeBar: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [BedPalette.brass, BedPalette.brassDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 5)
            HStack(spacing: 90) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [BedPalette.brassLit, BedPalette.brassDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 26, height: 9)
                        .overlay(Capsule().strokeBorder(BedPalette.brassDeep.opacity(0.7), lineWidth: 0.75))
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

/// Ball-top joystick. Decorative feedback: leans toward the last skip direction.
struct Joystick: View {
    var lean: Double
    var lit: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(BedPalette.faceEdge.opacity(0.9))
                .frame(width: 22, height: 8)
                .overlay(
                    Ellipse().strokeBorder(BedPalette.outline.opacity(0.4), lineWidth: 1)
                )

            VStack(spacing: 0) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                lit ? BedPalette.brassLit : Color(red: 0.95, green: 0.93, blue: 0.88),
                                lit ? BedPalette.brass : Color(red: 0.70, green: 0.66, blue: 0.58)
                            ],
                            center: .init(x: 0.34, y: 0.28),
                            startRadius: 0,
                            endRadius: 16
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(BedPalette.outline.opacity(0.35), lineWidth: 1))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [BedPalette.brassLit, BedPalette.brassDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 7, height: 16)
            }
            .rotationEffect(.degrees(lean * 16), anchor: .bottom)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: lean)
        }
        .frame(width: 40, height: 42)
        .accessibilityHidden(true)
    }
}

/// Small round power LED, lit when playing.
struct PowerLamp: View {
    var on: Bool

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: on
                        ? [Color(red: 0.55, green: 1.0, blue: 0.55), Color(red: 0.15, green: 0.65, blue: 0.2)]
                        : [Color(red: 0.32, green: 0.16, blue: 0.14), Color(red: 0.18, green: 0.08, blue: 0.07)],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: 6
                )
            )
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(BedPalette.outline.opacity(0.5), lineWidth: 1))
            .shadow(color: on ? Color.green.opacity(0.6) : .clear, radius: 4)
            .accessibilityHidden(true)
    }
}

enum ArcadeButtonKind {
    case skip
    case action
}

/// Round arcade button: brass ring + domed cap that depresses when pressed.
struct ArcadeButtonStyle: ButtonStyle {
    var kind: ArcadeButtonKind = .skip
    var lit: Bool = false

    private var diameter: CGFloat { kind == .action ? 56 : 40 }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [BedPalette.brassLit, BedPalette.brassDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .fill(BedPalette.outline.opacity(0.55))
                .padding(4)
            Circle()
                .fill(cap(pressed: pressed))
                .padding(5)
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(pressed ? 0.10 : 0.30))
                        .padding(5)
                        .mask(alignment: .top) {
                            Ellipse()
                                .frame(width: diameter * 0.5, height: diameter * 0.28)
                                .padding(.top, 8)
                        }
                        .allowsHitTesting(false)
                }
                .offset(y: pressed ? 1.5 : 0)

            configuration.label
                .font(PixelFont.ui(kind == .action ? 9 : 8))
                .foregroundStyle(lit ? BedPalette.ink : BedPalette.face.opacity(0.92))
                .offset(y: pressed ? 1.5 : 0)
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().strokeBorder(BedPalette.brassDeep, lineWidth: 1))
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private func cap(pressed: Bool) -> some ShapeStyle {
        if lit {
            return AnyShapeStyle(
                RadialGradient(
                    colors: [BedPalette.brassLit, BedPalette.lamp],
                    center: .init(x: 0.4, y: 0.32),
                    startRadius: 0,
                    endRadius: diameter * 0.6
                )
            )
        }
        let top = Color(red: 0.28, green: 0.26, blue: 0.24)
        let bottom = Color(red: 0.10, green: 0.09, blue: 0.08)
        return AnyShapeStyle(
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
        )
    }
}
