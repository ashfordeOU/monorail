#if os(macOS)
import AppKit
import CoreGraphics
import MonorailCore

/// Evening Mode on the Mac: warms every display (less blue light) through its colour curve, the
/// way f.lux does, keeping each display's own calibration. Screenshots and recordings aren't
/// affected, Night Shift is left alone, and macOS puts the normal colours back by itself if
/// Monorail quits or crashes.
final class EveningLight {
    var settings: () -> AppSettings = { AppSettings() }
    /// The strength shown now, 0–1.
    private(set) var level = 0.0
    private var applied = 0.0
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
        timer = Timer.every(20) { [weak self] _ in self?.update() }
        update()
    }

    /// Works out the strength for now and shows it (call after settings change, for a live slider).
    func update() {
        let settings = self.settings()
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        level = EveningMode.level(schedule: settings.eveningSchedule, manuallyOn: settings.eveningOn,
                                  strength: settings.eveningStrength, minute: minute,
                                  start: settings.eveningStart, end: settings.eveningEnd)
        guard abs(level - applied) > 0.002 else { return }
        apply(level)
    }

    /// Back to normal colours (on quit; macOS also does this if Monorail crashes).
    func restore() {
        if applied > 0 { CGDisplayRestoreColorSyncSettings() }
        applied = 0
    }

    private func displaysChanged() {
        base = [:]
        applied = -1
        update()
    }

    private func apply(_ level: Double) {
        guard level > 0.001 else {
            CGDisplayRestoreColorSyncSettings()
            applied = 0
            return
        }
        let m = EveningMode.multipliers(strength: level)
        // Read every display's own curve first (reading one resets them all), then warm each.
        let curves = Self.activeDisplays().compactMap { display in baseCurve(display).map { (display, $0) } }
        for (display, curve) in curves {
            let count = UInt32(curve.r.count)
            let r = curve.r.map { $0 * CGGammaValue(m.red) }
            let g = curve.g.map { $0 * CGGammaValue(m.green) }
            let b = curve.b.map { $0 * CGGammaValue(m.blue) }
            CGSetDisplayTransferByTable(display, count, r, g, b)
        }
        applied = level
    }

    private func baseCurve(_ display: CGDirectDisplayID) -> (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue])? {
        if let known = base[display] { return known }
        // Read the display's own curve before anything changed it.
        if applied != 0 { CGDisplayRestoreColorSyncSettings() }
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
