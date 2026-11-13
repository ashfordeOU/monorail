#if os(macOS)
import AppKit
import CoreAudio
import CoreMediaIO
import IOKit.pwr_mgt
import MonorailCore
import UserNotifications

/// Calls, films and heat: notices when the microphone or camera is in use (a call), keeps the Mac
/// awake through it, runs Film mode and its sleep timer, follows the Mac's heat, and nudges you to
/// unplug at the charge you chose. Everything here works in Station's sandbox too.
final class MomentsWatch: ObservableObject {
    static let shared = MomentsWatch()

    @Published private(set) var call = CallState()
    @Published private(set) var heat: Heat = .normal
    @Published private(set) var film = false
    /// When the sleep timer ends Film mode (and, in Monorail, sleeps the Mac).
    @Published private(set) var sleepAt: Date?
    /// Film mode was turned on by a video playing, so it also turns itself off.
    private var filmIsAuto = false

    var settings: () -> AppSettings = { AppSettings() }
    /// Film mode changed: the app pauses Evening Mode, quiets notices and hides the slider bar.
    var onFilmChange: (Bool) -> Void = { _ in }

    private var timer: Timer?
    private var sleepTimer: Timer?
    private var callAssertion: IOPMAssertionID = 0
    private var filmAssertion: IOPMAssertionID = 0
    private var nudgedThisCharge = false

    func start() {
        guard timer == nil else { return }
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tick()
        }
        timer = Timer.every(5) { [weak self] _ in self?.tick() }
        tick()
    }

    private func tick() {
        let newHeat = Heat(thermalState: ProcessInfo.processInfo.thermalState.rawValue)
        if newHeat != heat { heat = newHeat }
        let newCall = CallState(micInUse: Self.micInUse(), cameraInUse: Self.cameraInUse(), micMuted: Self.micMuted())
        if newCall != call {
            let started = newCall.isOnCall && !call.isOnCall, ended = !newCall.isOnCall && call.isOnCall
            call = newCall
            if started, settings().awakeDuringCalls { hold(&callAssertion, "Monorail: on a call") }
            if ended { release(&callAssertion) }
        }
        autoFilm()
        nudgeToUnplug()
    }

    // MARK: Film mode

    func setFilm(_ on: Bool) {
        guard on != film else { return }
        filmIsAuto = false
        apply(film: on)
    }

    private func apply(film on: Bool) {
        film = on
        if on { hold(&filmAssertion, "Monorail: Film mode") } else { release(&filmAssertion); setSleepTimer(nil) }
        onFilmChange(on)
    }

    /// With "Film mode by itself" on: a video player holding the display awake turns it on; when
    /// the video stops, it turns off again (only if it turned itself on).
    private func autoFilm() {
        guard settings().movieAuto else { return }
        let playing = !BarAside.videoPlayers().isEmpty
        if playing, !film {
            filmIsAuto = true
            apply(film: true)
        } else if !playing, film, filmIsAuto {
            filmIsAuto = false
            apply(film: false)
        }
    }

    /// Ends Film mode after `minutes` and lets the Mac sleep; Monorail also puts it to sleep.
    func setSleepTimer(_ minutes: Int?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        guard let minutes, minutes > 0 else { sleepAt = nil; return }
        sleepAt = Date().addingTimeInterval(Double(minutes) * 60)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.sleepAt = nil
            self.apply(film: false)
            if !Edition.isAppStore { Self.sleepNow() }
        }
    }

    private static func sleepNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]
        try? process.run()
    }

    // MARK: Charging

    private func nudgeToUnplug() {
        let b = PowerWatch.shared.battery
        if !b.isCharging { nudgedThisCharge = false; return }
        guard Moments.shouldNudgeToUnplug(percent: b.percent, isCharging: b.isCharging, limit: settings().chargeLimit,
                                          alreadyNudged: nudgedThisCharge) else { return }
        nudgedThisCharge = true
        let content = UNMutableNotificationContent()
        content.title = "Charged to \(b.percent)%"
        content.body = "Unplug now to keep the battery healthy."
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: "unplug-\(Date().timeIntervalSince1970)", content: content, trigger: nil))
        }
    }

    // MARK: Microphone and camera

    /// Mutes or unmutes the default microphone.
    func toggleMute() {
        guard let device = Self.defaultInput() else { return }
        var muted: UInt32 = Self.micMuted() ? 0 : 1
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muted)
        if status != noErr {
            // Some microphones have no mute: turn the input volume down instead (or back up).
            var volume: Float32 = muted == 1 ? 0 : 0.75
            address.mSelector = kAudioDevicePropertyVolumeScalar
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
        }
        tick()
    }

    private static func defaultInput() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
            device != 0 else { return nil }
        return device
    }

    static func micInUse() -> Bool {
        guard let device = defaultInput() else { return false }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr && running != 0
    }

    static func micMuted() -> Bool {
        guard let device = defaultInput() else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr { return muted != 0 }
        var volume: Float32 = 1
        size = UInt32(MemoryLayout<Float32>.size)
        address.mSelector = kAudioDevicePropertyVolumeScalar
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr && volume < 0.01
    }

    /// Any camera in use by any app.
    static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return false }
        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used, &devices) == noErr else { return false }
        for device in devices {
            var running: UInt32 = 0
            let runningSize = UInt32(MemoryLayout<UInt32>.size)
            var usedSize: UInt32 = 0
            var runAddress = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                                                       mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                                                       mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard))
            if CMIOObjectGetPropertyData(device, &runAddress, 0, nil, runningSize, &usedSize, &running) == noErr, running != 0 { return true }
        }
        return false
    }

    // MARK: Keeping the display awake

    private func hold(_ id: inout IOPMAssertionID, _ reason: String) {
        guard id == 0 else { return }
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &id)
    }

    private func release(_ id: inout IOPMAssertionID) {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }
}
#endif
