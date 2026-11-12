#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

// The shared look of Monorail's panels: system colours, Apple text sizes, tiles, round toggles,
// the three battery rings with their glow, and one set of springs. Everything respects
// Reduce Motion and Reduce Transparency.

enum Tone {
    /// Green, amber and red: the only three status colours, as in Activity and Health.
    static let good = Color(nsColor: .systemGreen)
    static let ok = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 1, green: 0.84, blue: 0.04, alpha: 1) : NSColor(red: 0.90, green: 0.65, blue: 0, alpha: 1)
    })
    static let high = Color(nsColor: .systemRed)
    static let blue = Color(nsColor: .systemBlue)
    static let warm = Color(nsColor: .systemOrange)

    static func of(_ tone: BatteryRings.Tone) -> Color {
        switch tone {
        case .good: return good
        case .ok: return ok
        case .high: return high
        }
    }

    static func of(_ tone: HomeLayout.Tone) -> Color {
        switch tone {
        case .calm: return good
        case .attention: return ok
        case .urgent: return high
        }
    }
}

enum Motion {
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    /// Pages sliding in the panel: quick, with the faintest overshoot.
    static var page: Animation { reduced ? .easeOut(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.86) }
    /// A toggle filling in, a button pressed.
    static var pop: Animation { reduced ? .easeOut(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.6) }
    /// Rings drawing in when a page opens.
    static var rings: Animation { reduced ? .easeOut(duration: 0.1) : .spring(response: 0.95, dampingFraction: 0.82) }
    /// Cards changing places when something needs you.
    static var reorder: Animation { reduced ? .easeOut(duration: 0.1) : .spring(response: 0.5, dampingFraction: 0.85) }
}

extension Font {
    /// Numbers in SF Pro Rounded with even widths, as on the Lock Screen and in Activity.
    static func figure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
    /// The small capitals label above a value ("CHARGE").
    static let label = Font.system(size: 10.5, weight: .semibold)
}

/// A rounded tile on the panel's glass.
struct TileBackground: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.map { $0.opacity(0.12) } ?? Color.primary.opacity(0.06)))
    }
}

extension View {
    func tile(tint: Color? = nil, padding: CGFloat = 10) -> some View {
        modifier(TileBackground(tint: tint, padding: padding))
    }
}

/// Presses in slightly with a spring, like Control Centre's modules.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !Motion.reduced ? 0.96 : 1)
            .animation(Motion.pop, value: configuration.isPressed)
    }
}

/// A round control with its name under it: the Control Centre switch.
struct RoundToggle: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    var tint: Color = Tone.blue
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isOn ? tint : Color.primary.opacity(0.1)))
                    .scaleEffect(isOn ? 1 : 0.97)
                    .animation(Motion.pop, value: isOn)
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                if let subtitle { Text(subtitle).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1) }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}

/// Three concentric rings, outside in, like Activity: each a share 0…1 in its colour over a faint track.
/// They draw in with a spring when they appear and glide when the values change.
struct Rings3: View {
    let values: [Double]
    let colors: [Color]
    var size: CGFloat = 108
    var width: CGFloat = 11
    var gap: CGFloat = 2
    @State private var drawn = false

    var body: some View {
        ZStack {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let inset = CGFloat(index) * (width + gap) + width / 2
                let color = colors[min(index, colors.count - 1)]
                Circle().inset(by: inset).stroke(color.opacity(0.18), lineWidth: width)
                Circle().inset(by: inset)
                    .trim(from: 0, to: drawn ? max(min(value, 1), 0.001) : 0.001)
                    .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            drawn = false
            withAnimation(Motion.rings.delay(Motion.reduced ? 0 : 0.08)) { drawn = true }
        }
        .animation(Motion.rings, value: values)
        .accessibilityHidden(true)
    }
}

/// A legend line beside the rings: a colour bar, the small label, the value and a note.
struct RingLegend: View {
    let color: Color
    let label: String
    let value: String
    let note: String
    var delay: Double = 0
    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3, height: 30).padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.label).foregroundStyle(color).kerning(0.3)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value).font(.figure(17))
                    Text(note).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 6)
        .onAppear { withAnimation(Motion.pop.delay(Motion.reduced ? 0 : 0.14 + delay)) { shown = true } }
        .accessibilityElement(children: .combine)
    }
}

