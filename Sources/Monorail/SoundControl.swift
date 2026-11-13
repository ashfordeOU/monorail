#if os(macOS)
import AppKit
import CoreAudio

/// The Mac's sound: output devices, the chosen one's volume and mute. Public Core Audio, allowed in
/// the App Store's sandbox too. (Volume per app would need an audio driver, which neither app installs.)
final class SoundControl: ObservableObject {
    static let shared = SoundControl()

    struct Device: Identifiable, Equatable { let id: AudioDeviceID; let name: String }

    @Published private(set) var outputs: [Device] = []
    @Published private(set) var current: AudioDeviceID = 0
    @Published var volume: Float = 0.5 { didSet { if !reading { setVolume(volume) } } }
    @Published private(set) var muted = false
    private var reading = false

    func refresh() {
        reading = true
        defer { reading = false }
        current = Self.defaultOutput() ?? 0
        outputs = Self.allDevices().filter { Self.hasOutput($0) }.map { Device(id: $0, name: Self.name($0)) }
        volume = Self.volume(current) ?? volume
        muted = Self.isMuted(current)
    }

    func choose(_ device: AudioDeviceID) {
        var id = device
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        refresh()
    }

    func toggleMute() {
        var value: UInt32 = muted ? 0 : 1
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(current, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        refresh()
    }

    private func setVolume(_ value: Float) {
        var v = Float32(min(max(value, 0), 1))
        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            if AudioObjectHasProperty(current, &address) {
                AudioObjectSetPropertyData(current, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
            }
        }
    }

    // MARK: Core Audio

    private static func defaultOutput() -> AudioDeviceID? {
        var id = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr ? id : nil
    }

    private static func allDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr ? ids : []
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func name(_ id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr, let value = name?.takeRetainedValue() else { return "Output" }
        return value as String
    }

    private static func volume(_ id: AudioDeviceID) -> Float? {
        for element in [kAudioObjectPropertyElementMain, 1] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            var value = Float32(0), size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectHasProperty(id, &address), AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr { return value }
        }
        return nil
    }

    private static func isMuted(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0, size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr && value != 0
    }
}

/// Listening ports (Monorail): dev servers and services on this Mac, with Stop.
final class PortsWatch: ObservableObject {
    static let shared = PortsWatch()
    @Published private(set) var ports: [ListeningPort] = []
    @Published private(set) var loading = false

    func refresh() {
        guard !Edition.isAppStore, !loading else { return }
        loading = true
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            var data = Data()
            if (try? task.run()) != nil { data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit() }
            let found = ListeningPort.parse(String(decoding: data, as: UTF8.self))
            DispatchQueue.main.async {
                self.ports = found
                self.loading = false
            }
        }
    }

    /// Asks first, then ends the program listening on that port.
    func stop(_ port: ListeningPort) {
        let alert = NSAlert()
        alert.messageText = "Stop \(port.command) on port \(port.port)?"
        alert.informativeText = "Anything you haven't saved in it may be lost."
        alert.addButton(withTitle: "Stop")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        kill(port.pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.refresh() }
    }
}
#endif
