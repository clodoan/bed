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
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: d + 8, height: d + 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: capColors,
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 0,
                        endRadius: d * 0.72
                    )
                )
                .overlay {
                    Ellipse()
                        .fill(BedPalette.lamp.opacity(pressed ? 0.06 : 0.22))
                        .frame(width: d * 0.46, height: d * 0.2)
                        .offset(x: -d * 0.06, y: -d * 0.22)
                }
                .overlay(Circle().strokeBorder(Color.black.opacity(0.45), lineWidth: 1))
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(pressed ? 0.2 : 0.55), radius: pressed ? 1 : 4, y: pressed ? 1 : 3)
                .offset(y: pressed ? 2 : 0)

            configuration.label
                .font(PixelFont.ui(kind == .action ? 9 : 8))
                .foregroundStyle(lit ? BedPalette.ink : BedPalette.cream)
                .offset(y: pressed ? 2 : 0)
        }
        .frame(width: d + 8, height: d + 8)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private var capColors: [Color] {
        if lit {
            return [
                Color(red: 1.0, green: 0.82, blue: 0.48),
                BedPalette.lamp,
                BedPalette.amber
            ]
        }
        return [
            Color(red: 0.26, green: 0.22, blue: 0.18),
            Color(red: 0.13, green: 0.11, blue: 0.09),
            Color(red: 0.06, green: 0.05, blue: 0.04)
        ]
    }
}
