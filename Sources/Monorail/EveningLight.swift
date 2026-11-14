#if os(macOS)
import AppKit
import CoreGraphics
import MonorailCore

/// Evening Mode on the Mac: warms every display (less blue light) through its colour curve, the
/// way f.lux does, keeping each display's own calibration. Screenshots and recordings aren't
/// affected, Night Shift is left alone, and macOS puts the normal colours back by itself if
/// Monorail quits or crashes. The same curves also carry each display's software brightness,
/// which can go below the display's own lowest setting.
final class EveningLight {
    var settings: () -> AppSettings = { AppSettings() }
    /// The strength shown now, 0–1.
    private(set) var level = 0.0
    /// What's on screen now: the strength, red or not, and each display's brightness.
    private var applied = Applied()
    private struct Applied: Equatable {
        var level = 0.0
        var red = false
        var brightness: [String: Double] = [:]
        var isNeutral: Bool { level <= 0.001 && brightness.values.allSatisfy { $0 >= 0.999 } }
    }
    /// Evening Mode rests while a colour-critical app (Settings → Evening Mode) is in front.
    private(set) var isPausedForApp = false
    /// Film mode: true colours while you watch, warmth back afterwards.
    private(set) var isPausedForFilm = false

    func pauseForFilm(_ on: Bool) {
        isPausedForFilm = on
        update()
    }
    /// Today's sunrise and sunset, worked out once a day.
    private var sun: (day: Int, value: SolarTimes.Day)?
    private var timer: Timer?
    /// Each display's own (calibrated) curve, read before changing it.
    private var base: [CGDirectDisplayID: (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue])] = [:]
    private static weak var current: EveningLight?

    var isOn: Bool { level > 0.001 }

    func start() {
        Self.current = self
        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            guard !flags.contains(.beginConfigurationFlag) else { return }
            DispatchQueue.main.async { EveningLight.current?.displaysChanged() }
        }, nil)
        // macOS puts the normal curves back after sleep.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.displaysChanged()
        }
        // Rests while an app where colour matters is in front.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.settings().eveningPausedApps.isEmpty else { return }
            self.update()
        }
        timer = Timer.every(20) { [weak self] _ in self?.update() }
        update()
    }

    /// Works out the strength for now and shows it (call after settings change, for a live slider).
    func update() {
        // While Monorail leads, it owns the screen's colours; two apps writing them would flicker.
        if SuiteRole.shared.pauses(.eveningColours) || SuiteRole.shared.rests(.eveningColours) {
            if !applied.isNeutral { restore() }
            return
        }
        let settings = self.settings()
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        level = EveningMode.level(schedule: settings.eveningSchedule, manuallyOn: settings.eveningOn,
                                  strength: settings.eveningStrength, minute: minute,
                                  start: settings.eveningStart, end: settings.eveningEnd,
                                  sun: settings.eveningSchedule == .sun ? todaysSun() : nil)
        isPausedForApp = level > 0.001 && EveningMode.isPaused(frontApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                                                                exceptions: settings.eveningPausedApps)
        var wanted = Applied(level: isPausedForApp || isPausedForFilm ? 0 : level, red: settings.eveningRed)
        // Keeper's display brightness leads when it's on: Monorail's software dimming steps back.
        for (uuid, value) in settings.displayBrightness where value < 0.999 && !SuiteRole.shared.rests(.displayBrightness) {
            wanted.brightness[uuid] = min(max(value, EveningMode.minimumBrightness), 1)
        }
        guard abs(wanted.level - applied.level) > 0.002 || wanted.red != applied.red || wanted.brightness != applied.brightness
        else { return }
        apply(wanted)
    }

    /// Today's sunrise and sunset where the Mac's time zone says it is.
    func todaysSun() -> SolarTimes.Day {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        if let sun, sun.day == day { return sun.value }
        let value = SolarTimes.day(on: Date(), timeZone: .current)
        sun = (day, value)
        return value
    }

    /// Back to normal colours (on quit; macOS also does this if Monorail crashes).
    func restore() {
        if !applied.isNeutral { CGDisplayRestoreColorSyncSettings() }
        applied = Applied()
    }

    private func displaysChanged() {
        base = [:]
        // Force the curves to be written again.
        applied = Applied(level: -1)
        update()
    }

    private func apply(_ wanted: Applied) {
        guard !wanted.isNeutral else {
            CGDisplayRestoreColorSyncSettings()
            applied = Applied()
            return
        }
        // Read every display's own curve first (reading one resets them all), then change each.
        let curves = Self.activeDisplays().compactMap { display in baseCurve(display).map { (display, $0) } }
        for (display, curve) in curves {
            let brightness = wanted.brightness[Display.uuidString(for: display)] ?? 1
            let m = EveningMode.multipliers(strength: max(wanted.level, 0), red: wanted.red, brightness: brightness)
            let count = UInt32(curve.r.count)
            let r = curve.r.map { $0 * CGGammaValue(m.red) }
            let g = curve.g.map { $0 * CGGammaValue(m.green) }
            let b = curve.b.map { $0 * CGGammaValue(m.blue) }
            CGSetDisplayTransferByTable(display, count, r, g, b)
        }
        applied = wanted
    }

    private func baseCurve(_ display: CGDirectDisplayID) -> (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue])? {
        if let known = base[display] { return known }
        // Read the display's own curve before anything changed it.
        if !applied.isNeutral { CGDisplayRestoreColorSyncSettings() }
        let capacity = Int(CGDisplayGammaTableCapacity(display))
        guard capacity > 1 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: capacity)
        var g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, UInt32(capacity), &r, &g, &b, &count) == .success, count > 1 else { return nil }
        let curve = (Array(r.prefix(Int(count))), Array(g.prefix(Int(count))), Array(b.prefix(Int(count))))
        base[display] = curve
        return curve
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var list = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &list, &count) == .success else { return [] }
        return Array(list.prefix(Int(count)))
    }
}
#endif
