import Foundation

/// Evening Mode: a warmer screen with less blue light, as strong as you choose, on by hand or on a
/// schedule that fades in and out. These are the rules and the colour maths; the Mac app applies
/// the result to every display.
public enum EveningSchedule: String, Codable, CaseIterable, Sendable {
    /// Only when turned on by hand.
    case manual
    /// Every day between `eveningStart` and `eveningEnd`.
    case scheduled
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
    public static func multipliers(strength: Double) -> (red: Double, green: Double, blue: Double) {
        let warm = rgb(kelvin: kelvin(strength: strength)), white = rgb(kelvin: neutralKelvin)
        return (min(warm.0 / white.0, 1), min(warm.1 / white.1, 1), min(warm.2 / white.2, 1))
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

    /// The strength to show now (0 = screen as normal).
    public static func level(schedule: EveningSchedule, manuallyOn: Bool, strength: Double, minute: Int,
                             start: Int, end: Int, fade: Int = 20) -> Double {
        let s = min(max(strength, 0), 1)
        if manuallyOn { return s }
        guard schedule == .scheduled else { return 0 }
        return s * scheduleLevel(minute: minute, start: start, end: end, fade: fade)
    }
}
