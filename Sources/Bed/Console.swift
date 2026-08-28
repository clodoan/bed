import SwiftUI

// One Braun radio face at night: a dark plate, a screen punched into it,
// one speaker field, and three tactile buttons.

enum TactileKind {
    case skip
    case action
}

struct SpeakerGrille: View {
    var body: some View {
        Canvas { context, size in
            let cols = 7
            let rows = 7
            let gapX = size.width / CGFloat(cols)
            let gapY = size.height / CGFloat(rows)
            let dot = min(gapX, gapY) * 0.42
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = gapX * (CGFloat(col) + 0.5) - dot / 2
                    let y = gapY * (CGFloat(row) + 0.5) - dot / 2
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                        with: .color(BedPalette.outline.opacity(0.85))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct TactileButtonStyle: ButtonStyle {
    var kind: TactileKind = .skip
    var lit: Bool = false

    private var diameter: CGFloat { kind == .action ? 54 : 40 }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let d = diameter
        let well = d + 10
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0.32)],
                        center: .center,
                        startRadius: d * 0.15,
                        endRadius: well * 0.52
                    )
                )
                .frame(width: well, height: well)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.black.opacity(0.75), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: capColors,
                        center: UnitPoint(x: 0.4, y: 0.34),
                        startRadius: 1,
                        endRadius: d * 0.64
                    )
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(pressed ? 0.04 : 0.12),
                                    Color.clear,
                                    Color.black.opacity(0.4)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .overlay {
                    if lit {
                        Circle()
                            .stroke(BedPalette.lamp.opacity(pressed ? 0.12 : 0.28), lineWidth: 3)
                            .blur(radius: 3)
                            .padding(1)
                    }
                }
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(pressed ? 0.18 : 0.48), radius: pressed ? 1 : 2.5, y: pressed ? 1 : 2)
                .offset(y: pressed ? 1.5 : 0)

            configuration.label
                .font(PixelFont.ui(kind == .action ? 9 : 8))
                .foregroundStyle(lit ? BedPalette.ink : BedPalette.cream.opacity(0.82))
                .offset(y: pressed ? 1.5 : 0)
        }
        .frame(width: well, height: well)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private var capColors: [Color] {
        if lit {
            return [
                Color(red: 0.86, green: 0.66, blue: 0.36),
                Color(red: 0.72, green: 0.48, blue: 0.20),
                Color(red: 0.42, green: 0.26, blue: 0.10)
            ]
        }
        return [
            Color(red: 0.20, green: 0.17, blue: 0.15),
            Color(red: 0.13, green: 0.11, blue: 0.10),
            Color(red: 0.07, green: 0.06, blue: 0.05)
        ]
    }
}