/// The living glow behind the rings: a soft bloom that breathes and specks of light circling,
/// quicker and warmer as the drain rises. Still with Reduce Motion on; draws only while shown.
struct EnergyGlow: View {
    /// Draw over your usual: 1 is calm.
    var intensity: Double
    var color: Color
    var size: CGFloat = 160

    private struct Speck { var angle: Double; var radius: Double; var speed: Double; var depth: Double }
    @State private var specks: [Speck] = (0..<160).map { _ in
        Speck(angle: .random(in: 0..<(2 * .pi)), radius: .random(in: 0.38...0.78), speed: .random(in: 0.3...1), depth: .random(in: 0...1))
    }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let still = Motion.reduced
        SwiftUI.TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { timeline in
            Canvas { context, canvas in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let k = min(max(intensity, 0.5), 3)
                let centre = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let r = min(canvas.width, canvas.height) / 2
                let breath = still ? 0.5 : 0.5 + 0.5 * sin(t * (0.9 + k * 0.6))
                let dark = scheme == .dark
                let bloom = Gradient(stops: [
                    .init(color: color.opacity((dark ? 0.32 : 0.22) + breath * 0.12), location: 0.25),
                    .init(color: color.opacity((dark ? 0.12 : 0.08) + breath * 0.05), location: 0.6),
                    .init(color: color.opacity(0), location: 1),
                ])
                context.fill(Path(ellipseIn: CGRect(origin: .zero, size: canvas)),
                             with: .radialGradient(bloom, center: centre, startRadius: 0, endRadius: r))
                if dark { context.blendMode = .plusLighter }
                for speck in specks {
                    let angle = speck.angle + (still ? 0 : t * 0.12 * speck.speed * k)
                    let wobble = still ? 0 : sin(angle * 3 + speck.depth * 9) * 0.02 * k
                    let rr = (speck.radius + wobble) * r
                    let point = CGPoint(x: centre.x + cos(angle) * rr, y: centre.y + sin(angle) * rr)
                    let fade = max(0, 1 - abs(speck.radius - 0.6) / 0.45) * (dark ? 0.75 : 0.5) * (0.4 + speck.depth * 0.6)
                    let dot = 0.7 + speck.depth * 1.5
                    context.fill(Path(ellipseIn: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)),
                                 with: .color(color.opacity(fade)))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The rings with their glow, sized for a page (108) or a home card (52).
struct BatteryRingsView: View {
    let rings: BatteryRings
    var size: CGFloat = 108
    var glow = true

    var body: some View {
        let width: CGFloat = size >= 90 ? 11 : 5.5
        let drain = Tone.of(rings.drainTone)
        ZStack {
            if glow { EnergyGlow(intensity: rings.drainRatio ?? 1, color: drain, size: size * 1.5) }
            Rings3(values: [rings.charge, rings.time, rings.drain], colors: [Tone.good, Tone.blue, drain],
                   size: size, width: width, gap: size >= 90 ? 2 : 1.5)
        }
        .frame(width: size, height: size)
    }
}

/// A panel page's top line: ‹ back on the left, the title in the middle.
struct PageHeader: View {
    let back: String
    let title: String
    let onBack: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text(back)
                    }
                    .foregroundStyle(Tone.blue)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityLabel(Text("Back to \(back)"))
                Spacer()
                if let trailing { trailing }
            }
        }
        .frame(height: 22)
    }
}
/// A row with a coloured icon, a bold title and a line under it, rising in after `delay`:
/// the rows of an Apple "What's New" or welcome screen.
struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String
    var delay: Double = 0
    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 10)
        .onAppear { withAnimation(Motion.pop.delay(Motion.reduced ? 0 : 0.15 + delay)) { shown = true } }
        .accessibilityElement(children: .combine)
    }
}

/// Page dots; the current one stretches into a short bar.
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.primary.opacity(0.6) : Color.primary.opacity(0.18))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(Motion.page, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(current + 1) of \(count)"))
    }
}
#endif
