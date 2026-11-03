import Foundation

/// Evening Mode: a warmer screen with less blue light, as strong as you choose, on by hand or on a
/// schedule that fades in and out. These are the rules and the colour maths; the Mac app applies
/// the result to every display.
public enum EveningSchedule: String, Codable, CaseIterable, Sendable {
    /// Only when turned on by hand.
    case manual
    /// Every day between `eveningStart` and `eveningEnd`.
    case scheduled
    /// Every day from sunset to sunrise, worked out on the Mac from its time zone.
    case sun
}

public enum EveningMode {
    /// The colour temperature at 0% (daylight, no change) and at 100% (candlelight).
    public static let neutralKelvin = 6500.0
    public static let warmestKelvin = 1900.0

    /// The colour temperature for a strength from 0 to 1.
    public static func kelvin(strength: Double) -> Double {
        let s = min(max(strength, 0), 1)
        return neutralKelvin - (neutralKelvin - warmestKelvin) * s
    }

    /// Red, green and blue multipliers (0–1) for a strength from 0 to 1: 1, 1, 1 at 0, less blue
    /// and some green as it grows. Normalised so white at 6500 K is exactly 1, 1, 1.
    /// With `red`, green and blue fall away further as it grows, down to red light only at 1 (for
    /// late at night or a darkroom).
    public static func multipliers(strength: Double, red: Bool = false) -> (red: Double, green: Double, blue: Double) {
        let warm = rgb(kelvin: kelvin(strength: strength)), white = rgb(kelvin: neutralKelvin)
        let m = (min(warm.0 / white.0, 1), min(warm.1 / white.1, 1), min(warm.2 / white.2, 1))
        guard red else { return m }
        let keep = 1 - min(max(strength, 0), 1)
        return (m.0, m.1 * keep, m.2 * keep)
    }

    /// The lowest software brightness a display can be set to, so it never goes completely dark.
    public static let minimumBrightness = 0.1

    /// A colour curve's multipliers with a display's software brightness (0.1–1) applied as well.
    public static func multipliers(strength: Double, red: Bool = false, brightness: Double) -> (red: Double, green: Double, blue: Double) {
        let m = multipliers(strength: strength, red: red)
        let b = min(max(brightness, minimumBrightness), 1)
        return (m.red * b, m.green * b, m.blue * b)
    }

    /// Whether Evening Mode rests while `frontApp` (a bundle ID) is in front, for apps where
    /// colour matters (photo and video editors).
    public static func isPaused(frontApp: String?, exceptions: [String]) -> Bool {
        guard let frontApp, !frontApp.isEmpty else { return false }
        return exceptions.contains { $0.caseInsensitiveCompare(frontApp) == .orderedSame }
    }

    /// Black-body colour (Tanner Helland's approximation), 0–255 per channel.
    static func rgb(kelvin: Double) -> (Double, Double, Double) {
        let t = kelvin / 100
        let red = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let green = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let blue = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        func clamp(_ v: Double) -> Double { min(max(v, 0), 255) }
        return (clamp(red), clamp(green), clamp(blue))
    }

    /// How much of the chosen strength applies at `minute` (minutes after midnight), 0–1, for a
    /// schedule from `start` to `end` (it may run past midnight). It fades in over `fade` minutes
    /// after the start and out over `fade` minutes before the end.
    public static func scheduleLevel(minute: Int, start: Int, end: Int, fade: Int = 20) -> Double {
        let day = 24 * 60
        let length = (end - start + day) % day
        guard length > 0 else { return 0 }
        let into = (minute - start + day) % day
        guard into < length else { return 0 }
        let ramp = Double(max(min(fade, length / 2), 0))
        guard ramp > 0 else { return 1 }
        let fromStart = Double(into), toEnd = Double(length - into)
        return min(1, fromStart / ramp, toEnd / ramp)
    }

    /// The strength to show now (0 = screen as normal). With the sun schedule, `sun` is today's
    /// sunrise and sunset: it fades in over 40 minutes from sunset and out over the 40 before sunrise.
    public static func level(schedule: EveningSchedule, manuallyOn: Bool, strength: Double, minute: Int,
                             start: Int, end: Int, fade: Int = 20, sun: SolarTimes.Day? = nil) -> Double {
        let s = min(max(strength, 0), 1)
        if manuallyOn { return s }
        switch schedule {
        case .manual:
            return 0
        case .scheduled:
            return s * scheduleLevel(minute: minute, start: start, end: end, fade: fade)
        case .sun:
            switch sun {
            case .normal(let sunrise, let sunset)?:
                return s * scheduleLevel(minute: minute, start: sunset, end: sunrise, fade: 40)
            case .alwaysDown?:
                return s
            case .alwaysUp?, nil:
                return 0
            }
        }
    }
}
